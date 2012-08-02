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
  #socket = io.connect "http://caasigd.org:8081/"

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

  # recorder
  do ->
    fps = 60
    interval = 1000 / fps

    keymap =
      "38": "up"
      "40": "down"
      "37": "left"
      "39": "right"

    controlSource =
      up: false
      down: false
      left: false
      right: false

    control = Ree controlSource
    control.on "bubble", (cmd) ->
      if startTime and (cmd.type is "set")
        cmd.time = Date.now() - startTime
        controlLog.push cmd
    controlLog = []
    startTime = null

    game = new EventEmitter2
    game.limit = 5000
    game.lastInvoke = 0
    game.stage = {}
    game.avatar = {}
    game.start = ->
      control.top = control.down = control.left = control.right = false
      $avatar.css "left", (game.stage.width - game.avatar.width) / 2 + "px"
      $avatar.css "top", (game.stage.height - game.avatar.height) / 2 + "px"
      startTime = do Date.now
      game.on "update", mainLoop
      game.emit "start"
    game.end = ->
      game.off "update", mainLoop
      startTime = 0
      game.emit "end"
    setInterval ->
      now = do Date.now - startTime
      delta = now - game.lastInvoke
      game.emit "update", now, delta
      game.lastInvoke = now
    , interval

    $doc = $ document
    $record = $ "#record"
    $play = $ "#play"
    $stage = $ "#stage"
    $time = $ "#time"
    $avatar = $ "#avatar"

    game.stage.width = parseInt $stage.width()
    game.stage.height = parseInt $stage.height()
    game.avatar.width = parseInt $avatar.width()
    game.avatar.height = parseInt $avatar.height()

    mainLoop = (now, delta) ->
      $time.text Math.ceil (game.limit - now) / 1000
      newX = x = parseInt $avatar.css "left"
      newY = y = parseInt $avatar.css "top"
      newY = y - 1 if control.up
      newY = y + 1 if control.down
      newX = x - 1 if control.left
      newX = x + 1 if control.right
      newX = 0 if newX < 0
      newX = game.stage.width - game.avatar.width if newX > game.stage.width - game.avatar.width
      newY = 0 if newY < 0
      newY = game.stage.height - game.avatar.height if newY > game.stage.height - game.avatar.height
      $avatar.css "left", newX + "px" if newX isnt x
      $avatar.css "top", newY + "px" if newY isnt y
      do game.end if now > game.limit

    onKeydown = (e) ->
      control[keymap[e.keyCode]] = true if not control[keymap[e.keyCode]]
    onKeyup = (e) ->
      control[keymap[e.keyCode]] = false

    $record.click ->
      do game.start
      controlLog = []
      $doc.keydown onKeydown
      $doc.keyup onKeyup
      $record.attr "disabled", true
      $play.attr "disabled", true
      game.on "end", ->
        do $doc.off
        $record.attr "disabled", false
        $play.attr "disabled", false

    $play.
      attr("disabled", true).
      click ->
        $play.attr "disabled", true
        index = 0
        replayLoop = (now, delta) ->
          loop
            log = controlLog[index]
            if not log or log.time > now
              break
            else
              Ree.exec controlSource, controlLog[index]
              index += 1
        do game.start
        game.on "update", replayLoop
        game.on "end", ->
          $play.attr "disabled", false

  # game of life
  do ->
    socket.on "life", (life) ->
      console.log life
      agentLife = Ree DObject.validate life
      cells = []
      $stage = $ "#life .stage"
      $canvas = $ "<canvas width=\"" + life.width * 10 + "\" height =\"" + life.height * 10 + "\"></canvas>"
      $canvas.drawCell = (x, y, isAlive) ->
        x *= 10
        y *= 10
        ctx = $canvas.get()[0].getContext "2d"
        ctx.fillStyle = "rgb(204, 204, 204)"
        ctx.fillRect x, y, 10, 10
        ctx.fillStyle = if isAlive then "rgb(0, 0, 0)" else "rgb(255, 255, 255)"
        ctx.fillRect x, y, 9.5, 9.5
        return this
      $canvas.click (e) ->
        x = Math.floor e.offsetX / 10
        y = Math.floor e.offsetY / 10
        agentLife.glider x, y
      $stage.append $canvas
      for y in [0..life.height - 1]
        for x in [0..life.width - 1]
          ((x, y) ->
            $canvas.drawCell x, y, life.world[x + y * life.width]
          ) x, y

      agentLife.on "bubble", (cmd) ->
        socket.emit "life.cmd", cmd

      socket.on "life.cmd", (cmd) ->
        Ree.exec life, cmd
        index = parseInt cmd.keypath[cmd.keypath.length - 1], 10
        x = Math.floor index % life.width
        y = Math.floor index / life.width
        $canvas.drawCell x, y, life.world[index]
