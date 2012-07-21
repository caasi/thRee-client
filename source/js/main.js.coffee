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

Actor = (o) ->
  ret = EventEmitter (args...) ->
    ret.emit "bubble",
      keypath: []
      args: args
  ((key) ->
    actor = Actor o[key]
    actor.on "bubble", (e, cmd) ->
      cmd.keypath = [key].concat cmd.keypath
      ret.emit "bubble", cmd
    ret[key] = actor
  ) key for key of o if o
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
      server: Actor o
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
      struct: (o) ->
        ret = {}
        ((key) ->
          ret[key] = thRee.struct o[key]
        ) key for key of o
        ret
      exec: (cmd) ->
        prev = undefined
        current = this.exts
        ((key) ->
          prev = current
          current = current[key]
        ) key for key in cmd.keypath
        current?.apply prev, cmd.args

    thRee.server.on "bubble", (e, cmd) ->
      socket.emit "cmd", cmd

    socket.on "cmd", (cmd) ->
      thRee.exec cmd

    socket.emit "expose", thRee.struct thRee.exts

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
