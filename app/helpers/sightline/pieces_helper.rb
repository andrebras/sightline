module Sightline
  # The pieces Sightline's pages are built from: section, stat card, trend chart, bar chart, check row and table.
  # An app's own pages (c.page) can use them too; outside Sightline, add `helper Sightline::PiecesHelper` and wrap
  # the page in <div class="sl"> with the sightline/application stylesheet.
  module PiecesHelper
    # A titled block, with an optional link on the right: sl_section("Last 30 days", link: ["All", url]) { ... }
    def sl_section(title, link: nil, id: nil, &)
      render "sightline/pieces/section", title: title, link: link, id: id, body: capture(&)
    end

    # A row of stat cards: sl_stats { sl_stat("Players", 12) + sl_stat("Games", 3, note: "this week") }
    def sl_stats(&)
      tag.div(capture(&), class: "sl-stats")
    end

    # One number with its label and an optional note; status (:ok, :warning, :problem) colours it.
    def sl_stat(label, value, note: nil, format: nil, status: nil)
      render "sightline/pieces/stat", label: label, value: sl_format(value, format), note: note, status: status
    end

    # A line chart drawn on the server: dates (oldest first) and { "Series" => [value per date] }.
    # totals: { "Series" => number } replaces a series' sum in the legend.
    def sl_trend(dates, series, totals: {}, label: nil)
      render "sightline/pieces/trend", dates: dates, series: series, totals: totals,
                                       label: label || "#{series.keys.to_sentence} by day"
    end

    # A bar per day: [[date, value], ...], oldest first.
    def sl_bars(values, label: nil)
      render "sightline/pieces/bars", values: values, label: label
    end

    # A plain table: headers and rows of cells (strings or HTML).
    def sl_table(headers, rows, empty: "Nothing yet.")
      render "sightline/pieces/table", headers: headers, rows: rows, empty: empty
    end

    def sl_format(value, format = nil)
      case value
      when nil then "–"
      when Numeric then format == :percent ? number_to_percentage(value, precision: 0) : number_with_delimiter(value)
      else value.to_s
      end
    end
  end
end
