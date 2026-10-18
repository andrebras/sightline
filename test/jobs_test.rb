require "test_helper"

# Jobs: Mission Control – Jobs, mounted and set up by Sightline, from real Solid Queue records.
class JobsTest < Sightline::IntegrationTest
  setup do
    active_job = ReportJob.new("ada@example.test")
    ActiveJob::QueueAdapters::SolidQueueAdapter.new.enqueue(active_job)
    @job = SolidQueue::Job.find_by!(active_job_id: active_job.job_id)
    @job.ready_execution.destroy!
    @job.failed_with(RuntimeError.new("SMTP down"))
  end

  def failed_path = "/admin/jobs/applications/dummy/failed/jobs"
  def job_path = "/admin/jobs/applications/dummy/jobs/#{@job.active_job_id}"

  test "the app's admin check decides who sees Jobs" do
    get failed_path
    assert_response :not_found
    get failed_path, headers: { "X-Admin" => "none" }
    assert_redirected_to "/things"
  end

  test "Jobs renders inside the app's layout, under Sightline's header, without Mission Control's Bulma" do
    get failed_path, headers: ADMIN
    assert_response :success
    assert_select "title", "Jobs · Dummy"
    assert_select ".app-nav a[href='/things']", "Things"
    assert_select ".sl.sl-jobs h1.sl-title", "Jobs"
    assert_select ".sl-nav a.sl-current[href='/admin/jobs']", "Jobs"
    assert_select "link[href*='sightline/jobs']"
    assert_select "link[href*='bulma']", 0
    assert_select "head script[type=importmap]"
    assert_includes response.body, "SMTP down"
  end

  test "links leave out the server picker when there is one job server" do
    get failed_path, headers: ADMIN
    assert_select "a[href*='server_id']", 0
  end

  test "a job's arguments are hidden unless the app shows them" do
    get failed_path, headers: ADMIN
    assert_includes response.body, "[hidden]"
    get job_path, headers: ADMIN
    assert_response :success
    assert_not_includes response.body, "ada@example.test"

    with_config(show_job_arguments: true) do
      get job_path, headers: ADMIN
    end
    assert_includes response.body, "ada@example.test"
  end

  test "Health links to the failed jobs in Jobs" do
    get "/admin/health", headers: ADMIN
    assert_select ".sl-check a[href='/admin/jobs/failed/jobs']", "See failed jobs"
    get "/admin/jobs/failed/jobs", headers: ADMIN
    follow_redirect! while response.redirect?
    assert_includes response.body, "SMTP down"
  end

  test "with Jobs turned off, the navigation and Health leave it out" do
    with_config(jobs: false) do
      get "/admin/health", headers: ADMIN
    end
    assert_select ".sl-nav a", text: "Jobs", count: 0
    assert_select "a", text: "Open Jobs", count: 0
  end

  test "without the app's admin controller, Sightline refuses to load rather than serve its pages to anyone" do
    error = assert_raises(ArgumentError) { Sightline::Configuration.new.admin_controller }
    assert_match(/c.base_controller/, error.message)
  end
end
