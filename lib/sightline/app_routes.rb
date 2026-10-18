module Sightline
  # The app's route helpers inside Sightline, sent to the app's routes (main_app).
  #
  # Sightline's controllers inherit the app's controller and render the app's layout, so app code such as a
  # before_action redirecting to new_session_path, or a layout linking to root_path, runs inside an isolated engine,
  # where route helpers resolve against the engine's routes and fail. This module defines, for every helper the app
  # has and Sightline doesn't, a method that asks the app's routes instead (as Mission Control – Jobs does).
  # Sightline's own (overview_path, health_path, app_page_path) stay Sightline's; use main_app. for the app's.
  module AppRoutes
    class << self
      def define_from(app_routes, engine_routes)
        defined.each { |name| remove_method(name) }
        defined.clear
        (app_routes.named_routes.helper_names - engine_routes.named_routes.helper_names).each do |name|
          define_method(name) { |*args, **options| main_app.public_send(name, *args, **options) }
          defined << name
        end
      end

      private

      def defined = @defined ||= []
    end
  end
end
