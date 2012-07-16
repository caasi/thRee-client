$ = jQuery

duration = 500

Log = (log) ->
  log.classes = {}
  log.classes[log.type] = true
  log

$(document).ready ->
  socket = io.connect "http://caasigd.org:8081"

  socket.on "log", (data) ->
    data = Log data
    three.logs.push data
    $logs = $ ".logs"
    $logs.animate { scrollTop: $logs.prop "scrollHeight" }, duration

  socket.on "user", (user) ->
    three.user.name user.name

  three =
    user:
      name: ko.observable("guest")
    logs: ko.observableArray()
    logsRendered: (elements) ->
      for element in elements
        do (element) ->
          $msg = $ element
          $msg.css {opacity: 0}
          $msg.fadeTo duration, 1
    send: (formElement) ->
      $msg = $(formElement).find "input"
      msg = $msg.val()
      if msg.length
        socket.emit "msg", msg

        if msg.charAt(0) isnt "/"
          this.logs.push Log {
            name: this.user.name()
            text: msg
            type: "self"
          }
          $logs = $ ".logs"
          $logs.animate { scrollTop: $logs.prop "scrollHeight" }, duration

        $msg.val ""

  ko.applyBindings three
  do $("input:last").focus
