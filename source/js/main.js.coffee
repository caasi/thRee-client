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

  socket.on "log", (data) ->
    console.log data
    data = Log data
    three.logs.push data
    $logs = $ ".logs"
    $logs.animate { scrollTop: $logs.prop "scrollHeight" }, duration

  socket.on "user", (user) ->
    three.user.name user.name
    $.cookie "name", user.name, { expires: 14, path: "/" }

  three =
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
        socket.emit "command", msg
        $msg.val ""

  ko.applyBindings three

  $window = $ window
  $wrap = $ "#wrap"

  $window.resize ->
    $wrap.height $window.height()

  $wrap.height $window.height()

  do $("input:last").focus
  
  # update cookie
  $.cookie "name", three.user.name(), { expires: 14, path: "/" }
