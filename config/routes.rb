# No `root` route on purpose: inside the app's layout, root_path stays the app's (lib/sightline/app_routes.rb).
Sightline::Engine.routes.draw do
  get "/", to: "overview#show", as: :overview
  get "health", to: "health#show", as: :health
  # The app's own pages, only those it declared, so any other path falls through to the app's routes.
  get ":page", to: "pages#show", as: :app_page,
               constraints: ->(request) { Sightline.config.find_page(request.params[:page]) }
end
