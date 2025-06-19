require "chartkick"

module PgInsights
  class Engine < ::Rails::Engine
    isolate_namespace PgInsights

    initializer "pg_insights.assets.precompile" do |app|
      app.config.assets.precompile += %w[ pg_insights/application.css pg_insights/application.js ]
    end
  end
end
