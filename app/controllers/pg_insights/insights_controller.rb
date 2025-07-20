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

    def query_history
      @executions = QueryExecution.recent_history(10)

      executions_data = @executions.map do |execution|
        {
          id: execution.id,
          title: execution.display_title,
          summary: execution.display_summary,
          performance_class: execution.performance_class,
          created_at: execution.created_at.strftime("%m/%d %H:%M"),
          total_time_ms: execution.total_time_ms,
          query_cost: execution.query_cost,
          sql_text: execution.sql_text
        }
      end

      respond_to do |format|
        format.json { render json: executions_data }
        format.html { redirect_to root_path }
      end
    end

            def compare
      # Handle nested parameters from form submission
      execution_ids = params[:execution_ids] || params.dig(:insight, :execution_ids)

      if execution_ids.blank? || execution_ids.size != 2
        error_response = { error: "Please select exactly 2 queries to compare" }
        respond_to do |format|
          format.json { render json: error_response, status: :bad_request }
          format.html { redirect_to root_path, alert: error_response[:error] }
        end
        return
      end

      begin
                @execution_a = QueryExecution.find(execution_ids[0])
        @execution_b = QueryExecution.find(execution_ids[1])

        # Performance logging
        Rails.logger.info "PgInsights: Comparing query executions #{@execution_a.id} vs #{@execution_b.id}"

        start_time = Time.current
        @comparison_data = generate_comparison_data(@execution_a, @execution_b)
        comparison_duration = ((Time.current - start_time) * 1000).round(2)

        Rails.logger.info "PgInsights: Comparison completed in #{comparison_duration}ms"

        respond_to do |format|
          format.json { render json: @comparison_data }
          format.html { redirect_to root_path, notice: "Comparison completed" }
        end
      rescue ActiveRecord::RecordNotFound => e
        error_response = { error: "One or both query executions not found" }
        respond_to do |format|
          format.json { render json: error_response, status: :not_found }
          format.html { redirect_to root_path, alert: error_response[:error] }
        end
      rescue => e
        Rails.logger.error "Comparison failed: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")

        error_response = { error: "Comparison failed: #{e.message}" }
        respond_to do |format|
          format.json { render json: error_response, status: :internal_server_error }
          format.html { redirect_to root_path, alert: error_response[:error] }
        end
      end
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

        def generate_comparison_data(exec_a, exec_b)
      begin
        {
          executions: {
                      a: {
            id: exec_a.id,
            title: exec_a.respond_to?(:display_title) ? exec_a.display_title : "Query ##{exec_a.id}",
            summary: exec_a.respond_to?(:display_summary) ? exec_a.display_summary : "",
            sql_text: exec_a.sql_text,
            metrics: extract_metrics(exec_a)
          },
          b: {
            id: exec_b.id,
            title: exec_b.respond_to?(:display_title) ? exec_b.display_title : "Query ##{exec_b.id}",
            summary: exec_b.respond_to?(:display_summary) ? exec_b.display_summary : "",
            sql_text: exec_b.sql_text,
            metrics: extract_metrics(exec_b)
          }
          },
          comparison: {
            performance: calculate_performance_diff(exec_a, exec_b),
            winner: determine_winner(exec_a, exec_b),
            insights: generate_insights(exec_a, exec_b)
          }
        }
      rescue => e
        Rails.logger.error "Error in generate_comparison_data: #{e.message}"
        Rails.logger.error "exec_a class: #{exec_a.class.name}, exec_b class: #{exec_b.class.name}"
        Rails.logger.error e.backtrace.join("\n")
        raise e
      end
    end

    def extract_metrics(execution)
      {
        total_time_ms: execution.total_time_ms,
        planning_time_ms: execution.planning_time_ms,
        execution_time_ms: execution.execution_time_ms,
        query_cost: execution.query_cost,
        rows_returned: execution.result_rows_count,
        rows_scanned: extract_rows_scanned(execution)
      }
    end

    def calculate_performance_diff(exec_a, exec_b)
      return {} unless exec_a.total_time_ms && exec_b.total_time_ms

      time_diff_pct = ((exec_a.total_time_ms - exec_b.total_time_ms) / exec_a.total_time_ms * 100).round(1)
      cost_diff_pct = if exec_a.query_cost && exec_b.query_cost
        ((exec_a.query_cost - exec_b.query_cost) / exec_a.query_cost * 100).round(1)
      else
        nil
      end

      {
        time_difference_pct: time_diff_pct,
        cost_difference_pct: cost_diff_pct,
        time_faster: time_diff_pct > 0 ? "b" : "a",
        cost_cheaper: cost_diff_pct && cost_diff_pct > 0 ? "b" : "a"
      }
    end

    def determine_winner(exec_a, exec_b)
      return "unknown" unless exec_a.total_time_ms && exec_b.total_time_ms
      exec_a.total_time_ms < exec_b.total_time_ms ? "a" : "b"
    end

    def generate_insights(exec_a, exec_b)
      insights = []

      if exec_a.total_time_ms && exec_b.total_time_ms
        time_diff_pct = ((exec_a.total_time_ms - exec_b.total_time_ms).abs / [ exec_a.total_time_ms, exec_b.total_time_ms ].max * 100).round(1)

        if time_diff_pct > 20
          faster_query = exec_a.total_time_ms < exec_b.total_time_ms ? "Query A" : "Query B"
          insights << "#{faster_query} is #{time_diff_pct}% faster in execution time"
        end
      end

      # Add plan structure insights
      if has_sequential_scan?(exec_a) && !has_sequential_scan?(exec_b)
        insights << "Query B uses index scans while Query A uses sequential scans"
      elsif has_sequential_scan?(exec_b) && !has_sequential_scan?(exec_a)
        insights << "Query A uses index scans while Query B uses sequential scans"
      end

      insights
    end

    def extract_rows_scanned(execution)
      return nil unless execution.execution_plan.present?

      plan = execution.execution_plan.is_a?(Array) ? execution.execution_plan[0] : execution.execution_plan
      extract_total_rows_from_plan(plan&.dig("Plan"))
    end

    def extract_total_rows_from_plan(node)
      return 0 unless node

      current_rows = node["Actual Rows"] || 0
      child_rows = 0

      if node["Plans"]&.any?
        child_rows = node["Plans"].sum { |child| extract_total_rows_from_plan(child) }
      end

      current_rows + child_rows
    end

    def has_sequential_scan?(execution)
      return false unless execution.execution_plan.present?

      plan = execution.execution_plan.is_a?(Array) ? execution.execution_plan[0] : execution.execution_plan
      check_for_seq_scan(plan&.dig("Plan"))
    end

    def check_for_seq_scan(node)
      return false unless node

      return true if node["Node Type"]&.include?("Seq Scan")

      if node["Plans"]&.any?
        return node["Plans"].any? { |child| check_for_seq_scan(child) }
      end

      false
    end
  end
end
