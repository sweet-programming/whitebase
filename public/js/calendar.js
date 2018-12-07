(function($) {
  $.fn.wb_calendar = function(options) {
    var today = new Date();
    var defaults = {
      "year" : today.getFullYear(),
      "month" : today.getMonth() + 1
    };

    var setting = $.extend(defaults, options);

    var elements = this;

    elements.each(function() {
      var day = new Date(setting.year, setting.month - 1, 1);

      var $table = $("<table>", { class: "wb_calendar_table" });
      var $header = $("<thead>");
      var $calendar_header = $("<th>", {class: "calendar_header", colspan: 7});
      $calendar_header
          .append($('<h3>')
            .append($("<a>").css({ color:"#fff" }).text("<< "))
            .append($("<span>", { class: "header_text", text: day.strftime("%B %Y") }))
            .append($("<a>").css("color", "#fff").text(" >>")));
      $header.append($("<tr>").append($calendar_header));
      $header
          .append($("<tr>")
            .append($("<th>").append("mon"))
            .append($("<th>").append("tue"))
            .append($("<th>").append("wed"))
            .append($("<th>").append("thu"))
            .append($("<th>").append("fri"))
            .append($("<th>").append("sat"))
            .append($("<th>").append("sun")));
      $table.append($header);

      var $body = $("<tbody>");
      for (var row = 0; row < 5; row ++) {
        $row = $("<tr>");
        for (var col = 0; col < 7; col ++) {
          if (row == 0) {
            var firstDayOfWeek = day.getDay() <= 0 ? 6 : day.getDay() - 1;
            if (firstDayOfWeek > col) {
              $row.append($("<td>").append($("<div>", { class: 'wb_calendar_cell' })));
              continue;
            }
          }
          if (day.getMonth() != setting.month - 1) {
            $row.append($("<td>").append($("<div>", { class: 'wb_calendar_cell' })));
            continue;
          }
          date_class = day.strftime("wb_calendar_date_%Y-%m-%d");
          $row.append($("<td>")
                .append($("<div>", { class: "wb_calendar_cell" })
                  .append($("<a>", { href: day.strftime("/%Y-%m-%d") })
                    .append($("<div>", { class: date_class })
                      .append($("<p>").css({ color: "#000", opacity: 0.8 }).text(day.getDate()))))));

          day = new Date(day.getFullYear(), day.getMonth(), day.getDate() + 1);
        }
        $body.append($row);
      }
      $table.append($body);
      $(this).append($table);
    });
    var today = new Date();
  }
})(jQuery);
