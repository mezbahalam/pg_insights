# frozen_string_literal: true

module PgInsights
  class HealthCheckJob < ApplicationJob
    queue_as -> { PgInsights.background_job_queue }

    rescue_from(StandardError) do |exception|
      Rails.logger.error "PgInsights::HealthCheckJob failed: #{exception.message}"
    end

    def perform(check_type, options = {})
      unless PgInsights.background_jobs_available?
        Rails.logger.warn "PgInsights: Background jobs not available, skipping #{check_type} check"
        return
      end

      limit = options.fetch("limit", 10)

      Rails.logger.debug "PgInsights: Starting background health check for #{check_type}"

      begin
        HealthCheckService.execute_and_cache_check(check_type, limit)
        Rails.logger.debug "PgInsights: Completed background health check for #{check_type}"
      rescue => e
        Rails.logger.error "PgInsights: Background health check failed for #{check_type}: #{e.message}"
      end
    end

    def self.queue_name
      PgInsights.background_job_queue
    end

    def self.perform_check(check_type, options = {})
      return false unless PgInsights.background_jobs_available?

      begin
        perform_later(check_type, options)
        true
      rescue => e
        Rails.logger.warn "PgInsights: Failed to enqueue health check job for #{check_type}: #{e.message}"
        false
      end
    end
  end
end
