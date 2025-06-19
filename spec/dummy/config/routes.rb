Rails.application.routes.draw do
  mount PgInsights::Engine => "/pg_insights"
end
