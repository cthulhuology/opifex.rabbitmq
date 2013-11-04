# Opifex.RSS.coffee
#
#	© 2013 Dave Goehrig <dave@dloh.org>
#

http = require('http')

crud = (method,self) ->
	(command, path,data) ->
		block = []
		req = http.request { hostname: 'localhost', port: 5678, path: path, method: method, headers: { "Content-Type": "application/json", "Content-Length" : data && data.length || 0 }}, (res) ->
			res.setEncoding 'utf8'
			res.on 'data', (chunk) ->
				block.push(chunk)
			res.on 'end', () ->
				console.log 'sending', [ 'docker', command, os.hostname(), res.statusCode, JSON.parse(block.join('')) ]
				self.send [ 'docker', command, os.hostname(), res.statusCode, JSON.parse(block.join('')) ]
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
	self.
	self["*"] = (message...) ->
		console.log "Unknown message #{ JSON.stringify(message) }"

module.exports = RabbitMQ
