require "active_support"
require "active_support/core_ext"
require "action_view"
require "sightline/version"
require "sightline/overview"
require "sightline/result"
require "sightline/solid_queue_checks"
require "sightline/system"
require "sightline/storage"
require "sightline/health"
require "sightline/configuration"
require "sightline/engine"

# An admin area for a Rails app: Overview, Health and Jobs. See README.md.
module Sightline
  class << self
    attr_accessor :booted_at
    attr_writer :config

    def config = @config ||= Configuration.new

    def configure
      yield config
    end
  end
end
