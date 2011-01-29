utils = require('./utils')
UserSession = require('./user_session').UserSession

class exports.Session
  
  id_length: 32
  user: null
  
  constructor: (@client) ->
    @cookies = try
      utils.parseCookie(@client.request.headers.cookie)
    catch e
      {}
  
  key: ->
    "session:#{@id}"

  process: (cb) ->
    if @cookies && @cookies.session_id && @cookies.session_id.length == @id_length
      R.hgetall 'session:' + @cookies.session_id, (err, @data) =>
        if err or @data == null
          @create(cb)
        else
          @id = @cookies.session_id
          @assignUser @data
          cb(null, @)
    else
      @create(cb)

  create: (cb) ->
    @id = utils.randomString(@id_length)
    @data = {}
    @data.created_at = Number(new Date())
    R.hset @key(), 'created_at', @data.created_at, (err, response) =>
      @newly_created = true
      cb(err, @)      

  # Authentication is provided by passing the name of a module which Node must be able to load, either from /lib/server, /vendor/module/lib, or from npm.
  # The module must implement an 'authenticate' function which expects a params object normally in the form of username and password, but could also be biometric or iPhone device id, SSO token, etc.
  #
  # The callback must be an object with a 'status' attribute (boolean) and a 'user_id' attribute (number or string) if successful.
  #
  # Additional info, such as number of tries remaining etc, can be passed back within the object and pushed upstream to the client. E.g:
  #
  # {success: true, user_id: 21323, info: {username: 'joebloggs'}}
  # {success: false, info: {num_retries: 2}}
  # {success: false, info: {num_retries: 0, lockout_duration_mins: 30}}
  authenticate: (module_name, params, cb) ->
    klass = require(module_name).Authentication
    auth = new klass
    auth.authenticate params, cb

  # Users
  assignUser: (data) ->
    return null unless data.user_id
    @user = new UserSession(data.user_id, @)
    @user.attributes = JSON.parse(data.attributes) if data.attributes

  loggedIn: ->
    @user?
  
  logout: (cb) ->
    @user = null
    @create (err, new_session) -> cb(null, new_session)    
  
  setUserAndAttributes: (user_id, user_data) ->
    return null if user_id is undefined or user_data is undefined
    R.hset @key(), 'user_id', user_id
    @assignUser(user_data)    
    R.hset @key(), 'attributes', JSON.stringify(Object.extend(@getAttributes(), user_data)) # Set attributes    
    
  getAttributes: ->
    attr = R.hget @key(), 'attributes'
    JSON.parse(attr || '{}')