module Sightline
  class Engine < ::Rails::Engine
    isolate_namespace Sightline

    # When this process started serving, for the System card.
    config.after_initialize { Sightline.booted_at ||= Time.current }

    # The app's route helpers inside Sightline's controllers and views, defined again whenever routes reload.
    initializer "sightline.app_routes" do |app|
      ActiveSupport.on_load(:after_routes_loaded) { Sightline::AppRoutes.define_from(app.routes, Sightline::Engine.routes) }
    end

    # Mission Control – Jobs, when the app has it, refuses actions unless c.job_actions is on.
    config.to_prepare do
      if defined?(MissionControl::Jobs::ApplicationController)
        MissionControl::Jobs::ApplicationController.include(Sightline::JobActionsGuard)
      end
    end
  end
end
