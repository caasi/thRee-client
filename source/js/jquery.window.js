(function($) {
  var methods = {
    init: function(options) {
      var settings = $.extend({
        "title": "untitled",
        "prefPosition": function(width, height) {
          return {
            x: width / 2,
            y: height / 5 * 3
          };
        },
        "prefStageSize": function(width, height) {
          return {
            width: 100,
            height: 100
          };
        }
      }, options);

      return this.each(function() {
        var $this = $(this);
        var $title = $this.find(".title");
        var $stage = $this.find(".stage");
        var $win = $(window);
        var onWindowResize, offset;
        var isDragging = false, delta;

        if (!$stage) return null;

        $title.text(settings.title);

        (onWindowResize = function(e) {
          var width = $win.width();
          var height = $win.height();
          var size = settings.prefStageSize(width, height);
          $stage.
            width(size.width).
            height(size.height);
        })();

        $win.resize(onWindowResize);

        offset = settings.prefPosition($win.width(), $win.height());

        $this.
          mousedown(function(e) {
            e.stopPropagation();
            isDragging = true;
            delta = $this.offset();
            delta.left -= e.clientX;
            delta.top -= e.clientY;

            $win.
              mousemove(function(e) {
                if (isDragging) {
                  $this.offset({
                    left: e.clientX + delta.left,
                    top: e.clientY + delta.top
                  });
                }
              }).
              mouseup(function(e) {
                isDragging = false;
                $win.
                  off("mousemove").
                  off("mouseup");
              });
          }).
          offset({
            left: offset.x,
            top: offset.y
          });
      });
    },
    load: function(url) {
      return this.each(function() {
      });
    }
  };

  $.fn.window = function(method) {
    if (methods[method]) {
      return methods[method].apply(this, Array.prototype.slice.call(arguments, 1));
    } else if (typeof method === 'object' || !method) {
      return methods.init.apply(this, arguments);
    } else {
      $.error("Method " + method + "does not exist on jQuery.frmplayer");
    }
  };
})(jQuery);
