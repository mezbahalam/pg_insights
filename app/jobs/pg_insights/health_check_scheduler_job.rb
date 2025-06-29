# frozen_string_literal: true

module PgInsights
  class HealthCheckSchedulerJob < ApplicationJob
    queue_as -> { PgInsights.background_job_queue }

    rescue_from(StandardError) do |exception|
      Rails.logger.error "PgInsights::HealthCheckSchedulerJob failed: #{exception.message}"
    end

    def perform
      unless PgInsights.background_jobs_available?
        Rails.logger.warn "PgInsights: Background jobs not available, skipping scheduler"
        return
      end

      Rails.logger.debug "PgInsights: Starting health check scheduler"

      scheduled_count = 0

      HealthCheckResult::VALID_CHECK_TYPES.each do |check_type|
        latest = HealthCheckResult.latest_for_type(check_type)

        if latest.nil? || !latest.fresh?
          if HealthCheckJob.perform_check(check_type)
            scheduled_count += 1
            Rails.logger.debug "PgInsights: Scheduled health check for #{check_type}"
          else
            Rails.logger.warn "PgInsights: Failed to schedule health check for #{check_type}"
          end
        else
          Rails.logger.debug "PgInsights: Skipping #{check_type} - data is fresh"
        end
      end

      Rails.logger.info "PgInsights: Health check scheduler completed. Scheduled #{scheduled_count} checks."
    end

    def self.schedule_health_checks
      return false unless PgInsights.background_jobs_available?

      begin
        perform_later
        Rails.logger.info "PgInsights: Health check scheduler enqueued successfully"
        true
      rescue => e
        Rails.logger.warn "PgInsights: Failed to enqueue health check scheduler: #{e.message}"
        false
      end
    end
  end
end
