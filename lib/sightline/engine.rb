module Sightline
  class Engine < ::Rails::Engine
    isolate_namespace Sightline

    # When this process started serving, for the System card.
    config.after_initialize { Sightline.booted_at ||= Time.current }

    # Mission Control – Jobs, when the app has it, refuses actions unless c.job_actions is on.
    config.to_prepare do
      if defined?(MissionControl::Jobs::ApplicationController)
        MissionControl::Jobs::ApplicationController.include(Sightline::JobActionsGuard)
      end
    end
  end
end
