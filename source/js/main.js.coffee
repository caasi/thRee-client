$ = jQuery

duration = 500

EventEmitter = (o) ->
  o.emitter = $ {}

  o.emit = (args...) ->
    o.emitter.trigger.apply o.emitter, args
  o.once = (e, cc) ->
    o.emitter.one e, cc
  o.on = (e, cc) ->
    o.emitter.bind e, cc
  o.off = (e, cc) ->
    o.emitter.unbind e, cc
  o

exec = (o, cmd) ->
  prev = undefined
  current = this.exts
  ((key) ->
    prev = current
    current = current[key]
  ) key for key in cmd.keypath
  if cmd.type is "msg"
    current?.apply prev, cmd.args
  else
    if cmd.type is "get"
      return prev[cmd.keypath[cmd.keypath.length - 1]]
    if cmd.type is "set"
      prev[cmd.keypath[cmd.keypath.length - 1]] = cmd.args[0]

Agent = (target, thisArg) ->
  type = typeof target

  if Array.isArray target
    ret = null
  else if type is "function"
    ret = (args...) ->
      target.apply thisArg, arguments
      ret.emit "bubble",
        type: "msg"
        keypath: []
        args: args
  else if type is "object"
    ret = {}
  else
    ret = null

  if ret
    ret = EventEmitter ret
    ((key) ->
      result = Agent target[key], ret
      if result
        result.on "bubble", (e, cmd) ->
          ret.emit "bubble",
            type: cmd.type
            keypath: [key].concat cmd.keypath
            args: cmd.args
        ret[key] = result
      else
        Object.defineProperty ret, key,
          enumerable: true
          get: ->
            ret.emit "bubble",
              type: "get"
              keypath: [key]
              args: []
            return target[key]
          set: (value) ->
            target[key] = value
            ret.emit "bubble",
              type: "set"
              keypath: [key]
              args: [value]
    ) key for key of target
    ret.exec = (cmd) ->
      exec(target, cmd)
  ret

DObject = ->
  null

DObject.validate = (o) ->
  type = typeof o
  if Array.isArray o
    ret = o
  else if type is "function"
    ret = o
  else if type is "object"
    if o.type? and o.type is "function"
      ret = ->
    else
      ret = o
  else
    ret = o
  if type is "function" or type is "object"
    ((key) ->
      return if key is "type"
      ret[key] = DObject.validate o[key]
    ) key for key of o
  ret

DObject.expose = (o) ->
  type = typeof o
  if Array.isArray o
    ret = o
  else if type is "function"
    ret = { type: "function" }
  else if type is "object"
    ret = {}
  else
    ret = o
  if ret isnt o
    ((key) ->
      ret[key] = DObject.expose o[key]
    ) key for key of o
  ret

Log = (log) ->
  time = new Date(log.time)

  log.target = log.target || null
  log.classes = {}
  log.classes[log.type] = true
  log.date = ->
    hour = do time.getHours
    hour = "0" + hour if hour < 10
    minute = do time.getMinutes
    minute = "0" + minute if minute < 10
    hour + ":" + minute
  log.html = marked log.text
  log

$(document).ready ->
  socket = io.connect "http://caasigd.org:8081"

  socket.on "expose", (o) ->
    thRee =
      # RPCs with namespace
      server: null#Actor o
      exts:
        chat:
          log: (log) ->
            log = Log log
            site.logs.push log
            $logs = $ ".logs"
            $logs.animate { scrollTop: $logs.prop "scrollHeight" }, duration
        username: (name) ->
          site.user.name name
          $.cookie "name", name, { expires: 14, path: "/" }
      # RPC utils
      exec: (cmd) ->
        prev = undefined
        current = this.exts
        ((key) ->
          prev = current
          current = current[key]
        ) key for key in cmd.keypath
        current?.apply prev, cmd.args

    ###
    thRee.server.on "bubble", (e, cmd) ->
      socket.emit "cmd", cmd
    ###

    socket.on "cmd", (cmd) ->
      thRee.exec cmd

    socket.emit "expose", DObject.expose thRee.exts

  socket.on "foobar", (foo) ->
    agentFoo = Agent DObject.validate foo
    agentFoo.on "bubble", (e, cmd) ->
      socket.emit "foobar.cmd", cmd
    agentFoo.count += 1

    socket.on "foobar.cmd", (cmd) ->
      agentFoo.exec cmd

  site =
    commandFromString: (str) ->
      return null if str.charAt(0) isnt "/"
      cmd =
        keypath: undefined,
        args: undefined
      str = str.substring 1
      cmd.args = str.split " "
      cmd.keypath = do cmd.args.shift
      cmd.keypath = cmd.keypath.split "."
      cmd
    # ko objects
    user:
      name: ko.observable($.cookie "name")
    logs: ko.observableArray()
    logsRendered: (elements) ->
      for element in elements
        do (element) ->
          $msg = $ element
          $msg.fadeIn duration
    send: (formElement) ->
      $msg = $(formElement).find "input"
      msg = $msg.val()
      if msg.length
        if msg.charAt(0) isnt "/"
          msg = "/say " + msg
        socket.emit "cmd", this.commandFromString msg
        $msg.val ""

  ko.applyBindings site
  
  # compute console height
  $window = $ window
  $wrap = $ "#wrap"

  $window.resize ->
    $wrap.height $window.height()

  $wrap.height $window.height()

  do $("input:last").focus
  
  # update cookie
  if site.user.name()
    $.cookie "name", site.user.name(), { expires: 14, path: "/" }
