(function($) {
  var methods = {
    init: function(options) {
      return this.each(function() {
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
        var $this = $(this);
        var $title = $this.find(".title");
        var $stage = $this.find(".stage");
        var $win = $(window);
        var onWindowResize, offset;
        var isDragging = false, delta;

        if (!$stage) return null;

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
          css("left", offset.x).
          css("top", offset.y);

        $title.
          text(settings.title).
          mousedown(function(e) {
            e.stopPropagation();
            console.log(this);
            isDragging = true;
            delta = $this.position();
            delta.left -= e.pageX;
            delta.top -= e.pageY;

            $win.
              mousemove(function(e) {
                if (isDragging) {
                  $this.
                    css("left", e.pageX + delta.left).
                    css("top", e.pageY + delta.top);
                }
              }).
              mouseup(function(e) {
                isDragging = false;
                $win.
                  off("mousemove").
                  off("mouseup");
              });
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
