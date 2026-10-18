# The app's admin check: admins send X-Admin: yes, everyone else gets a 404.
class AdminController < ApplicationController
  before_action { raise ActionController::RoutingError, "Not found" unless request.headers["X-Admin"] == "yes" }
end
