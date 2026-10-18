Rails.application.routes.draw do
  root "home#show"
  get "things", to: "home#show", as: :things
  mount Sightline::Engine, at: "/admin"
  get "admin/elsewhere", to: "home#show"
end
