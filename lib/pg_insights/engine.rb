require "chartkick"

module PgInsights
  class Engine < ::Rails::Engine
    isolate_namespace PgInsights

    initializer "pg_insights.assets.precompile" do |app|
      app.config.assets.precompile += %w[ pg_insights/application.css pg_insights/application.js pg_insights/health.css pg_insights/health.js ]
    end

    initializer "pg_insights.configure_background_jobs", after: "active_job.set_configs" do |app|
      ActiveSupport.on_load(:active_job) do
        if PgInsights::Engine.background_jobs_available?
          Rails.logger.info "PgInsights: Background jobs enabled (#{ActiveJob::Base.queue_adapter_name})"
        else
          PgInsights.enable_background_jobs = false
          Rails.logger.info "PgInsights: Background jobs disabled - will run health checks synchronously"
        end
      end
    end

    initializer "pg_insights.validate_configuration" do |app|
      ActiveSupport.on_load(:after_initialize) do
        if PgInsights.enable_background_jobs && !PgInsights::Engine.background_jobs_available?
          Rails.logger.warn "PgInsights: Background jobs requested but not available. Falling back to synchronous execution."
          PgInsights.enable_background_jobs = false
        end
      end
    end

    private

    def self.background_jobs_available?
      return false unless defined?(ActiveJob::Base)
      return false if ActiveJob::Base.queue_adapter.is_a?(ActiveJob::QueueAdapters::InlineAdapter)
      return false unless ActiveJob::Base.queue_adapter.respond_to?(:enqueue)

      begin
        ActiveJob::Base.queue_adapter.enqueue_at(1.second.from_now, "test")
        true
      rescue => e
        Rails.logger.debug "PgInsights: Background job test failed: #{e.message}"
        false
      end
    rescue => e
      Rails.logger.debug "PgInsights: Background job availability check failed: #{e.message}"
      false
    end
  end
end
