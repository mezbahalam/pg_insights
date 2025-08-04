module PgInsights
  module InsightsHelper
    def should_show_chart?(result)
      return false unless result&.rows&.any?
      return false if result.columns.size < 2 || result.columns.size > 4

      # Check if we have at least one numeric column
      has_numeric = result.rows.any? do |row|
        row.any? { |cell| cell.is_a?(Numeric) || (cell.is_a?(String) && cell.match?(/^\d+(\.\d+)?$/)) }
      end

      has_numeric && result.rows.size <= 50 # Limit for better chart readability
    end

    def render_chart(result)
      chart_data = prepare_chart_data(result)
      return "" unless chart_data[:chartData].present?

      # Use bar chart as default with ChartKick
      begin
        bar_chart(
          chart_data[:chartData],
          height: "350px",
          colors: [ "#00979D", "#00838a", "#00767a" ],
          responsive: true
        )
      rescue => e
        content_tag(:div,
                    "Chart data format error: #{e.message}",
                    style: "text-align: center; padding: 40px; color: #64748b;"
        )
      end
    end

    def render_stats(result)
      stats = calculate_stats(result)

      content_tag(:div) do
        content_tag(:div, class: "stats-section") do
          content_tag(:h4, "Summary Statistics") +
            content_tag(:div, class: "stats-grid") do
              stats.map do |stat|
                content_tag(:div, class: "stat-card") do
                  content_tag(:div, stat[:value], class: "stat-value") +
                    content_tag(:div, stat[:label], class: "stat-label")
                end
              end.join.html_safe
            end
        end
      end
    end

    def query_category_badge_class(category)
      "query-category-badge #{category.to_s.downcase}"
    end

    def sql_placeholder_text
      <<~SQL.strip
        -- Enter your SQL query here

        -- Example: Database table sizes (great for charts!)
        SELECT tablename,
               pg_total_relation_size(schemaname||'.'||tablename) as size_bytes
        FROM pg_tables
        WHERE schemaname = 'public'
        ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
        LIMIT 10;
      SQL
    end

    def query_example_button_data(query)
      {
        query_id: query["id"],
        category: query["category"],
        title: query["description"]
      }
    end

    def filter_buttons_data
      [
        { category: "all", label: "All", active: true },
        { category: "database", label: "Database", active: false },
        { category: "business", label: "Business", active: false },
        { category: "saved", label: "Saved", active: false }
      ]
    end

    def cell_value_class(cell)
      if cell.nil?
        "null-value"
      elsif cell.to_s.strip.empty?
        "empty-value"
      elsif cell.is_a?(Numeric) || (cell.is_a?(String) && cell.match?(/^\d+(\.\d+)?$/))
        "numeric-value"
      elsif cell.to_s.length > 50
        "long-text"
      else
        "text-value"
      end
    end

    def format_cell_value(cell)
      if cell.nil?
        "NULL"
      elsif cell.to_s.strip.empty?
        "empty"
      elsif cell.to_s.length > 100
        truncate(cell.to_s, length: 100)
      else
        cell.to_s
      end
    end

    def query_info_text
      execute_timeout = format_timeout(PgInsights.query_execution_timeout)
      analyze_timeout = format_timeout(PgInsights.query_analysis_timeout)
      "SELECT only • #{execute_timeout} exec • #{analyze_timeout} analyze • 1k row limit"
    end

    private

    def format_timeout(timeout)
      seconds = timeout.to_f
      seconds >= 1 ? "#{seconds.to_i}s" : "#{(seconds * 1000).to_i}ms"
    end

    def prepare_chart_data(result)
      return { labels: [], chartData: [] } unless result&.rows&.any?

      # For ChartKick, we need simple key-value pairs
      chart_data = result.rows.map do |row|
        label = row[0].to_s.truncate(30) # Truncate long labels
        value = parse_numeric_value(row[1])
        value ? [ label, value ] : nil
      end.compact

      {
        labels: chart_data.map(&:first),
        chartData: chart_data
      }
    rescue => e
      Rails.logger.error "Chart data preparation error: #{e.message}"
      { labels: [], chartData: [] }
    end

    def calculate_stats(result)
      return [] unless result&.rows&.any?

      stats = []

      # Basic stats
      stats << { label: "Total Records", value: number_with_delimiter(result.rows.size) }
      stats << { label: "Columns", value: result.columns.size }

      # Numeric column stats
      result.columns.each_with_index do |col, idx|
        next if idx == 0 # Skip first column (typically labels)

        numeric_values = result.rows.map { |row| parse_numeric_value(row[idx]) }.compact

        if numeric_values.any?
          stats << {
            label: "#{col} (Sum)",
            value: number_with_delimiter(numeric_values.sum.round(2))
          }
          stats << {
            label: "#{col} (Avg)",
            value: number_with_delimiter((numeric_values.sum / numeric_values.size).round(2))
          }
          stats << {
            label: "#{col} (Max)",
            value: number_with_delimiter(numeric_values.max)
          }
          stats << {
            label: "#{col} (Min)",
            value: number_with_delimiter(numeric_values.min)
          }
        end
      end

      stats
    end

    def parse_numeric_value(value)
      return nil if value.nil?
      return value if value.is_a?(Numeric)

      # Handle string numbers
      if value.is_a?(String)
        cleaned = value.to_s.gsub(/[,$\s%]/, "")
        if cleaned.match?(/^\d+$/)
          return cleaned.to_i
        elsif cleaned.match?(/^\d+\.\d+$/)
          return cleaned.to_f
        end
      end

      nil
    end

    def extract_rich_plan_metrics(execution)
      return {} unless execution.execution_plan.present?

      plan_data = execution.execution_plan.is_a?(Array) ? execution.execution_plan[0] : execution.execution_plan
      return {} unless plan_data && plan_data["Plan"]

      root_plan = plan_data["Plan"]

      {
        rows_returned: root_plan["Actual Rows"],
        rows_scanned: extract_total_rows_scanned_helper(root_plan),
        workers_planned: extract_workers_info_helper(root_plan)[:planned],
        workers_launched: extract_workers_info_helper(root_plan)[:launched],
        memory_usage_kb: extract_peak_memory_usage_helper(root_plan),
        sort_methods: extract_sort_methods_helper(root_plan),
        index_usage: extract_index_usage_helper(root_plan),
        node_count: count_plan_nodes_helper(root_plan),
        join_types: extract_join_types_helper(root_plan),
        scan_types: extract_scan_types_helper(root_plan)
      }
    end

    private

    def extract_workers_info_helper(node, workers_info = { planned: 0, launched: 0 })
      return workers_info unless node

      if node["Workers Planned"]
        workers_info[:planned] = [ workers_info[:planned], node["Workers Planned"] ].max
      end

      if node["Workers Launched"]
        workers_info[:launched] = [ workers_info[:launched], node["Workers Launched"] ].max
      end

      if node["Plans"]&.any?
        node["Plans"].each { |child| extract_workers_info_helper(child, workers_info) }
      end

      workers_info
    end

    def extract_peak_memory_usage_helper(node, max_memory = 0)
      return max_memory unless node

      if node["Peak Memory Usage"]
        max_memory = [ max_memory, node["Peak Memory Usage"] ].max
      end

      if node["Plans"]&.any?
        node["Plans"].each { |child| max_memory = extract_peak_memory_usage_helper(child, max_memory) }
      end

      max_memory
    end

    def extract_sort_methods_helper(node, methods = Set.new)
      return methods.to_a unless node

      if node["Sort Method"]
        methods.add(node["Sort Method"])
      end

      if node["Plans"]&.any?
        node["Plans"].each { |child| extract_sort_methods_helper(child, methods) }
      end

      methods.to_a
    end

    def extract_index_usage_helper(node, indexes = Set.new)
      return indexes.to_a unless node

      if node["Index Name"]
        indexes.add(node["Index Name"])
      end

      if node["Plans"]&.any?
        node["Plans"].each { |child| extract_index_usage_helper(child, indexes) }
      end

      indexes.to_a
    end

    def count_plan_nodes_helper(node)
      return 0 unless node

      count = 1
      if node["Plans"]&.any?
        count += node["Plans"].sum { |child| count_plan_nodes_helper(child) }
      end
      count
    end

    def extract_join_types_helper(node, types = Set.new)
      return types.to_a unless node

      if node["Node Type"]&.include?("Join")
        join_type = node["Join Type"] ? "#{node['Join Type']} #{node['Node Type']}" : node["Node Type"]
        types.add(join_type)
      end

      if node["Plans"]&.any?
        node["Plans"].each { |child| extract_join_types_helper(child, types) }
      end

      types.to_a
    end

    def extract_scan_types_helper(node, types = Set.new)
      return types.to_a unless node

      if node["Node Type"]&.include?("Scan")
        types.add(node["Node Type"])
      end

      if node["Plans"]&.any?
        node["Plans"].each { |child| extract_scan_types_helper(child, types) }
      end

      types.to_a
    end

    def extract_total_rows_scanned_helper(node)
      return 0 unless node

      scanned_rows = 0

      # Count rows from scan operations
      if node["Node Type"]&.include?("Scan") && node["Actual Rows"]
        scanned_rows += node["Actual Rows"] || 0
      end

      if node["Plans"]&.any?
        scanned_rows += node["Plans"].sum { |child| extract_total_rows_scanned_helper(child) }
      end

      scanned_rows
    end

    def calculate_plan_efficiency_score(plan_metrics)
      return "N/A" unless plan_metrics[:rows_returned] && plan_metrics[:rows_scanned]

      score = 100

      # Penalize based on I/O efficiency
      if plan_metrics[:rows_scanned] > 0
        io_efficiency = (plan_metrics[:rows_returned].to_f / plan_metrics[:rows_scanned]) * 100
        if io_efficiency < 20
          score -= 40
        elsif io_efficiency < 50
          score -= 20
        end
      end

      # Bonus for index usage
      score += 10 if plan_metrics[:index_usage]&.any?

      # Penalty for sequential scans on large datasets
      if plan_metrics[:scan_types]&.include?("Seq Scan") && plan_metrics[:rows_scanned] > 10000
        score -= 20
      end

      # Penalty for external sorting
      score -= 15 if plan_metrics[:sort_methods]&.include?("external merge")

      # Bonus for parallel execution
      score += 5 if plan_metrics[:workers_launched] && plan_metrics[:workers_launched] > 0

      score = [ 0, [ 100, score ].min ].max

      case score
      when 80..100 then "Excellent"
      when 60..79 then "Good"
      when 40..59 then "Fair"
      else "Poor"
      end
    end

    def render_plan_performance_issues(plan_metrics, execution)
      issues = []

      # Check for performance issues
      if execution.total_time_ms && execution.total_time_ms > 5000
        issues << "<li>Very slow execution time (>5 seconds)</li>"
      elsif execution.total_time_ms && execution.total_time_ms > 1000
        issues << "<li>Slow execution time (>1 second)</li>"
      end

      if plan_metrics[:memory_usage_kb] && plan_metrics[:memory_usage_kb] > 100000
        issues << "<li>High memory usage (>100MB)</li>"
      end

      if plan_metrics[:sort_methods]&.include?("external merge")
        issues << "<li>Sorting spilled to disk</li>"
      end

      if plan_metrics[:scan_types]&.include?("Seq Scan") && plan_metrics[:rows_scanned] && plan_metrics[:rows_scanned] > 100000
        issues << "<li>Large sequential scan detected</li>"
      end

      if plan_metrics[:workers_planned] && plan_metrics[:workers_launched] &&
         plan_metrics[:workers_planned] > plan_metrics[:workers_launched]
        issues << "<li>Worker shortage detected</li>"
      end

      if issues.empty?
        "<li>No major performance issues detected</li>"
      else
        issues.join.html_safe
      end
    end

    def render_plan_optimizations(plan_metrics, execution)
      optimizations = []

      if plan_metrics[:scan_types]&.include?("Seq Scan")
        optimizations << "<li>Consider adding indexes to eliminate sequential scans</li>"
      end

      if plan_metrics[:sort_methods]&.include?("external merge")
        optimizations << "<li>Increase work_mem to avoid disk-based sorting</li>"
      end

      if (!plan_metrics[:workers_launched] || plan_metrics[:workers_launched] == 0) &&
         execution.total_time_ms && execution.total_time_ms > 1000
        optimizations << "<li>Query could benefit from parallel execution</li>"
      end

      if (!plan_metrics[:index_usage] || plan_metrics[:index_usage].empty?) &&
         plan_metrics[:rows_scanned] && plan_metrics[:rows_scanned] > 10000
        optimizations << "<li>Add indexes to improve query performance</li>"
      end

      if plan_metrics[:join_types]&.any? && execution.total_time_ms && execution.total_time_ms > 500
        optimizations << "<li>Review join strategy and column statistics</li>"
      end

      if optimizations.empty?
        "<li>Query is well-optimized</li>"
      else
        optimizations.join.html_safe
      end
    end

    def calculate_advanced_metrics(plan_metrics)
      {
        io_efficiency: calculate_io_efficiency(plan_metrics),
        memory_efficiency: calculate_memory_efficiency(plan_metrics),
        parallelization: calculate_parallelization_score(plan_metrics),
        index_utilization: calculate_index_utilization(plan_metrics)
      }
    end

    def calculate_io_efficiency(plan_metrics)
      return "N/A" unless plan_metrics[:rows_returned] && plan_metrics[:rows_scanned] &&
                         plan_metrics[:rows_scanned] > 0

      efficiency = (plan_metrics[:rows_returned].to_f / plan_metrics[:rows_scanned]) * 100
      case efficiency
      when 80..Float::INFINITY then "Excellent"
      when 50..79 then "Good"
      when 20..49 then "Fair"
      else "Poor"
      end
    end

    def calculate_memory_efficiency(plan_metrics)
      return "N/A" unless plan_metrics[:memory_usage_kb] && plan_metrics[:rows_returned] &&
                         plan_metrics[:rows_returned] > 0

      memory_per_row = plan_metrics[:memory_usage_kb].to_f / plan_metrics[:rows_returned]
      case memory_per_row
      when 0..1 then "Excellent"
      when 1..5 then "Good"
      when 5..20 then "Fair"
      else "Poor"
      end
    end

    def calculate_parallelization_score(plan_metrics)
      return "N/A" unless plan_metrics[:workers_planned] && plan_metrics[:workers_planned] > 0

      if plan_metrics[:workers_launched].nil? || plan_metrics[:workers_launched] == 0
        return "None"
      end

      utilization = (plan_metrics[:workers_launched].to_f / plan_metrics[:workers_planned]) * 100
      case utilization
      when 90..Float::INFINITY then "Excellent"
      when 70..89 then "Good"
      when 50..69 then "Fair"
      else "Poor"
      end
    end

    def calculate_index_utilization(plan_metrics)
      return "N/A" unless plan_metrics[:scan_types]&.any?

      has_seq_scan = plan_metrics[:scan_types].include?("Seq Scan")
      index_scans = plan_metrics[:scan_types].count { |type| type.include?("Index") }

      if !has_seq_scan && index_scans > 0
        "Excellent"
      elsif index_scans > 0
        "Good"
      elsif has_seq_scan
        "Poor"
      else
        "N/A"
      end
    end

    def score_css_class(score)
      case score.to_s.downcase
      when "excellent"
        "score-excellent"
      when "good"
        "score-good"
      when "fair"
        "score-fair"
      when "poor"
        "score-poor"
      when "none"
        "score-none"
      else
        ""
      end
    end

    # Enhanced performance analysis helper methods
    def calculate_overall_performance_score(execution)
      return 75 unless execution.total_time_ms && execution.query_cost

      score = 100

      # Time penalty
      if execution.total_time_ms > 10000
        score -= 40
      elsif execution.total_time_ms > 5000
        score -= 25
      elsif execution.total_time_ms > 1000
        score -= 15
      elsif execution.total_time_ms > 500
        score -= 8
      end

      # Cost penalty
      if execution.query_cost > 1000000
        score -= 20
      elsif execution.query_cost > 100000
        score -= 10
      end

      # Plan metrics bonus/penalty
      if execution.execution_plan.present?
        plan_metrics = extract_rich_plan_metrics(execution)
        score += 5 if plan_metrics[:index_usage]&.any?
        score += 5 if plan_metrics[:workers_launched] && plan_metrics[:workers_launched] > 0
        score -= 10 if plan_metrics[:sort_methods]&.include?("external merge")
      end

      [ 0, [ 100, score ].min ].max
    end

    def planning_vs_execution_insight(planning_ms, execution_ms)
      return "" unless planning_ms && execution_ms && execution_ms > 0

      ratio = planning_ms / execution_ms.to_f

      if ratio > 0.5
        "High planning overhead"
      elsif ratio > 0.2
        "Moderate planning cost"
      elsif ratio < 0.05
        "Efficient planning"
      else
        "Balanced timing"
      end
    end

    def performance_benchmark_text(total_time_ms)
      return "" unless total_time_ms

      case total_time_ms
      when 0..100
        "Excellent"
      when 101..500
        "Good"
      when 501..2000
        "Acceptable"
      when 2001..10000
        "Slow"
      else
        "Very Slow"
      end
    end

    def cost_threshold_indicator(cost)
      return "" unless cost

      case cost
      when 0..1000
        "\u2713 Low"
      when 1001..10000
        "\u26A0 Medium"
      when 10001..100000
        "\u26A0 High"
      else
        "\u26A0 Very High"
      end
    end

    def memory_threshold_indicator(memory_kb)
      return "" unless memory_kb

      case memory_kb
      when 0..10000
        "\u2713 Low"
      when 10001..50000
        "\u26A0 Medium"
      when 50001..200000
        "\u26A0 High"
      else
        "\u26A0 Very High"
      end
    end

    def format_memory_size(kb)
      return "N/A" unless kb

      if kb >= 1024 * 1024
        "#{(kb / (1024.0 * 1024)).round(1)} GB"
      elsif kb >= 1024
        "#{(kb / 1024.0).round(1)} MB"
      else
        "#{number_with_delimiter(kb)} KB"
      end
    end

    def io_efficiency_impact(plan_metrics)
      return "N/A" unless plan_metrics[:rows_returned] && plan_metrics[:rows_scanned]

      ratio = plan_metrics[:rows_returned].to_f / plan_metrics[:rows_scanned]

      case ratio
      when 0.8..1.0
        "Excellent selectivity"
      when 0.5..0.79
        "Good filtering"
      when 0.1..0.49
        "Moderate waste"
      else
        "Poor selectivity"
      end
    end

    def memory_efficiency_impact(plan_metrics)
      return "N/A" unless plan_metrics[:memory_usage_kb] && plan_metrics[:rows_returned]

      memory_per_row = plan_metrics[:memory_usage_kb].to_f / plan_metrics[:rows_returned]

      case memory_per_row
      when 0..1
        "Very efficient"
      when 1..10
        "Reasonable usage"
      when 10..100
        "High consumption"
      else
        "Memory intensive"
      end
    end

    def parallelization_impact(plan_metrics)
      return "N/A" unless plan_metrics[:workers_planned]

      if plan_metrics[:workers_launched] == 0
        "No parallelization"
      elsif plan_metrics[:workers_launched] == plan_metrics[:workers_planned]
        "Full utilization"
      else
        "Partial utilization"
      end
    end

    def index_usage_impact(plan_metrics)
      return "N/A" unless plan_metrics[:scan_types]&.any?

      has_seq_scan = plan_metrics[:scan_types].include?("Seq Scan")
      has_index_scan = plan_metrics[:scan_types].any? { |type| type.include?("Index") }

      if has_index_scan && !has_seq_scan
        "Optimal access"
      elsif has_index_scan && has_seq_scan
        "Mixed access pattern"
      elsif has_seq_scan
        "Sequential scans"
      else
        "Unknown pattern"
      end
    end

    def recommendation_priority_class(suggestion, index)
      priority = recommendation_priority_level(suggestion, index)
      "priority-#{priority.downcase}"
    end

    def recommendation_priority_text(suggestion, index)
      recommendation_priority_level(suggestion, index)
    end

    def recommendation_priority_level(suggestion, index)
      text = suggestion.downcase

      if text.include?("index") && (text.include?("avoid") || text.include?("eliminate"))
        "HIGH"
      elsif text.include?("work_mem") || text.include?("memory")
        "MEDIUM"
      elsif index == 0
        "HIGH"
      elsif index <= 2
        "MEDIUM"
      else
        "LOW"
      end
    end

    def recommendation_impact_estimate(suggestion)
      text = suggestion.downcase

      if text.include?("index") && text.include?("avoid")
        "~50-80% faster"
      elsif text.include?("work_mem")
        "~20-40% improvement"
      elsif text.include?("parallel")
        "~30-60% faster"
      else
        "Performance gain"
      end
    end

    def recommendation_hint(suggestion)
      text = suggestion.downcase

      if text.include?("index") && text.include?("order_items")
        "CREATE INDEX ON order_items(...)"
      elsif text.include?("work_mem")
        "SET work_mem = '256MB'"
      elsif text.include?("parallel")
        "Adjust max_parallel_workers"
      else
        "See PostgreSQL docs"
      end
    end
  end
end
