module PgInsights
  module ApplicationHelper
    def render_plan_node(node, level = 0)
      return "".html_safe unless node

      # Build the node display text
      node_text = []
      node_text << "#{node['Node Type']}"
      node_text << "on #{node['Relation Name']}" if node["Relation Name"]

      # Cost information
      cost_info = []
      if node["Startup Cost"] && node["Total Cost"]
        cost_info << "cost=#{node['Startup Cost']}..#{node['Total Cost']}"
      elsif node["Total Cost"]
        cost_info << "cost=#{node['Total Cost']}"
      end

      if node["Plan Rows"]
        cost_info << "rows=#{node['Plan Rows']}"
      end

      if node["Plan Width"]
        cost_info << "width=#{node['Plan Width']}"
      end

      node_text << "(#{cost_info.join(' ')})" if cost_info.any?

      # Actual execution stats
      actual_info = []
      if node["Actual Total Time"]
        actual_info << "actual time=#{node['Actual Total Time']}ms"
      end
      if node["Actual Rows"]
        actual_info << "rows=#{node['Actual Rows']}"
      end
      if node["Actual Loops"]
        actual_info << "loops=#{node['Actual Loops']}"
      end

      node_text << "[#{actual_info.join(' ')}]" if actual_info.any?

      # Build the HTML for this node
      indent = "  " * level
      prefix = level == 0 ? "" : "├─ "

      result = content_tag(:div, class: "plan-node level-#{level}") do
        content = content_tag(:span, "#{indent}#{prefix}", class: "plan-indent")
        content += content_tag(:span, node_text.join(" "), class: "plan-node-text")

        # Add filter information if present
        if node["Filter"]
          content += content_tag(:div, class: "plan-filter") do
            content_tag(:span, "#{indent}    Filter: #{node['Filter']}", class: "filter-text")
          end
        end

        # Add index condition if present
        if node["Index Cond"]
          content += content_tag(:div, class: "plan-condition") do
            content_tag(:span, "#{indent}    Index Cond: #{node['Index Cond']}", class: "condition-text")
          end
        end

        # Add other important fields
        %w[Sort Key Hash Cond Join Filter].each do |field|
          if node[field]
            content += content_tag(:div, class: "plan-detail") do
              content_tag(:span, "#{indent}    #{field}: #{node[field]}", class: "detail-text")
            end
          end
        end

        content
      end

      # Recursively render child nodes
      if node["Plans"] && node["Plans"].any?
        node["Plans"].each do |child_plan|
          result += render_plan_node(child_plan, level + 1)
        end
      end

      result
    end

    def render_plan_node_modern(node, level = 0)
      return "".html_safe unless node

      # Get node type and determine color/icon
      node_type = node["Node Type"] || "Unknown"
      operation_class = get_operation_class(node_type)
      operation_icon = get_operation_icon(node_type)

      # Build timing info
      timing_info = []
      if node["Actual Total Time"]
        timing_info << "#{node['Actual Total Time']}ms"
      end
      if node["Actual Rows"]
        timing_info << "#{node['Actual Rows']} rows"
      end

      # Build cost info
      cost_info = node["Total Cost"] ? node["Total Cost"].round(2) : nil

      result = content_tag(:div, class: "plan-node-modern level-#{level} #{operation_class}") do
        content = ""

        # Tree connector
        if level > 0
          content += content_tag(:div, class: "tree-connector") do
            "├─".html_safe
          end
        end

        # Node card
        content += content_tag(:div, class: "node-card") do
          card_content = ""

          # Header row
          card_content += content_tag(:div, class: "node-header") do
            header_content = content_tag(:span, operation_icon, class: "node-icon")
            header_content += content_tag(:span, node_type, class: "node-type")

            if node["Relation Name"]
              header_content += content_tag(:span, "#{node['Relation Name']}", class: "relation-name")
            end

            if timing_info.any?
              header_content += content_tag(:div, timing_info.join(" • "), class: "timing-badge")
            end

            header_content
          end

          # Details row (if present)
          details = []
          if cost_info
            details << "Cost: #{cost_info}"
          end
          if node["Filter"]
            details << "Filter: #{truncate_filter(node['Filter'])}"
          end
          if node["Sort Key"]
            details << "Sort: #{node['Sort Key']}"
          end
          if node["Hash Cond"]
            details << "Join: #{truncate_filter(node['Hash Cond'])}"
          end

          if details.any?
            card_content += content_tag(:div, class: "node-details") do
              details.map { |detail| content_tag(:span, detail, class: "detail-item") }.join(" • ").html_safe
            end
          end

          card_content.html_safe
        end

        content.html_safe
      end

      # Recursively render child nodes
      if node["Plans"] && node["Plans"].any?
        node["Plans"].each do |child_plan|
          result += render_plan_node_modern(child_plan, level + 1)
        end
      end

      result
    end

    private

    def get_operation_class(node_type)
      case node_type.downcase
      when /seq scan/ then "op-seq-scan"
      when /index.*scan/ then "op-index-scan"
      when /hash/ then "op-hash"
      when /sort/ then "op-sort"
      when /aggregate/ then "op-aggregate"
      when /limit/ then "op-limit"
      when /join/ then "op-join"
      else "op-other"
      end
    end

    def get_operation_icon(node_type)
      case node_type.downcase
      when /seq scan/ then "\u{1F50D}"
      when /index.*scan/ then "\u{1F3F7}\uFE0F"
      when /hash.*join/ then "\u{1F517}"
      when /hash/ then "#\uFE0F\u20E3"
      when /sort/ then "\u2195\uFE0F"
      when /aggregate/ then "\u{1F4CA}"
      when /limit/ then "\u2702\uFE0F"
      when /join/ then "\u{1F517}"
      else "\u2699\uFE0F"
      end
    end

    def truncate_filter(text)
      return text unless text
      text.length > 50 ? "#{text[0..47]}..." : text
    end

    def get_performance_rating(total_time_ms)
      return "Unknown" unless total_time_ms

      case total_time_ms
      when 0..50
        "\u{1F680} Excellent"
      when 51..200
        "\u2705 Good"
      when 201..1000
        "\u26A0\uFE0F Fair"
      else
        "\u{1F40C} Slow"
      end
    end

    def render_plan_node_compact(node, level = 0)
      return "".html_safe unless node

      node_type = node["Node Type"] || "Unknown"
      relation = node["Relation Name"]
      timing = node["Actual Total Time"] ? "#{node['Actual Total Time']}ms" : nil
      cost = node["Total Cost"] ? node["Total Cost"].round(1) : nil
      rows = node["Actual Rows"]

      # Build compact display
      display_parts = [ node_type ]
      display_parts << relation if relation

      metrics = []
      metrics << "#{timing}" if timing
      metrics << "#{rows} rows" if rows
      metrics << "cost: #{cost}" if cost

      # Get visual styling
      node_class = get_node_visual_class(node_type)
      icon = get_node_compact_icon(node_type)

      result = content_tag(:div, class: "plan-node-compact #{node_class} level-#{level}") do
        content = ""

        # Flow connector for child nodes
        if level > 0
          content += content_tag(:div, "└─", class: "flow-connector")
        end

        # Node content
        content += content_tag(:div, class: "node-content") do
          node_content = content_tag(:div, class: "node-header") do
            header = content_tag(:span, icon, class: "node-icon")
            header += content_tag(:span, display_parts.join(" "), class: "node-title")
            header
          end

          if metrics.any?
            node_content += content_tag(:div, metrics.join(" • "), class: "node-metrics")
          end

          # Show important details compactly
          details = []
          details << "Filter: #{truncate_text(node['Filter'], 30)}" if node["Filter"]
          details << "Sort: #{node['Sort Key']}" if node["Sort Key"]
          details << "Join: #{truncate_text(node['Hash Cond'], 30)}" if node["Hash Cond"]

          if details.any?
            node_content += content_tag(:div, details.join(" | "), class: "node-details-compact")
          end

          node_content
        end

        content.html_safe
      end

      # Render children with indentation
      if node["Plans"] && node["Plans"].any?
        node["Plans"].each do |child_plan|
          result += render_plan_node_compact(child_plan, level + 1)
        end
      end

      result
    end

    def get_node_visual_class(node_type)
      case node_type.downcase
      when /seq scan/ then "node-scan-seq"
      when /index.*scan/ then "node-scan-index"
      when /hash join/ then "node-join"
      when /sort/ then "node-sort"
      when /aggregate/ then "node-aggregate"
      when /limit/ then "node-limit"
      else "node-other"
      end
    end

    def get_node_compact_icon(node_type)
      case node_type.downcase
      when /seq scan/ then "\u{1F50D}"
      when /index.*scan/ then "\u{1F3F7}\uFE0F"
      when /hash join/ then "\u{1F517}"
      when /sort/ then "\u2195\uFE0F"
      when /aggregate/ then "\u{1F4CA}"
      when /limit/ then "\u2702\uFE0F"
      else "\u2699\uFE0F"
      end
    end

    def truncate_text(text, max_length)
      return text unless text
      text.length > max_length ? "#{text[0..max_length-3]}..." : text
    end

    def timing_percentage(time, total_time)
      return 0 unless time && total_time && total_time > 0
      [ (time / total_time * 100).round, 100 ].min
    end

    def calculate_efficiency_score(execution)
      return "N/A" unless execution.query_cost && execution.result_rows_count && execution.result_rows_count > 0
      score = execution.query_cost / execution.result_rows_count
      score.round(2)
    end
  end
end
