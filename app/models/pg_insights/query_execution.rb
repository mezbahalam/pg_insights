# frozen_string_literal: true

module PgInsights
  class QueryExecution < ApplicationRecord
    belongs_to :query, class_name: "PgInsights::Query", optional: true

    EXECUTION_TYPES = %w[execute analyze both].freeze
    STATUSES = %w[pending running completed failed].freeze

    validates :sql_text, presence: true
    validates :execution_type, inclusion: { in: EXECUTION_TYPES }
    validates :status, inclusion: { in: STATUSES }

    scope :recent, -> { order(created_at: :desc) }
    scope :completed, -> { where(status: "completed") }
    scope :failed, -> { where(status: "failed") }
    scope :with_analysis, -> { where(execution_type: [ "analyze", "both" ]) }
    scope :with_results, -> { where(execution_type: [ "execute", "both" ]) }

    # Status management
    def pending?
      status == "pending"
    end

    def running?
      status == "running"
    end

    def completed?
      status == "completed"
    end

    def failed?
      status == "failed"
    end

    def success?
      completed? && error_message.blank?
    end

    # Execution type checks
    def includes_execution?
      execution_type.in?([ "execute", "both" ])
    end

    def includes_analysis?
      execution_type.in?([ "analyze", "both" ])
    end

    # Performance metrics
    def has_timing_data?
      planning_time_ms.present? || execution_time_ms.present?
    end

    def formatted_total_time
      return nil unless total_time_ms

      if total_time_ms < 1000
        "#{total_time_ms.round(2)}ms"
      else
        "#{(total_time_ms / 1000).round(2)}s"
      end
    end

    def formatted_query_cost
      return nil unless query_cost

      if query_cost < 1000
        query_cost.round(2)
      else
        "#{(query_cost / 1000).round(1)}K"
      end
    end

    # Plan analysis helpers
    def has_plan_data?
      execution_plan.present?
    end

    def plan_nodes
      return [] unless execution_plan.present?

      # Extract plan nodes from PostgreSQL EXPLAIN output
      plan_data = execution_plan.is_a?(Array) ? execution_plan.first : execution_plan
      extract_plan_nodes(plan_data["Plan"]) if plan_data && plan_data["Plan"]
    end

    def optimization_suggestions
      return [] unless performance_insights.present?

      performance_insights["suggestions"] || []
    end

    def has_performance_issues?
      return false unless performance_insights.present?

      insights = performance_insights
      insights["issues_detected"] == true ||
      insights["slow_operations"].present? ||
      insights["missing_indexes"].present?
    end

    # Result data helpers
    def has_result_data?
      result_data.present? && result_rows_count.present?
    end

    def result_summary
      return nil unless has_result_data?

      "#{result_rows_count} #{'row'.pluralize(result_rows_count)} • #{result_columns_count} #{'column'.pluralize(result_columns_count)}"
    end

    # Status transitions
    def mark_as_running!
      update!(
        status: "running",
        started_at: Time.current
      )
    end

    def mark_as_completed!(results = {})
      update!(
        status: "completed",
        completed_at: Time.current,
        duration_ms: calculate_duration,
        **results
      )
    end

    def mark_as_failed!(error_msg, error_detail = nil)
      update!(
        status: "failed",
        completed_at: Time.current,
        duration_ms: calculate_duration,
        error_message: error_msg,
        error_detail: error_detail
      )
    end

    private

    def calculate_duration
      return nil unless started_at

      end_time = completed_at || Time.current
      ((end_time - started_at) * 1000).round(3)
    end

    def extract_plan_nodes(plan_node, nodes = [], level = 0)
      return nodes unless plan_node

      nodes << {
        node_type: plan_node["Node Type"],
        relation_name: plan_node["Relation Name"],
        cost: plan_node["Total Cost"],
        actual_time: plan_node["Actual Total Time"],
        actual_rows: plan_node["Actual Rows"],
        level: level
      }

      # Recursively process child plans
      if plan_node["Plans"]
        plan_node["Plans"].each do |child_plan|
          extract_plan_nodes(child_plan, nodes, level + 1)
        end
      end

      nodes
    end
  end
end
