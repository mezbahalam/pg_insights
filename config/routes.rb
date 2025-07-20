PgInsights::Engine.routes.draw do
  root "insights#index"

  post "/", to: "insights#index"
  get :table_names, to: "insights#table_names"

  # Query analysis endpoints
  post :analyze, to: "insights#analyze"
  get "execution/:id", to: "insights#execution_status", as: :execution_status

  resources :queries, only: [ :create, :update, :destroy ]

  get :health, to: "health#index"
  namespace :health do
    get :unused_indexes
    get :missing_indexes
    get :sequential_scans
    get :slow_queries
    get :table_bloat
    get :parameter_settings
    post :refresh
  end

  get :timeline, to: "timeline#index"
  get "timeline/compare", to: "timeline#compare", as: :timeline_compare
  get "timeline/export", to: "timeline#export", as: :timeline_export
  get "timeline/status", to: "timeline#status", as: :timeline_status
  post "timeline/refresh", to: "timeline#refresh", as: :timeline_refresh
  get "timeline/:id", to: "timeline#show", as: :timeline_show
end
