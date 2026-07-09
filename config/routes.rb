Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  root "dashboard#index"

  resources :repositories, only: :create

  # Repository names may contain dots, so formats are disabled on these routes.
  scope "repos/:owner/:name", format: false do
    get "", to: "repositories#show", as: :repository
    delete "", to: "repositories#destroy"
    post "sync", to: "syncs#create", as: :repository_sync
    get "status", to: "sync_statuses#show", as: :repository_sync_status
  end
end
