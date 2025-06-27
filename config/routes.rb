PgInsights::Engine.routes.draw do
  root "insights#index"

  # For running queries and loading the main UI
  post "/", to: "insights#index"

  # For the table name dropdown
  get :table_names, to: "insights#table_names"

  # For managing user-saved queries
  resources :queries, only: [ :create, :update, :destroy ]  # For the health dashboard
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
end
