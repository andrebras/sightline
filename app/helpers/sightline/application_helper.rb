module Sightline
  # The frame around every Sightline page: its title, the navigation and the stylesheet.
  module ApplicationHelper
    NavItem = Data.define(:label, :url, :current)

    # Overview, Health, Jobs (when there is a jobs dashboard), then the app's own pages.
    def sightline_navigation
      items = [
        NavItem.new("Overview", overview_path, controller_name == "overview"),
        NavItem.new("Health", health_path, controller_name == "health")
      ]
      items << NavItem.new("Jobs", sightline_jobs_url, false) if sightline_jobs_url
      items + Sightline.config.pages.map do |page|
        NavItem.new(page.title, app_page_path(page.path), controller_name == "pages" && params[:page] == page.path)
      end
    end

    # Where the jobs dashboard is: the `jobs_path` setting, or Mission Control – Jobs' mount point if the app has one.
    def sightline_jobs_url
      Sightline.config.jobs_path || mission_control_path
    end

    # Mission Control's list of failed jobs, or the jobs dashboard when it's something else.
    def sightline_failed_jobs_url
      return Sightline.config.jobs_path if Sightline.config.jobs_path
      return unless mission_control_path

      MissionControl::Jobs::Engine.routes.url_helpers.jobs_path(:failed, script_name: mission_control_path.chomp("/"))
    end

    private

    def mission_control_path
      main_app.mission_control_jobs_path if main_app.respond_to?(:mission_control_jobs_path)
    end
  end
end
