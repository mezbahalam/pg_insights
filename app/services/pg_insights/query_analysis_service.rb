# frozen_string_literal: true

module PgInsights
  class QueryAnalysisService
    class << self
      def execute_query(sql, execution_type: "execute", options: {})
        execution = create_execution_record(sql, execution_type)

        begin
          execution.mark_as_running!

          results = case execution_type.to_s
          when "execute"
                     execute_only(sql, options)
          when "analyze"
                     analyze_only(sql, options)
          when "both"
                     execute_and_analyze(sql, options)
          else
                     raise ArgumentError, "Invalid execution_type: #{execution_type}"
          end

          execution.mark_as_completed!(results)
          execution

        rescue => e
          Rails.logger.error "Query analysis failed: #{e.message}"
          Rails.logger.error e.backtrace.join("\n") if Rails.env.development?

          execution.mark_as_failed!(e.message, e.backtrace&.first&.truncate(500))
          execution
        end
      end

      def analyze_query_async(sql, execution_type: "analyze", options: {})
        if background_jobs_available?
          execution = create_execution_record(sql, execution_type)
          QueryAnalysisJob.perform_later(execution.id, options)
          execution
        else
          # Fallback to synchronous execution
          execute_query(sql, execution_type: execution_type, options: options)
        end
      end

      private

      def create_execution_record(sql, execution_type)
        QueryExecution.create!(
          sql_text: normalize_sql(sql),
          execution_type: execution_type,
          status: "pending"
        )
      end

      def execute_only(sql, options)
        result = execute_with_timeout(sql, PgInsights.query_execution_timeout_ms)

        {
          result_data: serialize_result_data(result),
          result_rows_count: result.rows.count,
          result_columns_count: result.columns.count,
          total_time_ms: measure_execution_time { result }
        }
      end

      def analyze_only(sql, options)
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

      def execute_and_analyze(sql, options)
        # Execute the query first
        execution_results = execute_only(sql, options)

        # Then analyze it
        analysis_results = analyze_only(sql, options)

        # Merge both sets of results
        execution_results.merge(analysis_results)
      end

      def execute_with_timeout(sql, timeout_ms)
        ActiveRecord::Base.connection.transaction do
          ActiveRecord::Base.connection.execute("SET LOCAL statement_timeout = #{timeout_ms}")
          ActiveRecord::Base.connection.exec_query(sql)
        end
      end

      def build_explain_query(sql, options)
        explain_options = []
        explain_options << "ANALYZE"
        explain_options << "VERBOSE" if options[:verbose]
        explain_options << "COSTS" if options.fetch(:costs, true)
        explain_options << "SETTINGS" if options[:settings]
        explain_options << "BUFFERS" if options[:buffers]
        explain_options << "TIMING" if options.fetch(:timing, true)
        explain_options << "SUMMARY" if options.fetch(:summary, true)
        explain_options << "FORMAT JSON" # Always use JSON for parsing

        "EXPLAIN (#{explain_options.join(', ')}) #{sql}"
      end

      def parse_explain_output(result)
        return {} if result.rows.empty?

        json_string = result.rows.first.first
        JSON.parse(json_string)
      rescue JSON::ParserError => e
        Rails.logger.error "Failed to parse EXPLAIN output: #{e.message}"
        { error: "Failed to parse execution plan", raw_output: result.rows }
      end

      def generate_plan_summary(plan_data)
        return nil unless plan_data.present? && plan_data.first

        plan = plan_data.first["Plan"]
        return nil unless plan

        summary_parts = []
        summary_parts << "#{plan['Node Type']}"
        summary_parts << "on #{plan['Relation Name']}" if plan["Relation Name"]
        summary_parts << "(cost=#{plan['Total Cost']&.round(2)})" if plan["Total Cost"]
        summary_parts << "rows=#{plan['Actual Rows']}" if plan["Actual Rows"]
        summary_parts << "time=#{plan['Actual Total Time']&.round(2)}ms" if plan["Actual Total Time"]

        summary_parts.join(" ")
      end

      def extract_planning_time(plan_data)
        return nil unless plan_data.present? && plan_data.first

        plan_data.first["Planning Time"]
      end

      def extract_execution_time(plan_data)
        return nil unless plan_data.present? && plan_data.first

        plan_data.first["Execution Time"]
      end

      def calculate_total_time(plan_data)
        planning = extract_planning_time(plan_data) || 0
        execution = extract_execution_time(plan_data) || 0
        planning + execution
      end

      def extract_query_cost(plan_data)
        return nil unless plan_data.present? && plan_data.first && plan_data.first["Plan"]

        plan_data.first["Plan"]["Total Cost"]
      end

      def extract_execution_stats(plan_data)
        return {} unless plan_data.present? && plan_data.first

        stats = {}
        plan = plan_data.first["Plan"]

        if plan
          stats[:shared_hit_blocks] = plan["Shared Hit Blocks"] if plan["Shared Hit Blocks"]
          stats[:shared_read_blocks] = plan["Shared Read Blocks"] if plan["Shared Read Blocks"]
          stats[:shared_dirtied_blocks] = plan["Shared Dirtied Blocks"] if plan["Shared Dirtied_blocks"]
          stats[:local_hit_blocks] = plan["Local Hit Blocks"] if plan["Local Hit Blocks"]
          stats[:local_read_blocks] = plan["Local Read Blocks"] if plan["Local Read Blocks"]
          stats[:temp_read_blocks] = plan["Temp Read Blocks"] if plan["Temp Read Blocks"]
          stats[:temp_written_blocks] = plan["Temp Written Blocks"] if plan["Temp Written Blocks"]
        end

        stats
      end

      def generate_performance_insights(plan_data)
        return { suggestions: [], issues_detected: false } unless plan_data.present?

        insights = { suggestions: [], issues_detected: false, slow_operations: [], missing_indexes: [] }

        plan = plan_data.first&.dig("Plan")
        return insights unless plan

        # Analyze plan for performance issues
        analyze_node_performance(plan, insights)

        insights[:issues_detected] = insights[:suggestions].any? ||
                                   insights[:slow_operations].any? ||
                                   insights[:missing_indexes].any?

        insights
      end

      def analyze_node_performance(node, insights, level = 0)
        return unless node

        node_type = node["Node Type"]
        actual_time = node["Actual Total Time"]
        actual_rows = node["Actual Rows"]
        relation_name = node["Relation Name"]

        # Check for expensive sequential scans
        if node_type == "Seq Scan" && actual_rows && actual_rows > 1000
          insights[:slow_operations] << "Sequential scan on #{relation_name} (#{actual_rows} rows)"
          insights[:suggestions] << "Consider adding an index on #{relation_name} to avoid full table scan"
          insights[:missing_indexes] << relation_name if relation_name
        end

        # Check for expensive sorts
        if node_type == "Sort" && actual_time && actual_time > 100
          insights[:slow_operations] << "Expensive sort operation (#{actual_time.round(2)}ms)"
          insights[:suggestions] << "Consider adding an index to avoid sorting, or increase work_mem"
        end

        # Check for nested loop joins with high cost
        if node_type == "Nested Loop" && actual_time && actual_time > 50
          insights[:slow_operations] << "Potentially expensive nested loop join"
          insights[:suggestions] << "Consider adding indexes on join columns or using different join strategy"
        end

        # Check for hash joins that spill to disk
        if node_type == "Hash Join" && node["Temp Written Blocks"] && node["Temp Written Blocks"] > 0
          insights[:slow_operations] << "Hash join spilling to disk"
          insights[:suggestions] << "Consider increasing work_mem to avoid disk spilling"
        end

        # Recursively analyze child nodes
        if node["Plans"]
          node["Plans"].each do |child_plan|
            analyze_node_performance(child_plan, insights, level + 1)
          end
        end
      end

      def serialize_result_data(result)
        {
          columns: result.columns,
          rows: result.rows,
          column_types: result.column_types
        }
      end

      def measure_execution_time
        start_time = Time.current
        yield
        ((Time.current - start_time) * 1000).round(3)
      end

      def normalize_sql(sql)
        sql.strip.gsub(/\s+/, " ")
      end

      def background_jobs_available?
        defined?(ActiveJob) && ActiveJob::Base.queue_adapter.present?
      end
    end
  end
end
