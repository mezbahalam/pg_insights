# frozen_string_literal: true

module PgInsights
  class DatabaseSnapshotJob < ApplicationJob
    rescue_from(StandardError) do |exception|
      Rails.logger.error "PgInsights::DatabaseSnapshotJob failed: #{exception.message}"
    end

    def perform
      unless PgInsights.snapshots_available?
        Rails.logger.warn "PgInsights: Snapshots not available, skipping snapshot collection"
        return
      end

      Rails.logger.info "PgInsights: Starting database snapshot collection"

      begin
        # Use existing infrastructure to collect and store snapshot
        HealthCheckService.execute_and_cache_check("database_snapshot")

        # Cleanup old snapshots after successful collection
        cleanup_count = HealthCheckResult.cleanup_old_snapshots

        Rails.logger.info "PgInsights: Database snapshot completed successfully"
        Rails.logger.info "PgInsights: Cleaned up #{cleanup_count} old snapshots" if cleanup_count > 0
      rescue => e
        Rails.logger.error "PgInsights: Database snapshot collection failed: #{e.message}"
        raise e
      end
    end

    def self.schedule_next_snapshot
      return false unless PgInsights.snapshots_available?
      return false unless PgInsights.background_jobs_available?

      begin
        # Schedule the next snapshot based on configured frequency
        next_run_time = Time.current + PgInsights.snapshot_frequency
        set(wait_until: next_run_time).perform_later

        Rails.logger.info "PgInsights: Next snapshot scheduled for #{next_run_time}"
        true
      rescue => e
        Rails.logger.warn "PgInsights: Failed to schedule next snapshot: #{e.message}"
        false
      end
    end

    def self.start_recurring_snapshots
      return false unless PgInsights.snapshots_available?
      return false unless PgInsights.background_jobs_available?

      begin
        # Start the recurring snapshot cycle
        perform_later
        Rails.logger.info "PgInsights: Recurring snapshots started with frequency: #{PgInsights.snapshot_frequency}"
        true
      rescue => e
        Rails.logger.warn "PgInsights: Failed to start recurring snapshots: #{e.message}"
        false
      end
    end

    def self.validate_configuration
      issues = []

      issues << "Snapshots are disabled" unless PgInsights.enable_snapshots
      issues << "Snapshot collection is disabled" unless PgInsights.snapshot_collection_enabled
      issues << "Background jobs not available" unless PgInsights.background_jobs_available?
      issues << "HealthCheckResult model not available" unless defined?(HealthCheckResult)

      frequency = PgInsights.snapshot_frequency
      if frequency.respond_to?(:to_i) && frequency.to_i < 60
        issues << "Snapshot frequency too low (minimum 1 minute recommended)"
      end

      if issues.empty?
        { valid: true, message: "Database snapshots are properly configured" }
      else
        { valid: false, issues: issues }
      end
    end

    private

    # Override perform to automatically schedule the next run
    def perform_with_scheduling
      perform

      # Schedule the next snapshot if this one was successful
      self.class.schedule_next_snapshot if PgInsights.snapshots_available?
    rescue => e
      # Log the error but still try to schedule the next run
      Rails.logger.error "PgInsights: Snapshot failed but will retry: #{e.message}"
      self.class.schedule_next_snapshot if PgInsights.snapshots_available?
      raise e
    end
  end
end
