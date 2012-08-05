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

  # game loop for everybody
  requestAnimationFrame = window.requestAnimationFrame or
                          window.webkitRequestAnimationFrame or
                          window.mozRequestAnimationFrame or
                          window.oRequestAnimationFrame or
                          window.msRequestAnimationFrame or
                          (cc) ->
                            window.setTimeout cc, 1000 / 60
  game = new EventEmitter2
  game.lastInvoke = 0
  do game.loop = ->
    requestAnimationFrame game.loop
    now = do Date.now
    delta = now - game.lastInvoke
    game.emit "update", now, delta
    game.lastInvoke = now
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
      if recorder.timeStart and (cmd.type is "set")
        cmd.time = Date.now() - recorder.timeStart
        controlLog.push cmd
    controlLog = []

    recorder = new EventEmitter2()
    recorder.stage = {}
    recorder.avatar = {}
    recorder.timeLimit = 0
    recorder.timeStart = 0
    recorder.start = ->
      control.top = control.down = control.left = control.right = false
      $avatar.css "left", (recorder.stage.width - recorder.avatar.width) / 2 + "px"
      $avatar.css "top", (recorder.stage.height - recorder.avatar.height) / 2 + "px"
      recorder.timeStart = do Date.now
      recorder.timeLimit = recorder.timeStart + 5000
      game.on "update", recorder.loop
      recorder.emit "start"
    recorder.end = ->
      game.off "update", recorder.loop
      recorder.timeStart = recorder.timeLimit = 0
      recorder.emit "end"
    recorder.loop = (now, delta) ->
      $time.text Math.ceil (recorder.timeLimit - now) / 1000
      newX = x = parseInt $avatar.css "left"
      newY = y = parseInt $avatar.css "top"
      newY = y - 1 if control.up
      newY = y + 1 if control.down
      newX = x - 1 if control.left
      newX = x + 1 if control.right
      newX = 0 if newX < 0
      newX = recorder.stage.width - recorder.avatar.width if newX > recorder.stage.width - recorder.avatar.width
      newY = 0 if newY < 0
      newY = recorder.stage.height - recorder.avatar.height if newY > recorder.stage.height - recorder.avatar.height
      $avatar.css "left", newX + "px" if newX isnt x
      $avatar.css "top", newY + "px" if newY isnt y
      do recorder.end if now > recorder.timeLimit


    $doc = $ document
    $record = $ "#record"
    $play = $ "#play"
    $stage = $ "#stage"
    $time = $ "#time"
    $avatar = $ "#avatar"

    recorder.stage.width = parseInt $stage.width()
    recorder.stage.height = parseInt $stage.height()
    recorder.avatar.width = parseInt $avatar.width()
    recorder.avatar.height = parseInt $avatar.height()

    onKeydown = (e) ->
      control[keymap[e.keyCode]] = true if not control[keymap[e.keyCode]]
    onKeyup = (e) ->
      control[keymap[e.keyCode]] = false

    $record.click ->
      do recorder.start
      controlLog = []
      $doc.keydown onKeydown
      $doc.keyup onKeyup
      $record.attr "disabled", true
      $play.attr "disabled", true
      recorder.on "end", ->
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
            if log and log.time < now - recorder.timeStart
              Ree.exec controlSource, log
              index += 1
            else
              break
        do recorder.start
        game.on "update", replayLoop
        recorder.on "end", ->
          $play.attr "disabled", false
          game.off "update", replayLoop

  # game of life
  do ->
    Cell = (color) ->
      c = document.createElement "canvas"
      c.width = 10
      c.height = 10
      ctx = c.getContext "2d"
      ctx.fillStyle = "rgb(204, 204, 204)"
      ctx.fillRect 0, 0, 10, 10
      ctx.fillStyle = color
      ctx.fillRect 0, 0, 9.5, 9.5
      c
    socket.on "life", (life) ->
      agentLife = Ree DObject.validate life
      cells = []
      cellAlive = Cell "rgb(255, 153, 0)"
      cellDead = Cell "rgb(255, 255, 255)"
      $stage = $ "#life .stage"
      stageCanvas = document.createElement "canvas"
      stageCanvas.width = life.width * 10
      stageCanvas.height = life.height * 10
      $stageCanvas = $ stageCanvas
      stageCanvas.buffer = new Uint8Array new ArrayBuffer 2400
      stageCanvas.current = 0
      stageCanvas.sync = ->
        stageCanvas.current = 0
        for y in [0..life.height - 1]
          for x in [0..life.width - 1]
            ((x, y) ->
              stageCanvas.lineUp x, y, life.world[x + y * life.width]
            ) x, y
      stageCanvas.lineUp = (x, y) ->
        stageCanvas.buffer[stageCanvas.current] = x
        stageCanvas.buffer[stageCanvas.current + 1] = y
        stageCanvas.current += 2
      stageCanvas.drawCell = (x, y, isAlive) ->
        ctx = stageCanvas.getContext "2d"
        ctx.drawImage (if isAlive then cellAlive else cellDead), x * 10, y * 10
      stageCanvas.loop = (now, delta) ->
        if stageCanvas.current isnt 0
          ctx = stageCanvas.getContext "2d"
          i = 0
          while i < stageCanvas.current
            x = stageCanvas.buffer[i]
            y = stageCanvas.buffer[i + 1]
            isAlive = life.world[x + y * life.width]
            ctx.drawImage (if isAlive then cellAlive else cellDead), x * 10, y * 10
            i += 2
          stageCanvas.current = 0
      game.on "update", stageCanvas.loop
      do stageCanvas.sync
      $(window).focus ->
        do stageCanvas.sync

      $stageCanvas.click (e) ->
        x = (e.offsetX / 10) | 0
        y = (e.offsetY / 10) | 0
        agentLife.glider x, y
      $stage.append $stageCanvas

      agentLife.on "bubble", (cmd) ->
        socket.emit "life.cmd", cmd

      removeCmd = (cmd) ->
        ((key) ->
          delete cmd.keypath[key]
        ) key for key in cmd.keypath
        ((key) ->
          delete cmd.args[key]
        ) key for key in cmd.args
        delete cmd.keypath
        delete cmd.args

      socket.on "life.cmd", (cmd) ->
        Ree.exec life, cmd
        index = parseInt cmd.keypath[cmd.keypath.length - 1], 10
        x = (index % life.width) | 0
        y = (index / life.width) | 0
        stageCanvas.lineUp x, y
        removeCmd cmd
        cmd = null
