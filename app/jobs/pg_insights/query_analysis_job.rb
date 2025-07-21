# frozen_string_literal: true

module PgInsights
  class QueryAnalysisJob < ApplicationJob
    queue_as do
      PgInsights.queue_name || :default
    end

    retry_on StandardError, wait: :polynomially_longer, attempts: 3
    discard_on ActiveRecord::RecordNotFound

    def perform(execution_id, options = {})
      execution = QueryExecution.find(execution_id)

      # Skip if already completed or failed
      return execution if execution.completed? || execution.failed?

      Rails.logger.info "Starting query analysis for execution #{execution_id}"

      begin
        execution.mark_as_running!

        results = case execution.execution_type
        when "execute"
                   execute_query(execution.sql_text, options)
        when "analyze"
                   analyze_query(execution.sql_text, options)
        when "both"
                   execute_and_analyze_query(execution.sql_text, options)
        else
                   raise ArgumentError, "Invalid execution_type: #{execution.execution_type}"
        end

        execution.mark_as_completed!(results)
        Rails.logger.info "Completed query analysis for execution #{execution_id}"

        execution

      rescue => e
        Rails.logger.error "Query analysis job failed for execution #{execution_id}: #{e.message}"
        Rails.logger.error e.backtrace.join("\n") if Rails.env.development?

        execution.mark_as_failed!(e.message, e.backtrace&.first&.truncate(500))
        raise # Re-raise for job retry mechanism
      end
    end

    private

    def execute_query(sql, options)
      result = execute_with_timeout(sql, PgInsights.query_execution_timeout_ms)

      {
        result_data: serialize_result_data(result),
        result_rows_count: result.rows.count,
        result_columns_count: result.columns.count,
        total_time_ms: measure_execution_time { result }
      }
    end

    def analyze_query(sql, options)
      explain_sql = build_explain_query(sql, options)
      result = execute_with_timeout(explain_sql, PgInsights.query_analysis_timeout_ms)

      plan_data = parse_explain_output(result)
      insights = generate_performance_insights(plan_data)

      {
        execution_plan: plan_data,
        plan_summary: generate_plan_summary(plan_data),
        planning_time_ms: extract_planning_time(plan_data),
        execution_time_ms: extract_execution_time(plan_data),
        total_time_ms: calculate_total_time(plan_data),
        query_cost: extract_query_cost(plan_data),
        performance_insights: insights,
        execution_stats: extract_execution_stats(plan_data)
      }
    end

    def execute_and_analyze_query(sql, options)
      # Execute the query first
      execution_results = execute_query(sql, options)

      # Then analyze it
      analysis_results = analyze_query(sql, options)

      # Merge both sets of results
      execution_results.merge(analysis_results)
    end

    # Delegate to service methods to avoid code duplication
    def execute_with_timeout(sql, timeout_ms)
      QueryAnalysisService.send(:execute_with_timeout, sql, timeout_ms)
    end

    def build_explain_query(sql, options)
      QueryAnalysisService.send(:build_explain_query, sql, options)
    end

    def parse_explain_output(result)
      QueryAnalysisService.send(:parse_explain_output, result)
    end

    def generate_plan_summary(plan_data)
      QueryAnalysisService.send(:generate_plan_summary, plan_data)
    end

    def extract_planning_time(plan_data)
      QueryAnalysisService.send(:extract_planning_time, plan_data)
    end

    def extract_execution_time(plan_data)
      QueryAnalysisService.send(:extract_execution_time, plan_data)
    end

    def calculate_total_time(plan_data)
      QueryAnalysisService.send(:calculate_total_time, plan_data)
    end

    def extract_query_cost(plan_data)
      QueryAnalysisService.send(:extract_query_cost, plan_data)
    end

    def extract_execution_stats(plan_data)
      QueryAnalysisService.send(:extract_execution_stats, plan_data)
    end

    def generate_performance_insights(plan_data)
      QueryAnalysisService.send(:generate_performance_insights, plan_data)
    end

    def serialize_result_data(result)
      QueryAnalysisService.send(:serialize_result_data, result)
    end

    def measure_execution_time
      start_time = Time.current
      yield
      ((Time.current - start_time) * 1000).round(3)
    end
  end
end
