$ = jQuery

duration = 500

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

DObject = (o) ->
  agent = Ree o
  agent.exec = (cmd) ->
    Ree.exec this, cmd
  agent.expose = ->
    DObject.expose o
  agent

DObject.interface = (o) ->
  agent = Ree o
  agent.exec = (cmd) ->
    Ree.exec o, cmd
  agent

DObject.validate = (o) ->
  if _.isArray(o) or _.isNumber(o) or _.isString(o) or _.isBoolean(o)
    ret = o
  else if _.isFunction o
    ret = o
  else if _.isObject o
    if o.type? and o.type is "function"
      ret = ->
    else
      ret = o
  if _.isFunction(o) or _.isObject(o)
    ((key) ->
      return if key is "type"
      ret[key] = DObject.validate o[key]
    ) key for key of o
  ret

DObject.expose = (o) ->
  if _.isArray(o) or _.isNumber(o) or _.isString(o) or _.isBoolean(o)
    ret = o
  else if _.isFunction o
    ret = { type: "function" }
  else if _.isObject o
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
