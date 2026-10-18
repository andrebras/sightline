# Sightline

An admin area for a Rails app, as a mountable engine, in three sections:

- **Overview:** the numbers the app declares: stat cards, daily trend lines and bars per day, drawn on the server.
- **Health:** whether things are working: Solid Queue's processes, failed jobs and recurring tasks, free disk space,
  the app's own checks, and cards for the system and storage. A refresh picker reloads it every 5, 15 or 30 seconds.
- **Jobs:** [Mission Control – Jobs](https://github.com/rails/mission_control-jobs), mounted and set up by Sightline:
  inside the app's layout, behind the same admin check, job arguments hidden, look-only unless the app allows actions.

Sightline has no sign-in and no layout of its own. Its controllers inherit a controller of the app, so the app's
authentication and admin check decide who sees it, and its pages render inside the app's layout. Everything is
declared in one initializer. It needs Rails 8, Ruby 3.4 and Solid Queue, and brings Mission Control – Jobs with it.
Overview and Health use no JavaScript beyond a few lines for the refresh picker; Jobs uses Mission Control's.

## Install

```ruby
# Gemfile
gem "sightline", path: "gems/sightline"
```

```sh
bin/rails generate sightline:install --base-controller=Admin::BaseController --mount-at=/admin
```

The generator writes `config/initializers/sightline.rb`, adds the mount to `config/routes.rb`, and gives development
and test their own Solid Queue database, as production has, so Health and Jobs show real jobs locally. It changes
`config/database.yml` only when it has the plain SQLite shape `rails new` writes; otherwise it says what to add. Mount
Sightline after the app's own `/admin` routes, so they keep their paths: Sightline answers only its own paths.

Overview is then `/admin`, Health `/admin/health` and Jobs `/admin/jobs`. From the app, link to them with
`sightline.overview_path`, `sightline.health_path` and `sightline.jobs_path`. Don't mount Mission Control yourself.

## Configure

All of it goes in `config/initializers/sightline.rb`. Blocks run on each page view, never at boot, so they can use
the app's models and service objects.

```ruby
Sightline.configure do |c|
  # Required: the app's controller Sightline's controllers, and Jobs', inherit. Its before_actions, such as signing in
  # and an admin check that answers 404, apply to every page. Without it Sightline raises rather than serve anyone.
  c.base_controller = "Admin::BaseController"
  # The layout pages render in; nil (the default) keeps the base controller's own.
  c.layout = nil
  # The line above each page's title, and a line under the Overview's.
  c.title = "How Shop is doing"
  c.overview_intro = "Counted from orders and accounts."

  # Stats: a label, a block returning a number (nil shows a dash), an optional note (a string or a block)
  # and format: :percent for 42 → 42%.
  c.stat("Customers") { User.count }
  c.stat("Paid · 7 days", note: "orders") { Order.paid.where(created_at: 7.days.ago..).count }
  c.stat("Repeat buyers", format: :percent) { Report.new.repeat_share }

  # Trends: a line per series over the last `days` days (in the app's time zone). The block gets the dates, oldest
  # first, and returns { "Series" => values }, where values is an array (one per date) or a hash keyed by Date or
  # "YYYY-MM-DD", as SQL's date() groups them; missing days count 0. The legend shows each series' sum, unless
  # `totals` gives a block for it.
  c.trend "Last 30 days", days: 30, totals: { "Buyers" => -> { Order.where(created_at: 30.days.ago..).distinct.count(:user_id) } } do |dates|
    since = dates.first.beginning_of_day
    {
      "Buyers" => Order.where(created_at: since..).group("date(created_at)").distinct.count(:user_id),
      "Sign-ups" => User.where(created_at: since..).group("date(created_at)").count
    }
  end

  # Bars: one per day; the block gets the dates and returns values the same way.
  c.bars("Orders per day", days: 7) { |dates| Order.where(created_at: dates.first.beginning_of_day..).group("date(created_at)").count }

  # Fine print under the charts.
  c.note "Days are UTC."

  # Checks: the block returns Sightline.ok, Sightline.warning or Sightline.problem, with a summary and an optional
  # detail (a string or a list of lines). A check that raises, or returns anything else, shows as a problem.
  c.check("Payment webhooks") do
    last = PaymentEvent.maximum(:created_at)
    if last.nil? then Sightline.warning("None received yet")
    elsif last < 1.day.ago then Sightline.problem("None for a day", detail: "Last one #{last.to_fs(:short)}")
    else Sightline.ok("Last one #{last.to_fs(:short)}")
    end
  end

  # Pages of the app's own, after Overview, Health and Jobs in the navigation, at /admin/<path>.
  # The template renders inside Sightline's frame and can use the pieces below.
  c.page "Refunds", path: "refunds", template: "admin/refunds"

  # Section links (Overview, Health, Jobs, the app's pages) on every page. Turn them off when the app's own layout
  # already links the sections, so each is linked once.
  c.navigation = true

  # A decorative glyph at the right of a page's header, by page title (class sl-icon, hidden from screen readers).
  c.icons = { "Overview" => "▥", "Health" => "✓", "Jobs" => "⚙" }

  # Jobs, at /<mount>/jobs. false leaves it out; jobs_path links a jobs dashboard somewhere else instead.
  c.jobs = true
  c.jobs_path = nil
  # Off by default: Jobs refuses every request but GET (no retry, discard, pause or run now).
  c.job_actions = false
  # Off by default: job arguments can hold people's email addresses and names.
  c.show_job_arguments = false

  # Health's built-in checks. nil turns the Solid Queue ones on when the app has Solid Queue.
  c.solid_queue_checks = nil
  # How long a recurring task's run may take to be recorded after its scheduled time before it counts as missed.
  c.recurring_grace = 2.minutes
  # Free space on the volume holding storage_path (nil: the directory of the first SQLite database), in percent:
  # below the first a warning, below the second a problem. storage_check = false leaves the card and check out.
  c.storage_path = nil
  c.storage_warning_below = 20
  c.storage_problem_below = 10
  c.storage_check = true
end
```

### Inside the app's layout

Sightline is an isolated engine, so its own route helpers are `overview_path`, `health_path` and `app_page_path`.
Every other route helper the app has (`root_path`, `new_session_path`...) is sent to the app's routes, in Sightline's
controllers and views alike, so the app's before_actions and layout work unchanged. If the app has its own route
named `overview`, `health` or `app_page`, use `main_app.` for it in the layout. Sightline sets `content_for :title`
to the page's name.

## Health

- **Job processes:** Solid Queue's processes and their last heartbeat. Alive means a heartbeat within
  `SolidQueue.process_alive_threshold`. None alive, or none at all, is a problem; some not responding, a warning.
- **Failed jobs:** how many, with the latest five errors (job class, error class and message, never the job's
  arguments) and a link to Mission Control's failed list.
- **Recurring tasks:** for each `SolidQueue::RecurringTask`, its schedule (Fugit, in `SolidQueue.time_zone` when the
  schedule names none, as the scheduler does) gives the latest time it should have run, at least `recurring_grace`
  ago. If its latest `SolidQueue::RecurringExecution` is older, it is overdue, a problem. A task registered after that
  time is not due yet. Execution records go when Solid Queue clears finished jobs (`clear_finished_jobs_after`), so a
  missing record older than that is shown as "run not kept", not as overdue.
- **Disk space:** from `df -Pk` on the storage path, against the thresholds above.
- The app's own checks, then the **System** card (Ruby, Rails, when the process booted, its memory from
  `/proc/self/status` or `ps`, and on Fly.io the deployment and region from `FLY_IMAGE_REF` and `FLY_REGION`, else
  "Running locally") and the **Storage** card (free space and each SQLite database's size, with its WAL), and a table
  of recurring tasks with their last and next run.

The refresh picker keeps its choice in the URL (`/admin/health?refresh=15`).

## Jobs

Jobs is Mission Control – Jobs, which Sightline mounts at `/<mount>/jobs` and sets up (`lib/sightline/jobs.rb`):

- **Access:** Mission Control's controllers inherit `c.base_controller`, like Sightline's, and its password prompt is
  off. Solid Queue is its queue.
- **Layout:** its pages render inside the app's layout (`c.layout`, else `application`), under Sightline's header
  and navigation, without Mission Control's Bulma stylesheet, whose global classes would restyle the app;
  `sightline/jobs.css` styles its screens with the same `--sl-*` properties. Its scripts go in the head, so the app's
  layout should `yield :head`. The app's own route helpers work in that layout, as on Sightline's pages.
- **Job arguments:** hidden in every list and on a job's page unless `c.show_job_arguments = true`.
- **One server:** Mission Control's `server_id` is left out of links when the app has one job server.
- **Actions:** Mission Control can retry, discard, dispatch, pause and resume queues, and run recurring tasks now.
  Unless `c.job_actions = true`, any request other than GET or HEAD gets 403 "Job actions are turned off." The check
  runs after the base controller's own, so visitors who aren't admins still get what the app gives them. Mission
  Control's buttons still show; pressing one does nothing.

When upgrading Mission Control, compare its layout with `lib/sightline/jobs_views/layouts/mission_control/jobs/
application.html.erb` and look over its screens.

## Pieces

Overview and Health are built from these helpers (`Sightline::PiecesHelper`), which the app's own pages
(`c.page`) can use too. Outside Sightline's pages, add `helper Sightline::PiecesHelper`, wrap the page in
`<div class="sl">` and load `stylesheet_link_tag "sightline/application"`.

| Helper | Shows |
|---|---|
| `sl_section(title, link: [label, url]) { ... }` | A titled block |
| `sl_stats { ... }` with `sl_stat(label, value, note:, format:, status:)` | A row of stat cards |
| `sl_trend(dates, { "Series" => values }, totals: {})` | A server-drawn SVG line chart |
| `sl_bars([[date, value], ...])` | A bar per day |
| `sl_checks { ... }` with `sl_check(name, Sightline.ok("..."))` | Health check lines |
| `sl_card(title, [[label, value], ...])` | A card of labelled facts |
| `sl_table(headers, rows, empty: "Nothing yet.")` | A table that stacks on a phone |

## Styles

Every class starts with `sl-`, inside `.sl`. Colours and fonts are custom properties with neutral defaults
(set with `:where(.sl)`, so any rule of the app wins); override them on `.sl`:

```css
.sl{--sl-accent:#486440;--sl-font-heading:Georgia,serif}
```

| Property | Used for |
|---|---|
| `--sl-ink`, `--sl-muted`, `--sl-label` | Text, secondary text, small-caps labels |
| `--sl-accent` | Links, the current tab, bars |
| `--sl-surface`, `--sl-surface-alt`, `--sl-line` | Panels, table headers, borders |
| `--sl-ok`, `--sl-warning`, `--sl-problem` and their `-soft` backgrounds | Check states and the headline |
| `--sl-series-1` to `--sl-series-6` | Trend lines, in the series' order |
| `--sl-radius`, `--sl-font`, `--sl-font-heading` | Corners and type |

The stylesheet is linked from each page, so the app's layout needs nothing added.

## Tests

```sh
cd gems/sightline && bin/test
```

The tests run against a dummy app (`test/dummy`) with Solid Queue's tables, created from Solid Queue's own schema,
using real records; Jobs is Sightline's own, as in any app. The engine has its own `Gemfile` and lint config
(`bundle exec rubocop`).
