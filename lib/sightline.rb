require "active_support"
require "active_support/core_ext"
require "action_view"
require "mission_control/jobs"
require "sightline/version"
require "sightline/overview"
require "sightline/result"
require "sightline/solid_queue_checks"
require "sightline/system"
require "sightline/storage"
require "sightline/health"
require "sightline/configuration"
require "sightline/app_routes"
require "sightline/jobs"
require "sightline/engine"

# An admin area for a Rails app: Overview, Health and Jobs. See README.md.
module Sightline
  class << self
    attr_accessor :booted_at
    attr_writer :config

    def config = @config ||= Configuration.new

    def configure
      yield config
      # Mission Control – Jobs reads its base controller when its controllers load, after the app's initializers
      # and before production eager-loads them, so Jobs gets the same admin check as the other pages.
      MissionControl::Jobs.base_controller_class = config.base_controller if config.base_controller
    end
  end
end
