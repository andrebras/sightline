module Sightline
  # The frame around every Sightline page, Jobs included: its title, the navigation and the stylesheet.
  # Routes go through the `sightline` proxy, because Jobs' pages are Mission Control's, not the engine's.
  module ApplicationHelper
    NavItem = Data.define(:label, :url, :current)

    # Overview, Health, Jobs (unless turned off), then the app's own pages.
    def sightline_navigation
      items = [
        NavItem.new("Overview", sightline.overview_path, controller_path == "sightline/overview"),
        NavItem.new("Health", sightline.health_path, controller_path == "sightline/health")
      ]
      items << sightline_jobs_item if sightline_jobs_url
      items + sightline_page_items
    end

    # Where the jobs dashboard is: Sightline's own Jobs, or the `jobs_path` setting for one elsewhere.
    def sightline_jobs_url
      return Sightline.config.jobs_path if Sightline.config.jobs_path

      sightline.jobs_path if sightline_jobs?
    end

    # The list of failed jobs in Sightline's Jobs, or the jobs dashboard when it's somewhere else.
    def sightline_failed_jobs_url
      return Sightline.config.jobs_path if Sightline.config.jobs_path
      return unless sightline_jobs?

      MissionControl::Jobs::Engine.routes.url_helpers.jobs_path(:failed, script_name: sightline.jobs_path.chomp("/"))
    end

    private

    def sightline_page_items
      Sightline.config.pages.map do |page|
        current = controller_path == "sightline/pages" && params[:page] == page.path
        NavItem.new(page.title, sightline.app_page_path(page.path), current)
      end
    end

    def sightline_jobs_item = NavItem.new("Jobs", sightline_jobs_url, controller_path.start_with?("mission_control/"))

    def sightline_jobs? = Sightline.config.jobs && sightline.respond_to?(:jobs_path)
  end
end
