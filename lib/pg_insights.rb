require "pg_insights/version"
require "pg_insights/engine"

module PgInsights
  mattr_accessor :enable_background_jobs, default: true
  mattr_accessor :health_cache_expiry, default: 5.minutes
  mattr_accessor :background_job_queue, default: :pg_insights_health

  # Query execution timeout settings (granular control)
  mattr_accessor :query_execution_timeout, default: 30.seconds     # Regular "Execute" button queries
  mattr_accessor :query_analysis_timeout, default: 60.seconds      # "Analyze" button queries (EXPLAIN ANALYZE)
  mattr_accessor :health_check_timeout, default: 20.seconds        # Health check queries

  mattr_accessor :enable_snapshots, default: true
  mattr_accessor :snapshot_frequency, default: 1.day
  mattr_accessor :snapshot_retention_days, default: 90
  mattr_accessor :snapshot_collection_enabled, default: true

  def self.configure
    yield self
  end

  # Helper methods to get timeout values in milliseconds for PostgreSQL
  def self.query_execution_timeout_ms
    (query_execution_timeout.to_f * 1000).to_i
  end

  def self.query_analysis_timeout_ms
    (query_analysis_timeout.to_f * 1000).to_i
  end

  def self.health_check_timeout_ms
    (health_check_timeout.to_f * 1000).to_i
  end

  def self.background_jobs_available?
    return false unless enable_background_jobs
    return false unless defined?(ActiveJob::Base)
    return false if ActiveJob::Base.queue_adapter.is_a?(ActiveJob::QueueAdapters::InlineAdapter)
    return false unless defined?(PgInsights::HealthCheckJob)

    begin
      ActiveJob::Base.queue_adapter.respond_to?(:enqueue) ||
      ActiveJob::Base.queue_adapter.respond_to?(:enqueue_at)
    rescue => e
      Rails.logger.debug "PgInsights: Background job check failed: #{e.message}" if defined?(Rails)
      false
    end
  end

  def self.execute_with_fallback(job_class, method_name, *args, &fallback_block)
    if background_jobs_available?
      begin
        job_class.public_send(method_name, *args)
        return true
      rescue => e
        Rails.logger.warn "PgInsights: Background job failed, falling back to synchronous execution: #{e.message}" if defined?(Rails)
      end
    end

    fallback_block.call if fallback_block
    false
  end

  def self.snapshots_available?
    return false unless enable_snapshots
    return false unless snapshot_collection_enabled
    return false unless defined?(PgInsights::HealthCheckResult)

    true
  end

  def self.snapshot_interval_seconds
    case snapshot_frequency
    when ActiveSupport::Duration
      snapshot_frequency.to_i
    when Integer
      snapshot_frequency
    else
      1.day.to_i
    end
  end

  module Integration
    def self.status
      {
        background_jobs_available: PgInsights.background_jobs_available?,
        queue_adapter: defined?(ActiveJob::Base) ? ActiveJob::Base.queue_adapter_name : "not_available",
        configuration: {
          enable_background_jobs: PgInsights.enable_background_jobs,
          health_cache_expiry: PgInsights.health_cache_expiry,
          background_job_queue: PgInsights.background_job_queue
        }
      }
    end

    def self.test_background_jobs
      return { success: false, error: "Background jobs disabled" } unless PgInsights.enable_background_jobs
      return { success: false, error: "ActiveJob not available" } unless defined?(ActiveJob::Base)

      begin
        if defined?(PgInsights::HealthCheckJob)
          Rails.logger.info "PgInsights: Testing background job capability..."
          { success: true, message: "Background jobs appear to be working" }
        else
          { success: false, error: "PgInsights job classes not loaded" }
        end
      rescue => e
        { success: false, error: e.message }
      end
    end
  end
end
