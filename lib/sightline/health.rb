module Sightline
  # Everything Health shows, worked out once per page view: the built-in Solid Queue checks, then the app's own.
  class Health
    attr_reader :config, :now

    def initialize(config: Sightline.config, now: Time.current, failed_jobs_url: nil)
      @config = config
      @now = now
      @failed_jobs_url = failed_jobs_url
    end

    def solid_queue
      return unless config.solid_queue_checks?

      @solid_queue ||= SolidQueueChecks.new(now: now, grace: config.recurring_grace, failed_jobs_url: @failed_jobs_url)
    end

    # [[name, Result], ...] in the order they're shown.
    def results
      @results ||= Array(solid_queue&.results) + config.checks.map { |check| [ check.name, check.run ] }
    end

    def needing_a_look = results.count { |_name, result| !result.ok? }

    def status
      statuses = results.map { |_name, result| result.status }
      Result::STATUSES.reverse.find { |status| statuses.include?(status) } || :ok
    end

    def headline
      count = needing_a_look
      return "Everything looks fine" if count.zero?

      "#{count} #{count == 1 ? "thing needs" : "things need"} a look"
    end
  end
end
