# Sightline reference

Every setting and declaration, and how Health and Jobs work. For installing Sightline and a first tour, see the
[README](../README.md).

## Settings

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

## Declarations

| Call | Shows |
|---|---|
| `stat(label, note: nil, format: nil) { number }` | A stat card. A `nil` value shows a dash; `format: :percent` shows 42 as 42%; `note` is a string or a block. |
| `trend(title, days: 30, totals: {}) { \|dates\| { "Series" => values } }` | A line chart. Values are an array (one per date, oldest first) or a hash keyed by `Date` or `"YYYY-MM-DD"`. The legend shows each series' sum, unless `totals` gives a block for it. |
| `bars(title, days: 7) { \|dates\| values }` | A bar per day, with values as for trends. |
| `note(text)` or `note { text }` | Fine print under the charts. |
| `check(name) { Sightline.ok/warning/problem(summary, detail: nil) }` | A line on Health; `detail` is a string or a list of lines. |
| `page(title, path:, template:)` | A page of the app's own. |

Days follow the app's time zone.

## How Health decides

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

## How Jobs is set up

Sightline mounts Mission Control at `/<mount>/jobs` and sets it up (`lib/sightline/jobs.rb`):

- **Access:** Mission Control's controllers inherit `base_controller`, and its own password prompt is off.
- **Layout:** its pages render inside your layout (`layout`, else `application`), under Sightline's header and
  navigation. Mission Control's Bulma stylesheet is left out, because its global classes would restyle your app;
  `sightline/jobs.css` styles its screens with the same `--sl-*` properties. Your route helpers work there too.
- **Scripts:** Mission Control's import map is left out, so it can't clash with your app's. `sightline/jobs.js`, a
  plain script, applies a filter as soon as it changes and asks before deleting (Turbo asks instead when your app runs
  it). Without Turbo in your app, Jobs' pages load as full pages.
- **Arguments:** hidden in every list and on each job's page, unless `show_job_arguments` is on.
- **One server:** Mission Control's `server_id` is left out of links when there is one job server.
- **Actions:** unless `job_actions` is on, any request other than GET or HEAD gets 403 "Job actions are turned off".
  That check runs after your base controller's, so non-admins still get whatever your app gives them. Mission
  Control's buttons still show; pressing one does nothing.

When upgrading Mission Control, compare its layout with
`lib/sightline/jobs_views/layouts/mission_control/jobs/application.html.erb` and look over its screens.

## Route helpers inside your layout

Sightline is an isolated engine, so its own route helpers are `overview_path`, `health_path` and `app_page_path`. Every
other route helper (`root_path`, `new_session_path`...) goes to your app's routes, in Sightline's controllers and views
alike, so your before_actions and layout work unchanged. If your app has its own route named `overview`, `health` or
`app_page`, use `main_app.` for it in the layout. Sightline sets `content_for :title` to the page's name.

## Pieces

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

## Styles

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

## About the screenshots

The PNG pictures in `docs/screenshots/` come from a throwaway Rails 8 app, "Demo Shop", that uses Sightline from this
repository, with Solid Queue running inside Puma (`SOLID_QUEUE_IN_PUMA=1`). Its data is made up: generated customers
and orders, a few finished jobs, one job that fails on purpose, two recurring tasks and one check of its own
("Latest order"). The app's layout sets only a sans-serif font and the page margins; everything else is Sightline's
default look. So that no real machine shows, `storage_path` is set to `"storage"` and the job processes' host name
was changed to `demo-shop.local` in the queue database.

They were taken with headless Chromium through [Playwright](https://playwright.dev), 1280 pixels wide, full page, and
reduced to 256 colours with ImageMagick (`magick in.png -strip -colors 256 PNG8:out.png`). The Jobs picture is Mission
Control's list of failed jobs, with job arguments hidden as they are by default. To update them, build a similar app,
open `/admin`, `/admin/health` and the failed jobs in `/admin/jobs`, and capture them the same way.

`install.gif` is a different app: a brand-new one made with `rails new` (Rails 8.1), with no data. The terminal part is
the real commands, recorded with [asciinema](https://asciinema.org) and drawn with
[agg](https://github.com/asciinema/agg) at 2.5 times the speed; it stops once the server is up. In that recording,
absolute paths in the output were shortened (`~/projects`, `~/.gem`). The browser part is screenshots from Playwright,
with an address bar and a pointer drawn into the page. Before it, `storage_path` was set to `"storage"` and the job
processes' host name was changed, as for the screenshots. The two parts were joined and turned into a GIF with
[ffmpeg](https://ffmpeg.org) (`palettegen` and `paletteuse`, 128 colours, 10 frames a second, 960 pixels wide).
