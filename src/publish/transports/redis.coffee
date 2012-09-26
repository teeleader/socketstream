# Publish Event - Redis Transport

redis = require('redis')

module.exports = (config = {}) ->

  # Set options or use the defaults
  port = config.port || 6379
  host = config.host || "127.0.0.1"
  options = config.options || {}

  # Redis requires a separate connection for pub/sub
  conn = {}
  ['pub','sub'].forEach (name) ->
    conn[name] = redis.createClient(port, host, options)
    conn[name].auth(config.pass) if config.pass 
    conn[name].select(config.db) if config.db
    
    # listen for events
    conn[name].on 'connect', () ->
      console.error "[Redis-PubSub] Connection: #{name} - Connected"
      
      # try and publish a message every connection to keep the subscribe connection open...
      conn.pub.publish 'ss:event', 'd6581e085a3748259abcc61d20547e39eb1e7d2883934091b0968bdbe2bb4aaac2cd1ee9708e424eb7704e06be99d3c8' if name is 'pub'
    
    conn[name].on 'end', () ->
      console.error "[Redis-PubSub] Connection: #{name} - Disconnected"
    
    conn[name].on 'error', (err) ->
      console.error "[Redis-PubSub] Connection: #{name} - Error: #{err}"
    
  
  listen: (cb) ->
    conn.sub.subscribe 'ss:event'
    conn.sub.on 'message', (channel, msg) ->
      # stop if we have our 'test' message
      return if msg? and msg is 'd6581e085a3748259abcc61d20547e39eb1e7d2883934091b0968bdbe2bb4aaac2cd1ee9708e424eb7704e06be99d3c8'
      
      # callback
      cb JSON.parse(msg)

  send: (obj) ->
    msg = JSON.stringify(obj)
    conn.pub.publish 'ss:event', msg
