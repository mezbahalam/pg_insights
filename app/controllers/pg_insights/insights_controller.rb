# frozen_string_literal: true

module PgInsights
  class InsightsController < PgInsights::ApplicationController
    layout "pg_insights/application"
    protect_from_forgery with: :exception

    MAX_ROWS = 1_000
    TIMEOUT = 5_000

    # GET /pg_insights
    # POST /pg_insights
    def index
      # Combine built-in and user-saved queries for the UI
      built_in_queries = PgInsights::InsightQueryService.all

      saved_queries = PgInsights::Query.order(updated_at: :desc).map do |q|
        {
          id: q.id,
          name: q.name,
          sql: q.sql,
          description: q.description,
          category: q.category || "saved"
        }
      end

      @insight_queries = built_in_queries + saved_queries

      return unless request.post?

      # Determine execution type from button clicked
      execution_type = determine_execution_type
      sql = params.require(:sql)

      unless read_only?(sql)
        flash.now[:alert] = "Only single SELECT statements are allowed"
        return render :index, status: :unprocessable_entity
      end

      # Handle different execution types
      case execution_type
      when "execute"
        handle_execute_only(sql)
      when "analyze"
        handle_analyze_only(sql)
      when "both"
        handle_execute_and_analyze(sql)
      else
        # Fallback to original behavior for backward compatibility
        handle_execute_only(sql)
      end

      render :index
    end

    # POST /pg_insights/analyze
    def analyze
      sql = params.require(:sql)
      execution_type = params.fetch(:execution_type, "analyze")
      async = params.fetch(:async, false)

      unless read_only?(sql)
        render json: { error: "Only single SELECT statements are allowed" }, status: :unprocessable_entity
        return
      end

      begin
        if async.to_s == "true"
          execution = QueryAnalysisService.analyze_query_async(sql, execution_type: execution_type)
          render json: {
            execution_id: execution.id,
            status: execution.status,
            message: "Analysis started"
          }
        else
          execution = QueryAnalysisService.execute_query(sql, execution_type: execution_type)
          render json: format_execution_response(execution)
        end
      rescue => e
        Rails.logger.error "Analysis failed: #{e.message}"
        render json: { error: e.message }, status: :internal_server_error
      end
    end

    # GET /pg_insights/execution/:id
    def execution_status
      execution = QueryExecution.find(params[:id])
      render json: format_execution_response(execution)
    rescue ActiveRecord::RecordNotFound
      render json: { error: "Execution not found" }, status: :not_found
    end

    # GET /pg_insights/table_names
    def table_names
      tables = ActiveRecord::Base.connection.exec_query(
        "SELECT tablename FROM pg_tables WHERE schemaname = 'public' ORDER BY tablename"
      )
      render json: { tables: tables.rows.map(&:first) }
    rescue ActiveRecord::StatementInvalid, PG::Error => e
      Rails.logger.error "Failed to fetch table names: #{e.message}"
      render json: { tables: [] }
    end

    private

    def determine_execution_type
      return "analyze" if params[:analyze_button].present?
      return "both" if params[:both_button].present?
      "execute" # Default
    end

    def handle_execute_only(sql)
      sql = append_limit(sql, MAX_ROWS) unless sql.match?(/limit\s+\d+/i)

      begin
        ActiveRecord::Base.connection.transaction do
          ActiveRecord::Base.connection.execute("SET LOCAL statement_timeout = #{TIMEOUT}")
          @result = ActiveRecord::Base.connection.exec_query(sql)
        end
        @execution_type = "execute"
      rescue ActiveRecord::StatementInvalid, PG::Error => e
        flash.now[:alert] = "Query Error: #{e.message}"
        nil
      end
    end

    def handle_analyze_only(sql)
      begin
        @query_execution = QueryAnalysisService.execute_query(sql, execution_type: "analyze")
        @execution_type = "analyze"
      rescue => e
        flash.now[:alert] = "Analysis Error: #{e.message}"
        nil
      end
    end

    def handle_execute_and_analyze(sql)
      sql = append_limit(sql, MAX_ROWS) unless sql.match?(/limit\s+\d+/i)

      begin
        @query_execution = QueryAnalysisService.execute_query(sql, execution_type: "both")
        @execution_type = "both"

        # Extract regular result for backward compatibility
        if @query_execution.success? && @query_execution.result_data
          result_data = @query_execution.result_data
          @result = ActiveRecord::Result.new(
            result_data["columns"],
            result_data["rows"],
            result_data["column_types"] || {}
          )
        end
      rescue => e
        flash.now[:alert] = "Error: #{e.message}"
        nil
      end
    end

    def format_execution_response(execution)
      response = {
        id: execution.id,
        status: execution.status,
        execution_type: execution.execution_type
      }

      if execution.success?
        if execution.has_result_data?
          response[:result] = {
            rows: execution.result_data["rows"],
            columns: execution.result_data["columns"],
            summary: execution.result_summary
          }
        end

        if execution.has_plan_data?
          response[:analysis] = {
            execution_plan: execution.execution_plan,
            plan_summary: execution.plan_summary,
            performance_insights: execution.performance_insights,
            timing: {
              planning_time_ms: execution.planning_time_ms,
              execution_time_ms: execution.execution_time_ms,
              total_time_ms: execution.total_time_ms
            },
            cost: execution.query_cost,
            stats: execution.execution_stats
          }
        end
      elsif execution.failed?
        response[:error] = execution.error_message
      end

      response
    end

    def read_only?(sql)
      sql.strip!
      # Check for a single SELECT statement
      sql.downcase.start_with?("select") &&
        !sql.include?(";") &&
        !sql.match?(/\b(insert|update|delete|alter|drop|create|grant|revoke)\b/i)
    end

    def append_limit(sql, n)
      "#{sql.strip} LIMIT #{n}"
    end
  end
end
