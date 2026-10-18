module Sightline
  class HealthController < ApplicationController
    # Seconds between reloads the page offers; the choice stays in the URL (?refresh=15).
    REFRESH_CHOICES = [ 5, 15, 30 ].freeze

    def show
      @refresh = REFRESH_CHOICES.find { |seconds| seconds == params[:refresh].to_i }
      @health = Sightline::Health.new(failed_jobs_url: helpers.sightline_failed_jobs_url)
    end
  end
end
