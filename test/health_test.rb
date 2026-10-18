require "test_helper"

# Health, from real Solid Queue records: processes, failed jobs, recurring tasks, and the app's own checks.
class HealthTest < Sightline::IntegrationTest
  def job(class_name: "ReportJob", arguments: {})
    SolidQueue::Job.create!(queue_name: "default", class_name: class_name, arguments: arguments)
  end

  def process(last_heartbeat_at)
    SolidQueue::Process.create!(kind: "Worker", name: "worker-#{SecureRandom.hex(3)}", pid: 1, hostname: "web-1",
                                last_heartbeat_at: last_heartbeat_at)
  end

  # Taken off the queue and failed, the way a worker records it.
  def failed_job(message, arguments: {})
    job(arguments: arguments).tap do |failed|
      failed.ready_execution&.destroy!
      failed.failed_with(RuntimeError.new(message))
    end
  end

  def task(key, schedule, created_at: 2.days.ago)
    SolidQueue::RecurringTask.create!(key: key, schedule: schedule, class_name: "ReportJob", created_at: created_at)
  end

  def ran(key, run_at)
    SolidQueue::RecurringExecution.create!(job: job, task_key: key, run_at: run_at)
  end

  def check(name) = css_select(".sl-check").find { |row| row.at_css(".sl-check-name").text == name }

  test "all fine: processes alive, no failed jobs, recurring tasks on schedule" do
    travel_to Time.utc(2026, 5, 4, 12, 31) do
      process(10.seconds.ago)
      task("report", "every 15 minutes")
      ran("report", Time.utc(2026, 5, 4, 12, 30))
      get "/admin/health", headers: ADMIN
    end
    assert_response :success
    assert_select ".sl-headline.sl-ok", "Everything looks fine"
    assert_select ".sl-check", 5
    assert_select ".sl-check.sl-ok", 5
    assert_match(/1 of 1 alive/, check("Job processes").text)
    assert_match(/Worker worker-\w+ on web-1: heartbeat less than a minute ago/, check("Job processes").text)
    assert_match(/None/, check("Failed jobs").text)
    assert_match(/1 on schedule/, check("Recurring tasks").text)
    assert_select ".sl-table td", /report/
    assert_select ".sl-state.sl-ok", "On schedule"
  end

  test "a dead process, a failed job and an overdue task need a look; a job's arguments never show" do
    travel_to Time.utc(2026, 5, 4, 12, 33) do
      process(1.hour.ago)
      failed_job("SMTP down", arguments: { "arguments" => [ "secret@example.test" ] })
      task("report", "every 15 minutes")
      ran("report", Time.utc(2026, 5, 4, 12, 15))
      get "/admin/health", headers: ADMIN
    end
    assert_select ".sl-headline.sl-problem", "3 things need a look"
    assert_match(/0 of 1 alive.*not responding/m, check("Job processes").text)
    assert_includes check("Failed jobs")["class"], "sl-problem"
    assert_match(/1 failed job\b.*ReportJob · RuntimeError: SMTP down/m, check("Failed jobs").text)
    assert_select ".sl-check a[href='/admin/jobs/failed/jobs']", "See failed jobs"
    assert_match(/1 of 1 overdue.*report: due 3 minutes ago, last ran 18 minutes ago/m, check("Recurring tasks").text)
    assert_select ".sl-state.sl-problem", "Overdue"
    assert_not_includes response.body, "secret@example.test"
  end

  test "a run that came due within the grace period isn't missed yet" do
    travel_to Time.utc(2026, 5, 4, 12, 31) do
      task("report", "every 15 minutes")
      ran("report", Time.utc(2026, 5, 4, 12, 15))
      get "/admin/health", headers: ADMIN
    end
    assert_match(/1 on schedule/, check("Recurring tasks").text)
  end

  test "a task registered after its last due time, or whose run record was cleared, isn't overdue" do
    travel_to Time.utc(2026, 5, 6, 12, 0) do # a Wednesday
      task("new", "every day at 4am", created_at: 1.hour.ago)
      task("weekly", "every monday at 4am", created_at: 30.days.ago)
      get "/admin/health", headers: ADMIN
    end
    assert_match(/2 on schedule/, check("Recurring tasks").text)
    assert_equal [ "Not due yet", "Run not kept" ], css_select(".sl-state").map(&:text)
  end

  test "no job processes at all is a problem" do
    get "/admin/health", headers: ADMIN
    assert_match(/No job processes running/, check("Job processes").text)
    assert_includes check("Job processes")["class"], "sl-problem"
    assert_match(/None registered/, check("Recurring tasks").text)
    assert_select ".sl-table-wrap .sl-empty", "No recurring tasks registered."
  end

  test "the app's own checks show after the built-in ones, and one that breaks shows as a problem" do
    3.times { job }
    Sightline.config.check("Broken") { raise "database is locked" }
    Sightline.config.check("Wrong") { "fine" }
    process(Time.current)
    get "/admin/health", headers: ADMIN
    names = css_select(".sl-check-name").map(&:text)
    assert_equal [ "Job processes", "Failed jobs", "Recurring tasks", "Disk space", "Report queue", "Broken", "Wrong" ],
                 names
    assert_includes check("Report queue")["class"], "sl-warning"
    assert_equal [ "Over 2 waiting", "Check the worker" ], check("Report queue").css(".sl-check-detail li").map(&:text)
    assert_match(/The check failed.*RuntimeError: database is locked/m, check("Broken").text)
    assert_match(/returned String/, check("Wrong").text)
    assert_select ".sl-headline.sl-problem", "3 things need a look"
  ensure
    Sightline.config.checks.pop(2)
  end

  test "the built-in checks can be turned off" do
    with_config(solid_queue_checks: false) do
      get "/admin/health", headers: ADMIN
    end
    assert_equal [ "Disk space", "Report queue" ], css_select(".sl-check-name").map(&:text)
    assert_select ".sl-table", 0
  end

  test "the refresh picker keeps its choice in the URL" do
    get "/admin/health", headers: ADMIN
    assert_select ".sl-refresh-choice.sl-current", "Off"
    assert_select "[data-sl-refresh]", 0
    assert_select "script[src*='sightline/refresh']", 0
    assert_select ".sl-refresh-choice[href=?]", "/admin/health?refresh=15", text: "15s"

    get "/admin/health?refresh=15", headers: ADMIN
    assert_select ".sl-refresh-choice.sl-current", "15s"
    assert_select ".sl[data-sl-refresh='15']"
    assert_select "script[src*='sightline/refresh']"

    get "/admin/health?refresh=1", headers: ADMIN
    assert_select "[data-sl-refresh]", 0
  end
end
