require "sightline/version"
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
