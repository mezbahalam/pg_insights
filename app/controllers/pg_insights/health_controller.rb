# frozen_string_literal: true

module PgInsights
  class HealthController < ApplicationController
    layout "pg_insights/application"

    def index
      @health_results = HealthCheckResult.latest_results

      @unused_indexes = extract_or_fetch("unused_indexes") { HealthCheckService.check_unused_indexes }
      @missing_indexes = extract_or_fetch("missing_indexes") { HealthCheckService.check_missing_indexes }
      @sequential_scans = extract_or_fetch("sequential_scans") { HealthCheckService.check_sequential_scans }
      @slow_queries = extract_or_fetch("slow_queries") { HealthCheckService.check_slow_queries }
      @table_bloat = extract_or_fetch("table_bloat") { HealthCheckService.check_table_bloat }
      @parameter_settings = extract_or_fetch("parameter_settings") { HealthCheckService.check_parameter_settings }

      refresh_stale_data_async
    end

    def unused_indexes
      result = HealthCheckResult.latest_for_type("unused_indexes")
      render json: {
        data: result&.result_data || [],
        status: result&.status || "pending",
        executed_at: result&.executed_at,
        fresh: result&.fresh? || false
      }
    end

    def missing_indexes
      result = HealthCheckResult.latest_for_type("missing_indexes")
      render json: {
        data: result&.result_data || [],
        status: result&.status || "pending",
        executed_at: result&.executed_at,
        fresh: result&.fresh? || false
      }
    end

    def sequential_scans
      result = HealthCheckResult.latest_for_type("sequential_scans")
      render json: {
        data: result&.result_data || [],
        status: result&.status || "pending",
        executed_at: result&.executed_at,
        fresh: result&.fresh? || false
      }
    end

    def slow_queries
      result = HealthCheckResult.latest_for_type("slow_queries")
      render json: {
        data: result&.result_data || [],
        status: result&.status || "pending",
        executed_at: result&.executed_at,
        fresh: result&.fresh? || false
      }
    end

    def table_bloat
      result = HealthCheckResult.latest_for_type("table_bloat")
      render json: {
        data: result&.result_data || [],
        status: result&.status || "pending",
        executed_at: result&.executed_at,
        fresh: result&.fresh? || false
      }
    end

    def parameter_settings
      result = HealthCheckResult.latest_for_type("parameter_settings")
      render json: {
        data: result&.result_data || [],
        status: result&.status || "pending",
        executed_at: result&.executed_at,
        fresh: result&.fresh? || false
      }
    end

    def refresh
      HealthCheckService.refresh_all!
      render json: { message: "Health checks queued for refresh" }
    end

    private

    def extract_or_fetch(check_type)
      cached_result = @health_results[check_type]

      if cached_result&.fresh?
        return cached_result.result_data
      end

      begin
        yield
      rescue => e
        Rails.logger.error "Health check failed for #{check_type}: #{e.message}"
        { error: e.message }
      end
    end

    def refresh_stale_data_async
      stale_checks = @health_results.select { |_, result| result.nil? || !result.fresh? }

      if stale_checks.any?
        HealthCheckService.refresh_all!
      end
    end
  end
end
