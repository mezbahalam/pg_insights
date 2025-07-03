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

    def self.collect_database_snapshot
      return unless PgInsights.snapshots_available?

      get_cached_result("database_snapshot") || execute_database_snapshot_query
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

    def self.execute_database_snapshot_query
      execute_health_check_query("database_snapshot")
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
      when "database_snapshot"
        execute_database_snapshot_sql
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
            THEN round((n_dead_tup::numeric / (n_live_tup + n_dead_tup) * 100), 2)
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
            (n_dead_tup::numeric / (n_live_tup + n_dead_tup)) > 0.1
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

    def self.execute_database_snapshot_sql
      {
        parameters: collect_enhanced_parameters,
        metrics: collect_performance_metrics,
        metadata: collect_database_metadata,
        collected_at: Time.current.iso8601
      }
    end

    def self.collect_enhanced_parameters
      settings_to_check = [
        "shared_buffers", "work_mem", "effective_cache_size",
        "max_connections", "maintenance_work_mem", "checkpoint_completion_target",
        "wal_buffers", "random_page_cost", "seq_page_cost", "cpu_tuple_cost",
        "autovacuum", "autovacuum_max_workers", "max_wal_size", "min_wal_size"
      ]

      sql = <<-SQL
        SELECT name, setting, unit, context, vartype
        FROM pg_settings
        WHERE name IN (#{settings_to_check.map { |s| "'#{s}'" }.join(',')})
        ORDER BY name;
      SQL

      result = execute_query(sql)
      return {} if result.is_a?(Hash) && result[:error]

      result.each_with_object({}) do |row, hash|
        key = row["name"]
        value = row["setting"]
        value += row["unit"] if row["unit"].present?
        hash[key] = value
      end
    end

    def self.collect_performance_metrics
      metrics = {}

      cache_sql = <<-SQL
        SELECT#{' '}
          CASE#{' '}
            WHEN sum(heap_blks_hit) + sum(heap_blks_read) = 0 THEN 0
            ELSE round((sum(heap_blks_hit)::numeric / (sum(heap_blks_hit) + sum(heap_blks_read))) * 100, 2)
          END as cache_hit_rate
        FROM pg_statio_user_tables;
      SQL

      cache_result = execute_query(cache_sql)
      metrics["cache_hit_rate"] = cache_result.first&.dig("cache_hit_rate") || 0

      if extension_available?("pg_stat_statements")
        query_sql = <<-SQL
          SELECT#{' '}
            round(avg(mean_exec_time)::numeric, 2) as avg_query_time,
            round(percentile_cont(0.95) WITHIN GROUP (ORDER BY mean_exec_time)::numeric, 2) as p95_query_time,
            count(*) as total_queries,
            sum(calls) as total_calls
          FROM pg_stat_statements#{' '}
          WHERE mean_exec_time > 0;
        SQL

        query_result = execute_query(query_sql)
        if query_result.first
          metrics["avg_query_time"] = query_result.first["avg_query_time"]
          metrics["p95_query_time"] = query_result.first["p95_query_time"]
          metrics["total_queries"] = query_result.first["total_queries"]
          metrics["total_calls"] = query_result.first["total_calls"]
        end
      end

      bloat_sql = <<-SQL
        SELECT#{' '}
          count(*) as bloated_tables,
          round(avg(CASE#{' '}
            WHEN (n_live_tup + n_dead_tup) > 0#{' '}
            THEN (n_dead_tup::numeric / (n_live_tup + n_dead_tup) * 100)
            ELSE 0#{' '}
          END), 2) as avg_bloat_pct
        FROM pg_stat_user_tables
        WHERE schemaname = 'public'
          AND (n_live_tup + n_dead_tup) > 0
          AND (n_dead_tup::numeric / (n_live_tup + n_dead_tup)) > 0.1;
      SQL

      bloat_result = execute_query(bloat_sql)
      if bloat_result.first
        metrics["bloated_tables"] = bloat_result.first["bloated_tables"] || 0
        metrics["avg_bloat_pct"] = bloat_result.first["avg_bloat_pct"] || 0
      end

      conn_sql = <<-SQL
        SELECT#{' '}
          count(*) as total_connections,
          count(*) FILTER (WHERE state = 'active') as active_connections,
          count(*) FILTER (WHERE state = 'idle') as idle_connections
        FROM pg_stat_activity;
      SQL

      conn_result = execute_query(conn_sql)
      if conn_result.first
        metrics["total_connections"] = conn_result.first["total_connections"]
        metrics["active_connections"] = conn_result.first["active_connections"]
        metrics["idle_connections"] = conn_result.first["idle_connections"]
      end

      seq_scan_sql = <<-SQL
        SELECT count(*) as high_seq_scan_tables
        FROM pg_stat_user_tables
        WHERE schemaname = 'public' AND seq_scan > 100;
      SQL

      seq_result = execute_query(seq_scan_sql)
      metrics["high_seq_scan_tables"] = seq_result.first&.dig("high_seq_scan_tables") || 0

      metrics
    end

    def self.collect_database_metadata
      {
        postgres_version: execute_query("SELECT version();").first&.dig("version"),
        database_size: execute_query("SELECT pg_size_pretty(pg_database_size(current_database()));").first&.values&.first,
        extensions: collect_extensions,
        collected_at: Time.current.iso8601
      }
    end

    def self.collect_extensions
      ext_sql = "SELECT extname FROM pg_extension ORDER BY extname;"
      result = execute_query(ext_sql)
      return [] if result.is_a?(Hash) && result[:error]

      result.map { |row| row["extname"] }
    end

    def self.extension_available?(extension_name)
      escaped_name = ActiveRecord::Base.connection.quote(extension_name)
      result = execute_query("SELECT 1 FROM pg_extension WHERE extname = #{escaped_name}")

      return false if result.is_a?(Hash) && result[:error]
      result.any?
    rescue => e
      Rails.logger.error "PgInsights: Extension availability check failed: #{e.message}"
      false
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
