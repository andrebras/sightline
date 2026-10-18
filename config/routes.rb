# No `root` route on purpose: inside the app's layout, root_path stays the app's (lib/sightline/app_routes.rb).
Sightline::Engine.routes.draw do
  get "/", to: "overview#show", as: :overview
  get "health", to: "health#show", as: :health
  # Jobs, only once the app has said who may see it (Sightline.configure sets Mission Control's base controller).
  if Sightline.config.jobs && Sightline.config.base_controller
    mount MissionControl::Jobs::Engine, at: "/jobs", as: :jobs
  end
  # The app's own pages, only those it declared, so any other path falls through to the app's routes.
  get ":page", to: "pages#show", as: :app_page,
               constraints: ->(request) { Sightline.config.find_page(request.params[:page]) }
end
