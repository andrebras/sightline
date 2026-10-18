ENV["RAILS_ENV"] = "test"
require "fileutils"
FileUtils.mkdir_p(File.expand_path("dummy/tmp", __dir__))
require_relative "dummy/config/environment"
require "rails/test_help"

# Routes are drawn on the first request, and Jobs is mounted only if the configuration says so. They're drawn here,
# before any test changes the configuration.
Rails.application.reload_routes_unless_loaded

# Solid Queue's own tables, from the schema its installer writes, created afresh for each run.
ActiveRecord::Schema.verbose = false
load File.join(Gem.loaded_specs["solid_queue"].full_gem_path,
               "lib/generators/solid_queue/install/templates/db/queue_schema.rb")

module Sightline
  class IntegrationTest < ActionDispatch::IntegrationTest
    ADMIN = { "X-Admin" => "yes" }.freeze

    # Settings a test changes are put back afterwards.
    def with_config(**settings)
      before = settings.keys.index_with { |key| Sightline.config.public_send(key) }
      settings.each { |key, value| Sightline.config.public_send(:"#{key}=", value) }
      yield
    ensure
      before.each { |key, value| Sightline.config.public_send(:"#{key}=", value) }
    end
  end
end
