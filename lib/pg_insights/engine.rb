# frozen_string_literal: true

require "chartkick"

module PgInsights
  class Engine < ::Rails::Engine
    isolate_namespace PgInsights

    initializer "pg_insights.assets.precompile" do |app|
      app.config.assets.precompile += %w[
        pg_insights/application.css
        pg_insights/application.js
        pg_insights/analysis.css
        pg_insights/health.css
        pg_insights/health.js
        pg_insights/results.css
        pg_insights/results.js
        pg_insights/query_comparison.js
        pg_insights/plan_performance.js
        pg_insights/results/view_toggles.js
        pg_insights/results/chart_renderer.js
        pg_insights/results/table_manager.js
        chartkick.js
        Chart.bundle.js
      ]
    end

    initializer "pg_insights.configure_background_jobs", after: "active_job.set_configs" do |app|
      ActiveSupport.on_load(:active_job) do
        if PgInsights.enable_background_jobs
          if PgInsights.background_jobs_available?
            Rails.logger.info "PgInsights: Background jobs enabled (#{ActiveJob::Base.queue_adapter_name})"
          else
            Rails.logger.warn "PgInsights: Background jobs enabled but may not be fully available yet."
            Rails.logger.warn "PgInsights: Will fall back to synchronous execution when needed."
            Rails.logger.warn "PgInsights: Check your ActiveJob configuration if you see issues."
          end
        else
          Rails.logger.info "PgInsights: Background jobs disabled - will run health checks synchronously"
        end
      end
    end

    rake_tasks do
      load "tasks/pg_insights.rake"
    end
  end
end
