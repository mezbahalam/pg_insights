# frozen_string_literal: true

module PgInsights
  class HealthCheckResult < ApplicationRecord
    VALID_CHECK_TYPES = %w[
      unused_indexes
      missing_indexes
      sequential_scans
      slow_queries
      table_bloat
      parameter_settings
      database_snapshot
    ].freeze

    VALID_STATUSES = %w[pending running success error].freeze

    validates :check_type, presence: true, inclusion: { in: VALID_CHECK_TYPES }
    validates :status, presence: true, inclusion: { in: VALID_STATUSES }

    scope :recent, -> { order(executed_at: :desc) }
    scope :successful, -> { where(status: "success") }
    scope :by_type, ->(type) { where(check_type: type) }

    def self.latest_for_type(check_type)
      by_type(check_type).successful.recent.first
    end

    def self.latest_results
      VALID_CHECK_TYPES.map do |check_type|
        [ check_type, latest_for_type(check_type) ]
      end.to_h
    end

    def success?
      status == "success"
    end

    def error?
      status == "error"
    end

    def fresh?(threshold = nil)
      threshold ||= PgInsights.health_cache_expiry
      executed_at && executed_at > threshold.ago
    end

    def self.snapshots(limit = 90)
      by_type("database_snapshot").successful.recent.limit(limit)
    end

    def self.latest_snapshot
      by_type("database_snapshot").successful.recent.first
    end

    def self.snapshots_between(start_date, end_date)
      by_type("database_snapshot")
        .successful
        .where(executed_at: start_date.beginning_of_day..end_date.end_of_day)
        .order(:executed_at)
    end

    def self.find_snapshot_by_date(date)
      by_type("database_snapshot")
        .successful
        .where("DATE(executed_at) = ?", date.to_date)
        .first
    end

    def self.detect_parameter_changes_since(days_ago = 7)
      snapshots = by_type("database_snapshot")
                    .successful
                    .where("executed_at >= ?", days_ago.days.ago)
                    .order(:executed_at)
                    .to_a

      changes = []
      snapshots.each_cons(2) do |older_snapshot, newer_snapshot|
        snapshot_changes = compare_snapshots(older_snapshot, newer_snapshot)
        if snapshot_changes.any?
          changes << {
            detected_at: newer_snapshot.executed_at,
            changes: snapshot_changes
          }
        end
      end

      changes
    end

    def self.compare_snapshots(snapshot1, snapshot2)
      return {} unless snapshot1&.result_data && snapshot2&.result_data

      params1 = snapshot1.result_data.dig("parameters") || {}
      params2 = snapshot2.result_data.dig("parameters") || {}

      changes = {}
      params2.each do |param_name, new_value|
        old_value = params1[param_name]
        if old_value != new_value && !both_nil_or_empty?(old_value, new_value)
          changes[param_name] = {
            from: old_value,
            to: new_value,
            change_type: determine_change_type(param_name, old_value, new_value),
            detected_at: snapshot2.executed_at
          }
        end
      end

      changes
    end

    def self.cleanup_old_snapshots
      return unless PgInsights.snapshots_available?

      cutoff_date = PgInsights.snapshot_retention_days.days.ago
      deleted_count = by_type("database_snapshot")
                        .where("executed_at < ?", cutoff_date)
                        .delete_all

      Rails.logger.info "PgInsights: Cleaned up #{deleted_count} old snapshots" if deleted_count > 0
      deleted_count
    end

    def self.timeline_data(days = 30, parameter_changes = nil)
      snapshots = by_type("database_snapshot")
                    .successful
                    .where("executed_at >= ?", days.days.ago)
                    .order(:executed_at)

      build_timeline_data(snapshots, parameter_changes || detect_parameter_changes_since(days))
    end

    def self.build_timeline_data(snapshots, parameter_changes)
      {
        dates: snapshots.map { |s| s.executed_at.strftime("%Y-%m-%d %H:%M") },
        cache_hit_rates: snapshots.map { |s| (s.result_data.dig("metrics", "cache_hit_rate") || 0).to_f },
        avg_query_times: snapshots.map { |s| (s.result_data.dig("metrics", "avg_query_time") || 0).to_f },
        bloated_tables: snapshots.map { |s| (s.result_data.dig("metrics", "bloated_tables") || 0).to_i },
        total_connections: snapshots.map { |s| (s.result_data.dig("metrics", "total_connections") || 0).to_i },
        parameter_changes: parameter_changes
      }
    end

    private

    def self.both_nil_or_empty?(val1, val2)
      (val1.nil? || val1 == "") && (val2.nil? || val2 == "")
    end

    def self.determine_change_type(param_name, old_value, new_value)
      return "change" unless old_value && new_value

      if numeric_parameter?(param_name)
        old_numeric = extract_numeric_value(old_value)
        new_numeric = extract_numeric_value(new_value)

        return "change" unless old_numeric && new_numeric

        if new_numeric > old_numeric
          "increase"
        elsif new_numeric < old_numeric
          "decrease"
        else
          "stable"
        end
      else
        old_value == new_value ? "stable" : "change"
      end
    end

    def self.numeric_parameter?(param_name)
      %w[
        shared_buffers work_mem effective_cache_size max_connections
        maintenance_work_mem wal_buffers max_wal_size min_wal_size
        autovacuum_max_workers
      ].include?(param_name.to_s)
    end

    def self.extract_numeric_value(value)
      return value.to_f if value.is_a?(Numeric)
      return nil unless value.is_a?(String)

      if value.match(/(\d+(?:\.\d+)?)\s*(kB|MB|GB|TB)/i)
        number = $1.to_f
        unit = $2.upcase

        case unit
        when "KB" then number * 1024
        when "MB" then number * 1024 * 1024
        when "GB" then number * 1024 * 1024 * 1024
        when "TB" then number * 1024 * 1024 * 1024 * 1024
        else number
        end
      elsif value.match(/^\d+(?:\.\d+)?$/)
        value.to_f
      else
        nil
      end
    end
  end
end
