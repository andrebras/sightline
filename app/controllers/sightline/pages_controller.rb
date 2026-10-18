module Sightline
  # A page the app declared with `c.page`, rendered from the app's template inside Sightline's frame.
  class PagesController < ApplicationController
    def show
      @page = Sightline.config.find_page(params[:page])
    end
  end
end
