# Opifex.RabbitMQ.coffee
#
#	© 2013 Dave Goehrig <dave@dloh.org>
#

os = require 'os'
http = require 'http'
config = require "#{process.env.HOME}/.rabbitmq.coffee"

auth = new Buffer(config.user + ':' + config.password ).toString('base64')

crud = (method,self) ->
	(command, path,data) ->
		block = []
		data = JSON.stringify(data)
		req = http.request {
			hostname: 'localhost',
			port: 15672,
			path: path, method: method,
			headers: {
				"Authorization": "Basic " + auth,
				"Content-Type": "application/json",
				"Content-Length" : data && data.length || 0
			}}, (res) ->
				res.setEncoding 'utf8'
				res.on 'data', (chunk) ->
					block.push(chunk)
				res.on 'end', () ->
					console.log "Got [#{block.join('')}]"
					msg = ''
					if block.length
						msg = JSON.parse(block.join(''))
					console.log 'sending', [ 'rabbitmq', command, os.hostname(), res.statusCode, msg ]
					self.send [ 'rabbitmq', command, os.hostname(), res.statusCode, msg ]
		if data && data.length
			req.write(data)
		req.end()

RabbitMQ = () ->
	# A bucket to contain the IDs of all the feed's we're parsing
	self = this
	Get = crud 'GET', self
	Post = crud 'POST', self
	Put = crud 'PUT', self
	Delete = crud 'DELETE', self
	# Does not understand message
	self["create.vhost"] = (name) ->
		Put "create.vhost", "/api/vhosts/#{name}"
	self["create.user"] = (name,password,tags...) ->
		Put "create.user", "/api/users/#{name}", { password: password, tags: tags.join(',') }
	self["grant.user"] = (vhost, name, read, write, config) ->
		Put "grant.user", "/api/permissions/#{vhost}/#{name}", { read: read, write: write, configure: config }
	self["federate"] = ( vhost, user, pass, name, priority, maxhops, pattern, uris... ) ->
		Put 'federate.user', "/api/parameters/federation/#{vhost}/local-username",
			{ vhost: vhost, component: "federation",  value: user }
		Put 'federate.password', "/api/parameters/federation/#{vhost}/local-nodename",
			{ vhost: vhost, component: "federation",  value: pass }
		Put 'federate.upstream-set', "/api/parameters/federation-upstream-set/#{vhost}/#{name}",
			{ vhost: vhost, component: "federation-upstream-set", value: [ { upstream: name }] }
		Put 'federate.upstream', "/api/parameters/federation-upstream/#{vhost}/#{name}",
			{ vhost: vhost, component: "federation-upstream", value: { uri: uris, 'max-hops':  maxhops }}
		Put 'federate.policy', "/api/policies/#{vhost}/#{name}",
			{pattern: pattern, definition: {"federation-upstream-set": name}, priority: priority}
	self["help"] = () ->
		self.send [ "rabbitmq", "help",
			[ "create.vhost", "name" ],
			[ "create.user", "name", "password", "tags..." ],
			[ "grant.user", "vhost", "name", "read", "write", "config" ],
			[ "federate", "vhost", "user", "password", "name", "priority", "max-hops", "pattern", "uris..." ]
			]
	self["*"] = (message...) ->
		console.log "Unknown message #{ JSON.stringify(message) }"

module.exports = RabbitMQ
