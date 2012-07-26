$ = jQuery

duration = 500

isObject = (o) ->
  o? and o is Object o

isFunction = (o) ->
  typeof o is "function"

isNumber = (o) ->
  Object.prototype.toString.call(o) is "[object Number]"

isString = (o) ->
  Object.prototype.toString.call(o) is "[object String]"

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

Command = (str) ->
  return null if str.charAt(0) isnt "/"
  cmd =
    keypath: undefined,
    args: undefined
  str = str.substring 1
  cmd.args = str.split " "
  cmd.keypath = do cmd.args.shift
  cmd.keypath = cmd.keypath.split "."
  cmd

Command.exec = (o, cmd) ->
  prev = undefined
  current = o
  ((key) ->
    prev = current
    current = current?[key]
  ) key for key in cmd.keypath
  return if not current
  if cmd.type is "msg"
    return Function.prototype.apply.call current, prev, cmd.args
  else
    if cmd.type is "get"
      return prev[cmd.keypath[cmd.keypath.length - 1]]
    if cmd.type is "set"
      prev[cmd.keypath[cmd.keypath.length - 1]] = cmd.args[0]

Agent = (target, thisArg) ->
  if Array.isArray target
    ret = null
  else if isFunction target
    ret = (args...) ->
      target.apply thisArg, arguments
      ret.emit "bubble",
        type: "msg"
        keypath: []
        args: args
  else if isNumber(target) or isString(target)
    ret = null
  else if isObject target
    ret = {}

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
  ret

DObject = (o) ->
  agent = Agent o
  agent.exec = (cmd) ->
    Command.exec this, cmd
  agent.expose = ->
    DObject.expose o
  agent

DObject.interface = (o) ->
  agent = Agent o
  agent.exec = (cmd) ->
    Command.exec o, cmd
  agent

DObject.validate = (o) ->
  if Array.isArray o
    ret = o
  else if isFunction o
    ret = o
  else if isNumber(o) or isString(o)
    ret = o
  else if isObject o
    if o.type? and o.type is "function"
      ret = ->
    else
      ret = o
  if isFunction(o) or isObject(o)
    ((key) ->
      return if key is "type"
      ret[key] = DObject.validate o[key]
    ) key for key of o
  ret

DObject.expose = (o) ->
  if Array.isArray o
    ret = o
  else if isFunction o
    ret = { type: "function" }
  else if isNumber(o) or isString(o)
    ret = o
  else if isObject o
    ret = {}
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
  socket = io.connect "http://caasi.three.jit.su:80/"

  thRee =
    prev_name: $.cookie "name"
    log: (log) ->
      logs.list.push Log log
      $logs = $ "#logs"
      $logs.animate { scrollTop: $logs.prop "scrollHeight" }, duration
    name: (name) ->
      input.name name
      $.cookie "name", name, { expires: 14 }
  agent = DObject thRee
  agent.on "bubble", (e, cmd) ->
    socket.emit "thRee.cmd", cmd
  socket.on "thRee.cmd", (cmd) ->
    agent.exec cmd

  socket.emit "thRee", do agent.expose

  logs =
    list: ko.observableArray()
    didRendered: (elements) ->
      for element in elements
        do (element) ->
          $msg = $ element
          $msg.fadeIn duration

  ko.applyBindings logs, $("#logs").get()[0]

  input =
    name: ko.observable $.cookie("name") or "?"
    send: (formElement) ->
      $msg = $(formElement).find "input"
      msg = $msg.val()
      if msg.length
        if msg.charAt(0) isnt "/"
          msg = "/say " + msg
        socket.emit "cmd", Command msg
        $msg.val ""

  ko.applyBindings input, $("#input").get()[0]

  # compute height of the console
  $window = $ window
  $wrap = $ "#wrap"

  $window.resize ->
    $wrap.height $window.height()

  $wrap.height $window.height()

  do $("input:last").focus
