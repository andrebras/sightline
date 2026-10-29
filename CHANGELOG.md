# Changelog

All notable changes to Sightline are listed here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Each version is a `vX.Y.Z` tag in this repository.

## [Unreleased]

### Fixed

- Jobs no longer adds Mission Control – Jobs' import map to the page. Its names (`application`, `controllers`) clashed
  with an app's own import map, so one app's scripts didn't load. `sightline/jobs.js`, a plain script, now does what
  those scripts did on Jobs' screens, and `yield :head` in the app's layout is optional.
- The install generator changes `config/environments/development.rb` and `test.rb` only when it also adds the queue
  databases to `config/database.yml`. When it leaves `database.yml` alone, it now leaves those alone too, and says what
  to add to both, instead of pointing Solid Queue at a database that doesn't exist.
- The Overview's bar chart has no inline `style` attributes, so a strict Content Security Policy (`style-src 'self'`)
  no longer flattens it. Each bar is now drawn at its exact share of the tallest one.

### Changed

- The README is reorganised: a screenshot, a short "Why", a table of contents, a quick start without edge cases, and
  notes for the edge cases. The full reference moved to `docs/reference.md`.

### Added

- Screenshots of Overview, Health and Jobs in `docs/screenshots/`.
- A GIF of the install, from `rails new` to the dashboard, under the README's Quick start.
- This changelog.

## [0.1.2] - 2026-10-19

### Added

- `--sl-accent-text`, a CSS property for links, the current tab and the selected refresh choice, so a light accent can
  keep a darker text colour.
- The install generator's `--queue-in-primary` and `--no-queue-in-primary` options, for apps that keep Solid Queue's
  tables in their primary database. Such apps get no queue databases.

### Changed

- The default text colours are darker, so they reach a contrast of 4.5:1 (WCAG AA, the usual level of the Web Content
  Accessibility Guidelines).
- Health's Solid Queue checks are on by default only where Solid Queue is Active Job's adapter, so they are off where
  jobs run on `:async` or `:test`.
- For apps whose databases aren't SQLite, the generated initializer points at `storage_path` for the disk space check.

## [0.1.1] - 2026-10-18

### Changed

- The README is rewritten for someone deciding whether to use Sightline: what it gives, a five-step quick start, then
  the reference.

## [0.1.0] - 2026-10-18

First release.

### Added

- **Overview**: stat cards, daily trend lines, bars per day and notes, declared in one initializer. Charts are drawn
  on the server.
- **Health**: Solid Queue's processes, failed jobs and overdue recurring tasks worked out from their schedules, the
  app's own checks, System and Storage cards with a disk space check, and a refresh picker.
- **Jobs**: Mission Control – Jobs mounted at `/<mount>/jobs` behind the app's admin controller, inside the app's
  layout, with job arguments hidden and job actions refused unless `job_actions` is on.
- Pages render inside the app's own layout, behind the app's own admin controller, and the app's route helpers work
  inside them.
- Settings to turn off Sightline's section links and to give each page a decorative icon.
- `bin/rails generate sightline:install`: writes the initializer, mounts Sightline and gives development and test their
  own Solid Queue database.
- Installation from this GitHub repository by tag, under the MIT license.

[Unreleased]: https://github.com/andrebras/sightline/compare/v0.1.2...HEAD
[0.1.2]: https://github.com/andrebras/sightline/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/andrebras/sightline/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/andrebras/sightline/releases/tag/v0.1.0
