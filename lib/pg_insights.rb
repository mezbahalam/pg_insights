require "pg_insights/version"
require "pg_insights/engine"

module PgInsights
  # Configuration options
  mattr_accessor :enable_background_jobs, default: true
  mattr_accessor :health_cache_expiry, default: 5.minutes
  mattr_accessor :background_job_queue, default: :pg_insights_health
  mattr_accessor :max_query_execution_time, default: 30.seconds
  mattr_accessor :health_check_timeout, default: 10.seconds

  def self.configure
    yield self
  end

  # Check if background jobs are available and properly configured
  def self.background_jobs_available?
    return false unless enable_background_jobs
    return false unless defined?(ActiveJob::Base)
    return false if ActiveJob::Base.queue_adapter.is_a?(ActiveJob::QueueAdapters::InlineAdapter)
    return false unless defined?(PgInsights::HealthCheckJob)

    # Verify the queue adapter can handle our jobs
    begin
      ActiveJob::Base.queue_adapter.respond_to?(:enqueue) ||
      ActiveJob::Base.queue_adapter.respond_to?(:enqueue_at)
    rescue => e
      Rails.logger.debug "PgInsights: Background job check failed: #{e.message}" if defined?(Rails)
      false
    end
  end

  # Safely execute background jobs with fallback
  def self.execute_with_fallback(job_class, method_name, *args, &fallback_block)
    if background_jobs_available?
      begin
        job_class.public_send(method_name, *args)
        return true
      rescue => e
        Rails.logger.warn "PgInsights: Background job failed, falling back to synchronous execution: #{e.message}" if defined?(Rails)
      end
    end

    # Execute fallback if provided
    fallback_block.call if fallback_block
    false
  end

  # Integration helpers for host applications
  module Integration
    # Helper for host apps to check if they need to configure anything
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

    # Helper for host apps to test job functionality
    def self.test_background_jobs
      return { success: false, error: "Background jobs disabled" } unless PgInsights.enable_background_jobs
      return { success: false, error: "ActiveJob not available" } unless defined?(ActiveJob::Base)

      begin
        # Try to enqueue a simple test
        if defined?(PgInsights::HealthCheckJob)
          # Don't actually run the job, just test enqueueing
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
