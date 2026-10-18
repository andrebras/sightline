require "rails"
require "active_record/railtie"
require "active_job/railtie"
require "action_controller/railtie"
require "action_view/railtie"
require "propshaft"
require "solid_queue"
require "mission_control/jobs"
require "sightline"

# The smallest app Sightline runs in: an admin controller, a layout with its own links and Solid Queue's tables in
# its one database. Sightline mounts and sets up Jobs (Mission Control – Jobs) itself.
module Dummy
  class Application < Rails::Application
    config.load_defaults 8.0
    config.root = File.expand_path("..", __dir__)
    config.eager_load = false
    config.enable_reloading = false
    config.secret_key_base = "sightline-dummy-secret"
    config.consider_all_requests_local = true
    config.action_controller.allow_forgery_protection = false
    config.active_support.deprecation = :raise
    config.active_job.queue_adapter = :test
    config.logger = Logger.new(nil)
  end
end
