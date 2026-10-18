module Sightline
  # Inherits the app's controller (Sightline.config.base_controller), so the app's sign-in and admin check
  # decide who sees these pages. Sightline has no sign-in of its own.
  class ApplicationController < Sightline.config.base_controller.constantize
    layout Sightline.config.layout if Sightline.config.layout
    helper Sightline::AppRoutesHelper, Sightline::PiecesHelper, Sightline::ApplicationHelper
  end
end
