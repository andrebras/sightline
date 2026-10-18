require "open3"

module Sightline
  # What is running: Ruby and Rails, when this process booted, its memory, and where it runs.
  # The environment and /proc file are arguments, so tests can describe a Fly machine without being on one.
  class System
    attr_reader :booted_at

    def initialize(env: ENV, proc_status: "/proc/self/status", pid: Process.pid, booted_at: Sightline.booted_at)
      @env = env
      @proc_status = proc_status
      @pid = pid
      @booted_at = booted_at
    end

    def ruby = "#{RUBY_VERSION}#{" with YJIT" if defined?(RubyVM::YJIT) && RubyVM::YJIT.enabled?}"
    def rails = Rails.version

    # Resident memory in bytes: VmRSS from /proc on Linux, else what `ps` says; nil if neither answers.
    def memory
      kilobytes = proc_rss || ps_rss
      kilobytes && (kilobytes * 1024)
    end

    # Fly sets FLY_IMAGE_REF and FLY_REGION on each machine; the image's tag names the deployment
    # (registry.fly.io/app:deployment-01K...). Without them the app runs somewhere else, usually a laptop.
    def fly? = image.present?
    def region = @env["FLY_REGION"].presence

    def deployment
      return unless fly?

      tag = image.split(":").last
      tag.delete_prefix("deployment-").last(8).downcase
    end

    def running_on
      return "Running locally" unless fly?

      [ "Fly.io", ("deployment #{deployment}" if deployment), ("region #{region}" if region) ].compact.join(" · ")
    end

    private

    def image = @env["FLY_IMAGE_REF"].presence

    def proc_rss
      return unless File.readable?(@proc_status)

      File.foreach(@proc_status) { |line| return Integer(line[/\d+/]) if line.start_with?("VmRSS:") }
      nil
    end

    def ps_rss
      output, status = Open3.capture2("ps", "-o", "rss=", "-p", @pid.to_s, err: File::NULL)
      status.success? ? Integer(output.strip, exception: false) : nil
    rescue SystemCallError
      nil
    end
  end
end
