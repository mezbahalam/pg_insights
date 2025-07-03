# frozen_string_literal: true

module PgInsights
  class TimelineController < ApplicationController
    layout "pg_insights/application"

    def index
      unless PgInsights.snapshots_available?
        flash[:notice] = "Database snapshots are not enabled. Configure PgInsights.enable_snapshots = true to use timeline features."
        redirect_to health_path
        return
      end

      @snapshots = HealthCheckResult.snapshots(90)
      @parameter_changes = HealthCheckResult.detect_parameter_changes_since(30)
      @timeline_data = HealthCheckResult.timeline_data(30)
      @stats = calculate_timeline_stats(@snapshots)
    end

    def show
      @snapshot = HealthCheckResult.find(params[:id])

      unless @snapshot.check_type == "database_snapshot"
        flash[:error] = "Invalid snapshot"
        redirect_to timeline_path
        return
      end

      @previous_snapshot = HealthCheckResult.snapshots
                                           .where("executed_at < ?", @snapshot.executed_at)
                                           .first

      if @previous_snapshot
        @parameter_changes = HealthCheckResult.compare_snapshots(@previous_snapshot, @snapshot)
        @performance_comparison = compare_performance_metrics(@previous_snapshot, @snapshot)
      end
    end

    def compare
      @date1 = Date.parse(params[:date1]) rescue nil
      @date2 = Date.parse(params[:date2]) rescue nil

      unless @date1 && @date2
        flash[:error] = "Invalid dates provided"
        redirect_to timeline_path
        return
      end

      @snapshot1 = HealthCheckResult.find_snapshot_by_date(@date1)
      @snapshot2 = HealthCheckResult.find_snapshot_by_date(@date2)

      unless @snapshot1 && @snapshot2
        flash[:error] = "Could not find snapshots for the selected dates"
        redirect_to timeline_path
        return
      end

                  @parameter_changes = HealthCheckResult.compare_snapshots(@snapshot1, @snapshot2)
      performance_metrics = compare_performance_metrics(@snapshot1, @snapshot2)
      @performance_comparison = {
        metrics: performance_metrics.transform_values do |data|
          data.merge(difference: data[:change])
        end
      }
      @metadata_comparison = compare_metadata(@snapshot1, @snapshot2)
      @configuration_comparison = @parameter_changes

      @comparison_data = {
        snapshot1: @snapshot1,
        snapshot2: @snapshot2,
        parameters: @parameter_changes,
        performance: @performance_comparison,
        metadata: @metadata_comparison
      }
    end

    def export
      format = params[:format]&.downcase || "csv"
      days = params[:days]&.to_i || 30

      snapshots = HealthCheckResult.snapshots(days + 30)

      case format
      when "csv"
        send_data generate_csv_export(snapshots),
                  filename: "pg_insights_timeline_#{Date.current}.csv",
                  type: "text/csv",
                  disposition: "attachment"
      when "json"
        send_data generate_json_export(snapshots),
                  filename: "pg_insights_timeline_#{Date.current}.json",
                  type: "application/json",
                  disposition: "attachment"
      else
        flash[:error] = "Unsupported export format. Use 'csv' or 'json'."
        redirect_to timeline_path
      end
    end

    def refresh
      if PgInsights.snapshots_available? && PgInsights.background_jobs_available?
        if PgInsights::DatabaseSnapshotJob.perform_later
          render json: { message: "Snapshot collection started" }
        else
          render json: { error: "Failed to start snapshot collection" }, status: 422
        end
      else
        begin
          HealthCheckService.execute_and_cache_check("database_snapshot")
          render json: { message: "Snapshot collected successfully" }
        rescue => e
          render json: { error: "Snapshot collection failed: #{e.message}" }, status: 422
        end
      end
    end

    def status
      snapshot_status = {
        enabled: PgInsights.snapshots_available?,
        frequency: PgInsights.snapshot_frequency,
        retention_days: PgInsights.snapshot_retention_days,
        latest_snapshot: HealthCheckResult.latest_snapshot&.executed_at,
        total_snapshots: HealthCheckResult.snapshots.count,
        configuration_valid: PgInsights::DatabaseSnapshotJob.validate_configuration
      }

      render json: snapshot_status
    end

    private

    def calculate_timeline_stats(snapshots)
      return {} if snapshots.empty?

      latest = snapshots.first
      oldest = snapshots.last

      cache_hit_rate = latest.result_data.dig("metrics", "cache_hit_rate")
      numeric_cache_hit_rate = cache_hit_rate ? cache_hit_rate.to_f : nil

      {
        total_snapshots: snapshots.count,
        date_range: {
          from: oldest.executed_at.to_date,
          to: latest.executed_at.to_date
        },
        latest_cache_hit_rate: numeric_cache_hit_rate,
        parameter_changes_count: @parameter_changes.sum { |change| change[:changes].count }
      }
    end

    def compare_performance_metrics(snapshot1, snapshot2)
      metrics1 = snapshot1.result_data["metrics"] || {}
      metrics2 = snapshot2.result_data["metrics"] || {}

      comparison = {}

      %w[cache_hit_rate avg_query_time p95_query_time bloated_tables
         total_connections active_connections high_seq_scan_tables].each do |metric|
        val1 = metrics1[metric]
        val2 = metrics2[metric]

        if val1 && val2
          num_val1 = val1.to_f
          num_val2 = val2.to_f

          change = num_val2 - num_val1
          change_pct = num_val1 != 0 ? (change / num_val1) * 100 : 0

          comparison[metric] = {
            before: num_val1,
            after: num_val2,
            change: change.round(2),
            change_percent: change_pct.round(2),
            direction: change > 0 ? "increase" : (change < 0 ? "decrease" : "stable")
          }
        end
      end

      comparison
    end

    def compare_metadata(snapshot1, snapshot2)
      meta1 = snapshot1.result_data["metadata"] || {}
      meta2 = snapshot2.result_data["metadata"] || {}

      {
        postgres_version_changed: meta1["postgresql_version"] != meta2["postgresql_version"],
        extensions_added: (meta2["extensions"] || []) - (meta1["extensions"] || []),
        extensions_removed: (meta1["extensions"] || []) - (meta2["extensions"] || []),
        database_size: {
          before: meta1["database_size"],
          after: meta2["database_size"]
        },
        table_count: {
          before: meta1["table_count"],
          after: meta2["table_count"]
        },
        index_count: {
          before: meta1["index_count"],
          after: meta2["index_count"]
        }
      }
    end

    def generate_csv_export(snapshots)
      require "csv"

      CSV.generate(headers: true) do |csv|
        csv << [
          "Date", "Time", "Cache Hit Rate %", "Avg Query Time (ms)", "P95 Query Time (ms)",
          "Bloated Tables", "Total Connections", "Active Connections", "High Seq Scan Tables",
          "Database Size", "PostgreSQL Version"
        ]

        snapshots.each do |snapshot|
          metrics = snapshot.result_data["metrics"] || {}
          metadata = snapshot.result_data["metadata"] || {}

          csv << [
            snapshot.executed_at.strftime("%Y-%m-%d"),
            snapshot.executed_at.strftime("%H:%M:%S"),
            metrics["cache_hit_rate"]&.to_f,
            metrics["avg_query_time"]&.to_f,
            metrics["p95_query_time"]&.to_f,
            metrics["bloated_tables"]&.to_i,
            metrics["total_connections"]&.to_i,
            metrics["active_connections"]&.to_i,
            metrics["high_seq_scan_tables"]&.to_i,
            metadata["database_size"],
            metadata["postgres_version"]&.split(" ")&.first
          ]
        end
      end
    end

    def generate_json_export(snapshots)
      {
        exported_at: Time.current.iso8601,
        export_info: {
          snapshot_count: snapshots.size,
          date_range: {
            from: snapshots.last&.executed_at,
            to: snapshots.first&.executed_at
          },
          frequency: PgInsights.snapshot_frequency.to_s,
          retention_days: PgInsights.snapshot_retention_days
        },
        parameter_changes: HealthCheckResult.detect_parameter_changes_since(30),
        snapshots: snapshots.map do |snapshot|
          {
            id: snapshot.id,
            collected_at: snapshot.executed_at.iso8601,
            execution_time_ms: snapshot.execution_time_ms,
            parameters: snapshot.result_data["parameters"],
            metrics: snapshot.result_data["metrics"],
            metadata: snapshot.result_data["metadata"]
          }
        end
      }.to_json(indent: 2)
    end
  end
end
