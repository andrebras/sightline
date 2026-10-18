module Sightline
  # Everything Health shows, worked out once per page view: the built-in Solid Queue checks, disk space,
  # then the app's own checks; and the System and Storage cards.
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

    def storage
      return unless config.storage_check

      @storage ||= Storage.from_app(config)
    end

    def system = @system ||= System.new

    # [[name, Result], ...] in the order they're shown.
    def results
      @results ||= Array(solid_queue&.results) +
                   (storage ? [ [ "Disk space", storage.result ] ] : []) +
                   config.checks.map { |check| [ check.name, check.run ] }
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
