PgInsights::Engine.routes.draw do
  root "insights#index"

  # POST /pg_insights
  post "/", to: "insights#index"
  # GET /pg_insights/table_names
  get  :table_names, to: "insights#table_names"

  # POST /pg_insights/save_query
  post :save_query,  to: "insights#save_query"
end
