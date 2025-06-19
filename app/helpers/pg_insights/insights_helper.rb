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
        { category: "sample", label: "Sample", active: false }
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

    private

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
  end
end
