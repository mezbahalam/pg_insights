PgInsights::Engine.routes.draw do
  root "insights#index"

  # For running queries and loading the main UI
  post "/", to: "insights#index"

  # For the table name dropdown
  get :table_names, to: "insights#table_names"

  # For managing user-saved queries
  resources :queries, only: [ :create, :update, :destroy ]
end
