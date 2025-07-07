# frozen_string_literal: true

module PgInsights
  class RecurringHealthChecksJob < ApplicationJob
    rescue_from(StandardError) do |exception|
      Rails.logger.error "PgInsights::RecurringHealthChecksJob failed: #{exception.message}"
    end

    def perform
      unless PgInsights.background_jobs_available?
        Rails.logger.warn "PgInsights: Background jobs not available, skipping recurring health checks"
        return
      end

      Rails.logger.debug "PgInsights: Starting recurring health check cycle"

      if HealthCheckSchedulerJob.schedule_health_checks
        Rails.logger.info "PgInsights: Recurring health check cycle initiated successfully"
      else
        Rails.logger.warn "PgInsights: Recurring health check cycle failed to start"
      end
    end

    def self.should_be_scheduled?
      PgInsights.background_jobs_available? &&
      PgInsights.enable_background_jobs &&
      defined?(HealthCheckSchedulerJob) &&
      defined?(HealthCheckJob)
    end

    def self.validate_setup
      issues = []

      issues << "Background jobs are disabled" unless PgInsights.enable_background_jobs
      issues << "ActiveJob not available" unless defined?(ActiveJob::Base)
      issues << "Queue adapter is inline (no async processing)" if ActiveJob::Base.queue_adapter.is_a?(ActiveJob::QueueAdapters::InlineAdapter)
      issues << "HealthCheckJob not available" unless defined?(HealthCheckJob)
      issues << "HealthCheckSchedulerJob not available" unless defined?(HealthCheckSchedulerJob)

      if issues.empty?
        { valid: true, message: "PgInsights recurring health checks are properly configured" }
      else
        { valid: false, issues: issues }
      end
    end
  end
end
