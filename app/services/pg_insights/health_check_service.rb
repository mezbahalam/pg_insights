# frozen_string_literal: true

require "timeout"

module PgInsights
  class HealthCheckService
    def self.check_unused_indexes(limit: 10)
      get_cached_result("unused_indexes") || execute_unused_indexes_query(limit)
    end

    def self.check_missing_indexes(limit: 10)
      get_cached_result("missing_indexes") || execute_missing_indexes_query(limit)
    end

    def self.check_sequential_scans(limit: 10)
      get_cached_result("sequential_scans") || execute_sequential_scans_query(limit)
    end

    def self.check_slow_queries(limit: 10)
      get_cached_result("slow_queries") || execute_slow_queries_query(limit)
    end

    def self.check_table_bloat(limit: 10)
      get_cached_result("table_bloat") || execute_table_bloat_query(limit)
    end

    def self.check_parameter_settings
      get_cached_result("parameter_settings") || execute_parameter_settings_query
    end

    def self.refresh_all!(force_synchronous: false)
      if force_synchronous || !PgInsights.background_jobs_available?
        execute_all_checks_synchronously
      else
        PgInsights.execute_with_fallback(
          HealthCheckSchedulerJob,
          :perform_later
        ) do
          Rails.logger.info "PgInsights: Falling back to synchronous health check execution"
          execute_all_checks_synchronously
        end
      end
    end

    def self.refresh_check!(check_type, limit: 10, force_synchronous: false)
      if force_synchronous || !PgInsights.background_jobs_available?
        execute_and_cache_check(check_type, limit)
      else
        PgInsights.execute_with_fallback(
          HealthCheckJob,
          :perform_later,
          check_type,
          { "limit" => limit }
        ) do
          Rails.logger.info "PgInsights: Falling back to synchronous execution for #{check_type}"
          execute_and_cache_check(check_type, limit)
        end
      end
    end

    def self.execute_all_checks_synchronously
      HealthCheckResult::VALID_CHECK_TYPES.each do |check_type|
        execute_and_cache_check(check_type)
      end
    end

    def self.execute_and_cache_check(check_type, limit = 10)
      return unless HealthCheckResult::VALID_CHECK_TYPES.include?(check_type)

      result = HealthCheckResult.create!(
        check_type: check_type,
        status: "running",
        executed_at: Time.current
      )

      start_time = Time.current

      begin
        data = execute_health_check_query(check_type, limit)
        execution_time = ((Time.current - start_time) * 1000).to_i

        result.update!(
          status: "success",
          result_data: data,
          execution_time_ms: execution_time
        )

        data
      rescue => e
        execution_time = ((Time.current - start_time) * 1000).to_i

        result.update!(
          status: "error",
          error_message: e.message,
          execution_time_ms: execution_time
        )

        Rails.logger.error "PgInsights: Health check failed for #{check_type}: #{e.message}"
        { error: e.message }
      end
    end

    def self.execute_unused_indexes_query(limit)
      execute_health_check_query("unused_indexes", limit)
    end

    def self.execute_missing_indexes_query(limit)
      execute_health_check_query("missing_indexes", limit)
    end

    def self.execute_sequential_scans_query(limit)
      execute_health_check_query("sequential_scans", limit)
    end

    def self.execute_slow_queries_query(limit)
      execute_health_check_query("slow_queries", limit)
    end

    def self.execute_table_bloat_query(limit)
      execute_health_check_query("table_bloat", limit)
    end

    def self.execute_parameter_settings_query
      execute_health_check_query("parameter_settings")
    end

    def self.execute_health_check_query(check_type, limit = 10)
      case check_type
      when "unused_indexes"
        execute_unused_indexes_sql(limit)
      when "missing_indexes"
        execute_missing_indexes_sql(limit)
      when "sequential_scans"
        execute_sequential_scans_sql(limit)
      when "slow_queries"
        execute_slow_queries_sql(limit)
      when "table_bloat"
        execute_table_bloat_sql(limit)
      when "parameter_settings"
        execute_parameter_settings_sql
      else
        raise ArgumentError, "Unknown check type: #{check_type}"
      end
    end

    private

    def self.execute_unused_indexes_sql(limit)
      sql = <<-SQL
        SELECT
          schemaname || '.' || relname AS table,
          indexrelname AS index,
          pg_size_pretty(pg_relation_size(indexrelid)) AS index_size,
          idx_scan AS index_scans
        FROM pg_stat_all_indexes
        WHERE schemaname = 'public'
          AND idx_scan < 50
          AND indexrelid NOT IN (SELECT conindid FROM pg_constraint)
        ORDER BY pg_relation_size(indexrelid) DESC
        LIMIT #{limit.to_i};
      SQL

      execute_query(sql)
    end

    def self.execute_missing_indexes_sql(limit)
      sql = <<-SQL
        SELECT
          schemaname || '.' || relname AS table,
          seq_scan,
          idx_scan,
          pg_size_pretty(pg_relation_size(relid)) AS table_size
        FROM pg_stat_all_tables
        WHERE schemaname = 'public'
          AND seq_scan > 1000
          AND idx_scan = 0
        ORDER BY seq_scan DESC
        LIMIT #{limit.to_i};
      SQL

      execute_query(sql)
    end

    def self.execute_sequential_scans_sql(limit)
      sql = <<-SQL
        SELECT
          schemaname || '.' || relname AS table,
          seq_scan,
          seq_tup_read,
          pg_size_pretty(pg_relation_size(relid)) AS table_size
        FROM pg_stat_all_tables
        WHERE schemaname = 'public' AND seq_scan > 100
        ORDER BY seq_scan DESC
        LIMIT #{limit.to_i};
      SQL
      execute_query(sql)
    end

    def self.execute_slow_queries_sql(limit)
      sql = <<-SQL
        SELECT
          query,
          calls,
          total_exec_time,
          mean_exec_time,
          rows
        FROM pg_stat_statements
        ORDER BY total_exec_time DESC
        LIMIT #{limit.to_i};
      SQL
      execute_query(sql)
    end

    def self.execute_table_bloat_sql(limit)
      sql = <<-SQL
        SELECT#{' '}
          schemaname || '.' || relname as table_name,
          pg_size_pretty(pg_total_relation_size(relid)) as table_size,
          n_dead_tup,
          n_live_tup,
          CASE#{' '}
            WHEN (n_live_tup + n_dead_tup) > 0#{' '}
            THEN round((n_dead_tup::float / (n_live_tup + n_dead_tup) * 100)::numeric, 2)
            ELSE 0#{' '}
          END as dead_tuple_pct,
          pg_size_pretty(pg_total_relation_size(relid) / (1024*1024)) || ' MB' as table_mb_text,
          (pg_total_relation_size(relid) / (1024*1024))::bigint as table_mb,
          last_vacuum,
          last_autovacuum,
          last_analyze,
          last_autoanalyze
        FROM pg_stat_user_tables#{' '}
        WHERE schemaname = 'public'
          AND (n_live_tup + n_dead_tup) > 0
          AND (
            (n_dead_tup::float / (n_live_tup + n_dead_tup)) > 0.1
            OR n_dead_tup > 1000
          )
          AND pg_total_relation_size(relid) > 1024*1024
        ORDER BY dead_tuple_pct DESC, n_dead_tup DESC
        LIMIT #{limit.to_i};
      SQL
      execute_query(sql)
    end

    def self.execute_parameter_settings_sql
      settings_to_check = [
        "shared_buffers", "work_mem", "effective_cache_size",
        "max_connections", "maintenance_work_mem", "checkpoint_completion_target"
      ]

      sql = <<-SQL
        SELECT name, setting, unit, short_desc
        FROM pg_settings
        WHERE name IN (#{settings_to_check.map { |s| "'#{s}'" }.join(',')});
      SQL

      result = execute_query(sql)
      return result if result.is_a?(Hash) && result[:error]

      # todo basic recommendations (can be improved with system info)
      recommendations = {
        "shared_buffers" => "Recommended: 25% of total system RAM.",
        "work_mem" => "Recommended: Based on RAM, connections, and query complexity. Default is often too low.",
        "effective_cache_size" => "Recommended: 75% of total system RAM.",
        "max_connections" => "Varies. Check your connection pooler settings.",
        "maintenance_work_mem" => "Recommended: 10% of RAM (up to 2GB).",
        "checkpoint_completion_target" => "Recommended: 0.9"
      }

      result.map do |setting|
        setting.merge("recommendation" => recommendations[setting["name"]])
      end
    end

    def self.get_cached_result(check_type)
      return nil unless defined?(HealthCheckResult)

      result = HealthCheckResult.latest_for_type(check_type)
      return nil unless result&.fresh?

      result.result_data
    end

    def self.execute_query(sql)
      timeout = PgInsights.health_check_timeout

      Timeout.timeout(timeout) do
        ActiveRecord::Base.connection.exec_query(sql)
      end
    rescue Timeout::Error => e
      Rails.logger.error "PgInsights: Query timeout (#{timeout}s) - #{e.message}"
      { error: "Query timeout after #{timeout} seconds" }
    rescue ActiveRecord::StatementInvalid, PG::Error => e
      { error: e.message }
    end
  end
end
