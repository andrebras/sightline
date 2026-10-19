# Sightline

**An admin dashboard for your Rails app, in your app's own look: your numbers, whether everything is working, and
your background jobs. One gem, one generator, one initializer.**

Most Rails apps end up with the same admin pages: a few key numbers, a "is everything OK?" page someone checks when a
user complains, and a jobs dashboard. Sightline gives you all three, behind the admin check you already have.

| Page | What it shows |
|---|---|
| **Overview** | The numbers you declare: stat cards, daily trend lines, bars per day. Charts are drawn on the server. |
| **Health** | Whether things are working: Solid Queue's processes, failed jobs, recurring tasks that missed their schedule, free disk space, your own checks, and the system and storage it runs on. All green, or exactly what needs a look. |
| **Jobs** | [Mission Control – Jobs](https://github.com/rails/mission_control-jobs), set up for you: same admin check, same layout, job arguments hidden, look-only until you allow actions. |

**What makes it different**

- **No sign-in, no layout and no look of its own.** It inherits a controller you already have, so your sign-in
  and admin check decide who gets in. It renders inside your layout and takes your colours.
- **Everything in one initializer.** No migrations, no admin DSL to learn: a stat is a block that returns a number, and a
  check is a block that returns ok, warning or problem.
- **Safe by default.** Job actions (retry, discard, run now) are off, and job arguments, which often hold people's
  emails and names, are hidden. Without an admin controller set, nothing is served.
- **Knows Solid Queue.** It works out from each recurring task's schedule whether it should have run, so a job that
  quietly stopped shows up on Health, with no thresholds to tune.

## Requirements

Ruby 3.4+, Rails 8+ and Solid Queue. Sightline brings Mission Control – Jobs with it. Health's disk space check expects
SQLite on a local volume, and you can turn it off.

## Quick start

**1. Add the gem**, installed from GitHub and pinned to a release:

```ruby
# Gemfile
gem "sightline", github: "andrebras/sightline", tag: "v0.1.0"
```

**2. Have an admin controller.** Sightline's pages inherit it, so it must refuse everyone who isn't an admin. If you
don't have one yet, something like this, using the authentication Rails 8 generates:

```ruby
# app/controllers/admin/base_controller.rb
module Admin
  class BaseController < ApplicationController
    before_action { head :not_found unless Current.user&.admin? }
  end
end
```

**3. Run the generator:**

```sh
bundle install
bin/rails generate sightline:install --base-controller=Admin::BaseController --mount-at=/admin
bin/rails db:prepare
```

It writes `config/initializers/sightline.rb` and mounts Sightline in `config/routes.rb`. It also gives development
and test their own Solid Queue database, as production has, so Health and Jobs show real jobs locally. It changes
`config/database.yml` only when it has the plain shape `rails new` writes; otherwise it tells you what to add.

**4. Let your layout yield `:head`**, for Jobs' scripts:

```erb
<head>
  ...
  <%= yield :head %>
</head>
```

**5. Open `/admin`.** With only the admin controller set you already get:
- **Health**, with every built-in check: disk space, and where Solid Queue is your job adapter, job processes,
  failed jobs and recurring tasks;
- **Jobs**;
- an empty **Overview**, waiting for your numbers.

Run your jobs locally (`bin/jobs`, or `SOLID_QUEUE_IN_PUMA=1 bin/rails server`) to see them working.

The pages are at `/admin`, `/admin/health` and `/admin/jobs`. To link to them from your app, use
`sightline.overview_path`, `sightline.health_path` and `sightline.jobs_path`. Mount Sightline after your app's own
`/admin` routes, so those keep their paths. Don't mount Mission Control yourself.

## Make it yours

Everything below goes in `config/initializers/sightline.rb`. Blocks run on each page view, never at boot, so they can
use your models and service objects.

### Your numbers on the Overview

```ruby
Sightline.configure do |c|
  c.base_controller = "Admin::BaseController"
  c.title = "How Shop is doing"

  c.stat("Customers") { User.count }
  c.stat("Orders · 7 days") { Order.where(created_at: 7.days.ago..).count }

  # A line per series over the last 30 days. Return counts grouped by day; missing days count as 0.
  c.trend("Last 30 days", days: 30) do |dates|
    since = dates.first.beginning_of_day
    {
      "Sign-ups" => User.where(created_at: since..).group("date(created_at)").count,
      "Orders" => Order.where(created_at: since..).group("date(created_at)").count
    }
  end

  c.bars("Orders per day", days: 7) do |dates|
    Order.where(created_at: dates.first.beginning_of_day..).group("date(created_at)").count
  end
end
```

### Your own checks on Health

Return `Sightline.ok`, `Sightline.warning` or `Sightline.problem`, with a short summary and an optional detail. A check
that raises, or returns anything else, shows as a problem, so a broken check is never mistaken for a passing one.

```ruby
c.check("Payment webhooks") do
  last = PaymentEvent.maximum(:created_at)
  if last.nil? then Sightline.warning("None received yet")
  elsif last < 1.day.ago then Sightline.problem("None for a day", detail: "Last one #{last.to_fs(:short)}")
  else Sightline.ok("Last one #{last.to_fs(:short)}")
  end
end
```

### Letting admins act on jobs

```ruby
c.job_actions = true        # retry, discard, pause queues, run recurring tasks now
c.show_job_arguments = true # only if arguments never hold personal data
```

### Your look

Sightline's classes start with `sl-`, and its colours and fonts are CSS custom properties with neutral defaults. Set
yours on `.sl` in your own stylesheet:

```css
.sl{--sl-accent:#486440;--sl-font-heading:Georgia,serif}
```

Text colours must reach 4.5:1 on your page background (WCAG AA). The defaults do, on white and on light tinted pages.
If your accent is lighter than that, keep it for lines and bars and set `--sl-accent-text` to a darker shade, for links,
the current tab and the selected refresh choice (white text on it):

```css
.sl{--sl-accent:#a96b43;--sl-accent-text:#8f5835}
```

If your layout already links the admin pages, turn off Sightline's own section links with `c.navigation = false`.

### Pages of your own

```ruby
c.page "Refunds", path: "refunds", template: "admin/refunds"
```

The page is listed after Overview, Health and Jobs, at `/admin/refunds`. Its template can use the same
[pieces](#pieces) as Sightline's pages.

## Reference

### Settings

| Setting | Default | What it does |
|---|---|---|
| `base_controller` | none (required) | The controller Sightline's and Jobs' controllers inherit. Without it Sightline raises rather than serve anyone. |
| `layout` | the base controller's | The layout pages render in. |
| `title` | `"Admin"` | The line above each page's title. |
| `overview_intro` | `nil` | A line under the Overview's title. |
| `navigation` | `true` | Sightline's section links on each page. |
| `icons` | `{}` | A decorative glyph per page title, e.g. `{ "Health" => "✓" }`, hidden from screen readers. |
| `jobs` | `true` | Mount Jobs at `/<mount>/jobs`. `false` leaves it out. |
| `jobs_path` | `nil` | Link a jobs dashboard elsewhere instead (with `jobs = false`). |
| `job_actions` | `false` | Allow anything but GET in Jobs. |
| `show_job_arguments` | `false` | Show jobs' arguments. |
| `solid_queue_checks` | `nil` | Health's Solid Queue checks; `nil` means on when the app has Solid Queue and it is Active Job's adapter in that environment, so they are off where jobs run on `:async` or `:test`. |
| `recurring_grace` | `2.minutes` | How late a recurring run may be recorded before it counts as missed. |
| `storage_path` | `nil` | The directory whose volume Health checks; `nil` means the first SQLite database's. |
| `storage_warning_below` / `storage_problem_below` | `20` / `10` | Free space, in percent, for a warning and a problem. |
| `storage_check` | `true` | `false` leaves out the Storage card and the disk space check. |

### Declarations

| Call | Shows |
|---|---|
| `stat(label, note: nil, format: nil) { number }` | A stat card. A `nil` value shows a dash; `format: :percent` shows 42 as 42%; `note` is a string or a block. |
| `trend(title, days: 30, totals: {}) { \|dates\| { "Series" => values } }` | A line chart. Values are an array (one per date, oldest first) or a hash keyed by `Date` or `"YYYY-MM-DD"`. The legend shows each series' sum, unless `totals` gives a block for it. |
| `bars(title, days: 7) { \|dates\| values }` | A bar per day, with values as for trends. |
| `note(text)` or `note { text }` | Fine print under the charts. |
| `check(name) { Sightline.ok/warning/problem(summary, detail: nil) }` | A line on Health; `detail` is a string or a list of lines. |
| `page(title, path:, template:)` | A page of the app's own. |

Days follow the app's time zone.

### How Health decides

- **Job processes:** alive means a heartbeat within `SolidQueue.process_alive_threshold`. None alive, or none at all,
  is a problem; some not responding is a warning.
- **Failed jobs:** how many, with the latest five errors (job class, error class and message, never the arguments) and
  a link to Jobs' failed list.
- **Recurring tasks:** each `SolidQueue::RecurringTask`'s schedule gives the latest time it should have run, at least
  `recurring_grace` ago. The schedule is read with Fugit, in `SolidQueue.time_zone` unless it names one, as the
  scheduler does. If the task's latest run is older than that, it is overdue, a problem. A task registered after that
  time is "not due yet". Solid Queue deletes run records when it clears finished jobs (`clear_finished_jobs_after`), so
  a missing record older than that is shown as "run not kept", not as overdue.
- **Disk space:** `df -Pk` on the storage path, against the thresholds.
- **Cards:**
  - **System:** Ruby, Rails, when the process booted, its memory, and on Fly.io the deployment and region from
    `FLY_IMAGE_REF` and `FLY_REGION`;
  - **Storage:** free space and each SQLite database's size, WAL included;
  - a table of recurring tasks with their last and next run.

A refresh picker reloads Health every 5, 15 or 30 seconds, keeping the choice in the URL (`/admin/health?refresh=15`).

### How Jobs is set up

Sightline mounts Mission Control at `/<mount>/jobs` and sets it up (`lib/sightline/jobs.rb`):

- **Access:** Mission Control's controllers inherit `base_controller`, and its own password prompt is off.
- **Layout:** its pages render inside your layout (`layout`, else `application`), under Sightline's header and
  navigation. Mission Control's Bulma stylesheet is left out, because its global classes would restyle your app;
  `sightline/jobs.css` styles its screens with the same `--sl-*` properties. Your route helpers work there too.
- **Arguments:** hidden in every list and on each job's page, unless `show_job_arguments` is on.
- **One server:** Mission Control's `server_id` is left out of links when there is one job server.
- **Actions:** unless `job_actions` is on, any request other than GET or HEAD gets 403 "Job actions are turned off".
  That check runs after your base controller's, so non-admins still get whatever your app gives them. Mission
  Control's buttons still show; pressing one does nothing.

When upgrading Mission Control, compare its layout with
`lib/sightline/jobs_views/layouts/mission_control/jobs/application.html.erb` and look over its screens.

### Route helpers inside your layout

Sightline is an isolated engine, so its own route helpers are `overview_path`, `health_path` and `app_page_path`. Every
other route helper (`root_path`, `new_session_path`...) goes to your app's routes, in Sightline's controllers and views
alike, so your before_actions and layout work unchanged. If your app has its own route named `overview`, `health` or
`app_page`, use `main_app.` for it in the layout. Sightline sets `content_for :title` to the page's name.

### Pieces

Overview and Health are built from these helpers (`Sightline::PiecesHelper`), which your own pages can use too.
Outside Sightline's pages, add `helper Sightline::PiecesHelper`, wrap the page in `<div class="sl">` and load
`stylesheet_link_tag "sightline/application"`.

| Helper | Shows |
|---|---|
| `sl_section(title, link: [label, url]) { ... }` | A titled block |
| `sl_stats { ... }` with `sl_stat(label, value, note:, format:, status:)` | A row of stat cards |
| `sl_trend(dates, { "Series" => values }, totals: {})` | A server-drawn SVG line chart |
| `sl_bars([[date, value], ...])` | A bar per day |
| `sl_checks { ... }` with `sl_check(name, Sightline.ok("..."))` | Health check lines |
| `sl_card(title, [[label, value], ...])` | A card of labelled facts |
| `sl_table(headers, rows, empty: "Nothing yet.")` | A table that stacks on a phone |

### Styles

Every class starts with `sl-`, inside `.sl`. The defaults are set with `:where(.sl)`, so any rule of yours wins. The
stylesheet is linked from each page, so your layout needs nothing added.

| Property | Used for |
|---|---|
| `--sl-ink`, `--sl-muted`, `--sl-label` | Text, secondary text, small-caps labels |
| `--sl-accent` | The current tab's underline, bars |
| `--sl-accent-text` | Links, the current tab's text, the selected refresh choice; `--sl-accent` unless you set it |
| `--sl-surface`, `--sl-surface-alt`, `--sl-line` | Panels, table headers, borders |
| `--sl-ok`, `--sl-warning`, `--sl-problem` and their `-soft` backgrounds | Check states and the headline |
| `--sl-series-1` to `--sl-series-6` | Trend lines, in the series' order |
| `--sl-radius`, `--sl-font`, `--sl-font-heading` | Corners and type |

## Development

```sh
bin/test                 # tests, against a dummy app with real Solid Queue records
bundle exec rubocop      # lint
```

## License

MIT. See [LICENSE](LICENSE).
