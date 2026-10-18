module Sightline
  # Added to Mission Control – Jobs' controllers (lib/sightline/engine.rb). Unless the app turns job actions on
  # (c.job_actions = true), any request that would change something, such as retry, discard, pause, resume or
  # run now, is refused; looking stays allowed. It runs after the app's own admin check.
  module JobActionsGuard
    extend ActiveSupport::Concern

    included do
      before_action :sightline_refuse_job_actions
    end

    private

    def sightline_refuse_job_actions
      return if request.get? || request.head? || Sightline.config.job_actions

      render plain: "Job actions are turned off.", status: :forbidden
    end
  end
end
