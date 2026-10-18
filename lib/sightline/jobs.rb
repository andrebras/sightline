module Sightline
  # Jobs: Mission Control – Jobs, mounted by Sightline at /<mount>/jobs and changed in four ways: it renders inside the
  # app's layout with Sightline's header (lib/sightline/jobs_views), it hides job arguments, it leaves its server
  # picker out of links when there is one server, and it refuses actions unless the app allows them.
  module Jobs
    VIEWS = File.expand_path("jobs_views", __dir__)

    # A job's arguments can hold people's email addresses and names. Mission Control's filter_arguments setting only
    # blanks named hash keys, so the helper every job list uses is replaced; the job page's raw data leaves them out
    # (jobs_views/mission_control/jobs/jobs/_raw_data.html.erb).
    module HiddenArguments
      def job_arguments(job) = Sightline.config.show_job_arguments ? super : "[hidden]"
    end

    # Mission Control adds its server_id to every link it builds, the app's own links in its layout included. With one
    # job server, which Mission Control picks when the parameter is missing, it's left out.
    module OneServer
      private

      def default_url_options
        servers = MissionControl::Jobs.applications.sum { |application| application.servers.count }
        servers == 1 ? super.except(:server_id) : super
      end
    end

    def self.prepare
      controller = MissionControl::Jobs::ApplicationController
      controller.include(Sightline::JobActionsGuard) unless controller < Sightline::JobActionsGuard
      controller.prepend(OneServer) unless controller < OneServer
      # The app's layout links with the app's route helpers. Mission Control routes those through main_app in its
      # controllers only; its views get them too, minus the ones Mission Control defines itself (root_path stays its).
      controller.helper(MissionControl::Jobs::HostRouteHelpers, Sightline::ApplicationHelper)
      controller.prepend_view_path(VIEWS) unless controller.view_paths.map(&:to_s).include?(VIEWS)
      helpers = MissionControl::Jobs::JobsHelper
      helpers.prepend(HiddenArguments) unless helpers < HiddenArguments
    end
  end
end
