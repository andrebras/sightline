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
    # Whether Mission Control – Jobs may change anything (retry, discard, pause, run now). Off by default:
    # every request other than GET is refused.
    attr_accessor :job_actions

    # Health's built-in checks of Solid Queue's processes, failed jobs and recurring tasks.
    # nil (the default) turns them on when the app has Solid Queue.
    attr_accessor :solid_queue_checks
    # How long after its scheduled time a recurring task's run may take to be recorded before it counts as missed.
    attr_accessor :recurring_grace

    # The directory whose volume's free space Health checks; nil uses the directory of the first SQLite database.
    attr_accessor :storage_path
    # Free space, in percent of the volume, below which Health shows a warning and then a problem.
    attr_accessor :storage_warning_below, :storage_problem_below
    # false leaves the Storage card and the disk space check out, e.g. for an app without local databases.
    attr_accessor :storage_check

    attr_reader :stats, :charts, :notes, :checks, :pages

    def initialize
      @base_controller = "ActionController::Base"
      @layout = nil
      @title = "Admin"
      @overview_intro = nil
      @jobs_path = nil
      @job_actions = false
      @solid_queue_checks = nil
      @recurring_grace = 2.minutes
      @storage_path = nil
      @storage_warning_below = 20
      @storage_problem_below = 10
      @storage_check = true
      @stats = []
      @charts = []
      @notes = []
      @checks = []
      @pages = []
    end

    def solid_queue_checks?
      @solid_queue_checks.nil? ? defined?(SolidQueue::Process).present? : @solid_queue_checks
    end

    # An app's own health check, shown after the built-in ones. The block returns
    # Sightline.ok(summary), Sightline.warning(summary, detail: ...) or Sightline.problem(...).
    def check(name, &block)
      @checks << Check.new(name: name, block: block)
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
