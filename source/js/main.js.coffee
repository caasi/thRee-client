$ = jQuery

duration = 500

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
  socket.on "object", ->
    socket.emit "object", thRee.struct thRee.exts
  socket.on "cmd", (cmd) ->
    thRee.exec cmd

  thRee =
    # RPCs with namespace
    exts:
      chat:
        log: (log) ->
          log = Log log
          thRee.logs.push log
          $logs = $ ".logs"
          $logs.animate { scrollTop: $logs.prop "scrollHeight" }, duration
      username: (name) ->
        thRee.user.name name
        $.cookie "name", name, { expires: 14, path: "/" }
    # RPC utils
    struct: (o) ->
      ret = {}
      ((key) ->
        ret[key] = thRee.struct o[key]
      ) key for key of o
      ret
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
    exec: (cmd) ->
      prev = undefined
      current = this.exts
      ((key) ->
        prev = current
        current = current[key]
      ) key for key in cmd.keypath
      current?.apply prev, cmd.args
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

  ko.applyBindings thRee

  # compute console height
  $window = $ window
  $wrap = $ "#wrap"

  $window.resize ->
    $wrap.height $window.height()

  $wrap.height $window.height()

  do $("input:last").focus
  
  # update cookie
  if thRee.user.name()
    $.cookie "name", thRee.user.name(), { expires: 14, path: "/" }
