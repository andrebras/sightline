module Sightline
  # The built-in Health checks, read from Solid Queue's own tables: whether its processes are alive,
  # failed jobs with their latest errors (never a job's arguments), and recurring tasks that missed a run.
  class SolidQueueChecks
    include ActionView::Helpers::DateHelper

    # A recurring task's row on Health: when it should last have run, when it did, and whether that's late.
    Task = Data.define(:key, :schedule, :job, :due, :last_run, :next_run, :state)

    def initialize(now: Time.current, grace: 2.minutes, failed_jobs_url: nil)
      @now = now
      @grace = grace
      @failed_jobs_url = failed_jobs_url
    end

    def results
      [ [ "Job processes", processes ], [ "Failed jobs", failed_jobs ], [ "Recurring tasks", recurring_tasks ] ]
    end

    # Alive means a heartbeat within Solid Queue's own threshold (process_alive_threshold, 5 minutes by default).
    def processes
      all = SolidQueue::Process.order(:kind, :name).to_a
      return Sightline.problem("No job processes running", detail: "Nothing is working the queue.") if all.empty?

      alive = all.count { |process| alive?(process) }
      status = if alive.zero? then :problem
               elsif alive < all.size then :warning
               else :ok
               end
      Result.new(status: status, summary: "#{alive} of #{all.size} alive",
                 detail: all.map { |process| describe(process) })
    end

    def failed_jobs
      count = SolidQueue::FailedExecution.count
      return Sightline.ok("None") if count.zero?

      latest = SolidQueue::FailedExecution.includes(:job).order(created_at: :desc, id: :desc).limit(5).map do |failure|
        "#{failure.job&.class_name} · #{failure.exception_class}: #{failure.message.to_s.squish.truncate(160)} · " \
          "#{ago(failure.created_at)}"
      end
      Sightline.problem("#{count} failed #{count == 1 ? "job" : "jobs"}", detail: latest)
               .with_link("See failed jobs", @failed_jobs_url)
    end

    def recurring_tasks
      tasks = tasks_with_runs
      return Sightline.ok("None registered") if tasks.empty?

      late = tasks.select { |task| task.state == :overdue }
      return Sightline.ok("#{tasks.size} on schedule") if late.empty?

      Sightline.problem("#{late.size} of #{tasks.size} overdue",
                        detail: late.map { |task| "#{task.key}: due #{ago(task.due)}, #{last_run_text(task)}" })
    end

    # Each registered task with its schedule worked out by Fugit, as Solid Queue's scheduler does.
    def tasks_with_runs
      last_runs = SolidQueue::RecurringExecution.group(:task_key).maximum(:run_at)
      SolidQueue::RecurringTask.order(:key).map { |task| task_row(task, last_runs[task.key]) }
    end

    def last_run_text(task)
      task.last_run ? "last ran #{ago(task.last_run)}" : "no run recorded"
    end

    private

    def alive?(process)
      process.last_heartbeat_at && process.last_heartbeat_at > @now - SolidQueue.process_alive_threshold
    end

    def describe(process)
      heartbeat = process.last_heartbeat_at ? "heartbeat #{ago(process.last_heartbeat_at)}" : "no heartbeat"
      "#{process.kind} #{process.name} on #{process.hostname.presence || "an unknown host"}: #{heartbeat}" \
        "#{" (not responding)" unless alive?(process)}"
    end

    def task_row(task, last_run)
      schedule = parse(task)
      # The latest run that is at least `grace` old: the scheduler records each run at its scheduled time,
      # so a run that came due seconds ago may not be recorded yet.
      due = schedule && schedule.previous_time(@now - @grace).to_t.utc
      Task.new(key: task.key, schedule: task.schedule, job: task.class_name.presence || task.command,
               due: due, last_run: last_run, next_run: schedule && schedule.next_time(@now).to_t.utc,
               state: state(task, due, last_run))
    end

    def state(task, due, last_run)
      return :unknown unless due
      return :ok if last_run && last_run >= due - 1.second
      return :not_due if due < task.created_at
      # Runs are recorded with their job, which Solid Queue clears once finished (clear_finished_jobs_after):
      # a missing record for a run older than that says nothing.
      return :not_kept if due < @now - SolidQueue.clear_finished_jobs_after

      :overdue
    end

    # The schedule in the time zone Solid Queue's scheduler uses (SolidQueue.time_zone) when it names none.
    def parse(task)
      schedule = Fugit.parse(task.schedule, multi: :fail)
      return unless schedule.is_a?(Fugit::Cron)
      return schedule unless schedule.zone.nil? && SolidQueue.respond_to?(:time_zone) && SolidQueue.time_zone.present?

      Fugit.parse("#{schedule.to_cron_s} #{SolidQueue.time_zone}", multi: :fail)
    rescue ArgumentError
      nil
    end

    def ago(time) = "#{distance_of_time_in_words(time, @now)} ago"
  end
end
