require "test_helper"

# Mission Control – Jobs changes nothing unless the app turns job actions on.
class JobActionsTest < Sightline::IntegrationTest
  # Queued through Solid Queue and failed, the way a worker records it.
  setup do
    active_job = ReportJob.new
    ActiveJob::QueueAdapters::SolidQueueAdapter.new.enqueue(active_job)
    @job = SolidQueue::Job.find_by!(active_job_id: active_job.job_id)
    @job.ready_execution.destroy!
    @job.failed_with(RuntimeError.new("SMTP down"))
  end

  def retry_path = "/admin/jobs/applications/dummy/jobs/#{@job.active_job_id}/retry"

  test "off by default: looking works, retrying is refused" do
    assert_not Sightline.config.job_actions
    get "/admin/jobs/applications/dummy/failed/jobs", headers: ADMIN
    assert_response :success
    assert_includes response.body, "SMTP down"
    post retry_path, headers: ADMIN
    assert_response :forbidden
    assert_equal "Job actions are turned off.", response.body
    assert_predicate @job.reload, :failed?
  end

  test "turned on, a failed job can be retried" do
    with_config(job_actions: true) do
      post retry_path, headers: ADMIN
    end
    assert_response :redirect
    assert_not_predicate @job.reload, :failed?
  end

  test "the app's admin check still comes first" do
    with_config(job_actions: true) do
      post retry_path
    end
    assert_response :not_found
    assert_predicate @job.reload, :failed?
  end
end
