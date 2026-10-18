module Sightline
  # Everything an app declares about its admin area, in one `Sightline.configure` block.
  # Blocks are stored and called on each page view, never at boot, so they may use the app's reloadable classes.
  class Configuration
    Page = Data.define(:title, :path, :template)

    # The app's controller the engine's controllers inherit from: its sign-in and admin check apply to every page.
    attr_accessor :base_controller
    # The layout pages render in; nil keeps the base controller's own layout.
    attr_accessor :layout
    # Shown above each page's title, e.g. the app's name.
    attr_accessor :title
    # A line under the Overview's title.
    attr_accessor :overview_intro
    # The jobs dashboard's path for the navigation; nil finds Mission Control – Jobs' mount point, if any.
    attr_accessor :jobs_path

    attr_reader :stats, :charts, :notes, :pages

    def initialize
      @base_controller = "ActionController::Base"
      @layout = nil
      @title = "Admin"
      @overview_intro = nil
      @jobs_path = nil
      @stats = []
      @charts = []
      @notes = []
      @pages = []
    end

    # A number on the Overview: c.stat("Players") { User.count }
    def stat(label, note: nil, format: nil, &block)
      @stats << Overview::Stat.new(label: label, block: block, note: note, format: format)
    end

    # A daily line chart, one line per series:
    # c.trend("Last 30 days", days: 30) { |dates| { "Sign-ups" => User.group("date(created_at)").count } }
    def trend(title, days: 30, totals: {}, &block)
      @charts << Overview::Trend.new(title: title, days: days, block: block, totals: totals.transform_keys(&:to_s))
    end

    # A bar per day: c.bars("Orders per day", days: 7) { |dates| Order.group("date(created_at)").count }
    def bars(title, days: 7, &block)
      @charts << Overview::Bars.new(title: title, days: days, block: block)
    end

    # Fine print under the Overview's charts, e.g. what the numbers leave out.
    def note(text = nil, &block)
      @notes << Overview::Note.new(text: block || text)
    end

    # A page of the app's own, listed in the navigation after Overview, Health and Jobs, at /<mount>/<path>.
    # The template renders inside Sightline's frame and can use the same pieces (Sightline::PiecesHelper).
    def page(title, path:, template:)
      @pages << Page.new(title: title, path: path.to_s, template: template)
    end

    def find_page(path) = pages.find { |page| page.path == path.to_s }
  end
end
