module Sightline
  # What the Overview shows, as declared in Sightline.configure. Each block runs when the page is viewed.
  module Overview
    # Daily values for a list of dates, oldest first. A block may return them as an array (one per date)
    # or as a hash keyed by Date or "YYYY-MM-DD" (what SQL's date() groups by); missing days count 0.
    def self.align(dates, values)
      return Array(values) unless values.is_a?(Hash)

      dates.map { |date| values[date] || values[date.iso8601] || 0 }
    end

    # The last `days` days in the app's time zone, ending today.
    def self.dates(days)
      today = Time.zone.today
      ((today - (days - 1))..today).to_a
    end

    # A number in the row at the top: a label, a block returning the number, and an optional note
    # (a string or a block). format: :percent shows 42 as 42%; nil shows a dash.
    Stat = Data.define(:label, :block, :note, :format) do
      def value = block.call
      def note_text = note.respond_to?(:call) ? note.call : note
    end

    # A line chart of daily series. The block gets the dates and returns { "Series" => values }.
    # The legend shows each series' total: the sum, unless `totals` gives a block for that series.
    Trend = Data.define(:title, :days, :block, :totals) do
      def dates = Overview.dates(days)

      def series(dates = self.dates)
        block.call(dates).to_h { |name, values| [ name.to_s, Overview.align(dates, values) ] }
      end

      def total(name, values)
        totals.key?(name) ? totals[name].call : values.sum
      end
    end

    # A bar per day. The block gets the dates and returns the values.
    Bars = Data.define(:title, :days, :block) do
      def dates = Overview.dates(days)
      def values(dates = self.dates) = dates.zip(Overview.align(dates, block.call(dates)))
    end

    # A line of fine print under the charts: a string or a block.
    Note = Data.define(:text) do
      def to_s = text.respond_to?(:call) ? text.call.to_s : text.to_s
    end
  end
end
