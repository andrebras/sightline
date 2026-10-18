# The app's admin check: admins send X-Admin: yes, signed-out visitors (X-Admin: none) are sent to the app's
# own page with one of its route helpers, and everyone else gets a 404.
class AdminController < ApplicationController
  before_action do
    case request.headers["X-Admin"]
    when "yes" then nil
    when "none" then redirect_to things_path
    else raise ActionController::RoutingError, "Not found"
    end
  end
end
