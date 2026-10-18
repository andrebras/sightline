# Declared from Solid Queue's own tables, the only data the dummy app has.
Sightline.configure do |c|
  c.base_controller = "AdminController"
  c.title = "Dummy"
  c.overview_intro = "How the dummy app is doing."

  c.stat("Jobs", note: "all time") { SolidQueue::Job.count }
  c.stat("Finished", note: -> { "#{SolidQueue::Job.finished.count} of #{SolidQueue::Job.count}" }, format: :percent) do
    total = SolidQueue::Job.count
    100.0 * SolidQueue::Job.finished.count / total unless total.zero?
  end

  c.trend "Last 14 days", days: 14, totals: { "Queued" => -> { 1234 } } do |dates|
    since = dates.first.beginning_of_day
    {
      "Queued" => SolidQueue::Job.where(created_at: since..).group("date(created_at)").count,
      "Finished" => dates.map { |date| SolidQueue::Job.where(finished_at: date.all_day).count }
    }
  end

  c.bars("Jobs per day", days: 7) { |dates| SolidQueue::Job.where(created_at: dates.first.beginning_of_day..).group("date(created_at)").count }

  c.note "Days are UTC."
  c.note { "#{SolidQueue::Job.count} jobs kept." }

  c.page "Reports", path: "reports", template: "admin_pages/reports"
end
