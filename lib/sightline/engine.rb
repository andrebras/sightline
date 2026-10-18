module Sightline
  class Engine < ::Rails::Engine
    isolate_namespace Sightline

    # Jobs is Mission Control – Jobs behind the app's own admin controller (Sightline.configure sets it), so its
    # password prompt is off. Solid Queue is its queue. An app can still change these in config/application.rb.
    config.mission_control.jobs.http_basic_auth_enabled = false
    config.mission_control.jobs.show_console_help = false
    config.mission_control.jobs.adapters = [ :solid_queue ]

    # When this process started serving, for the System card.
    config.after_initialize { Sightline.booted_at ||= Time.current }

    # The app's route helpers inside Sightline's controllers and views, defined again whenever routes reload.
    initializer "sightline.app_routes" do |app|
      ActiveSupport.on_load(:after_routes_loaded) { Sightline::AppRoutes.define_from(app.routes, Sightline::Engine.routes) }
    end

    config.to_prepare { Sightline::Jobs.prepare }
  end
end
