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
  end
end
