class CreatePgInsightsQueryExecutions < ActiveRecord::Migration[7.0]
  def change
    create_table :pg_insights_query_executions do |t|
      t.references :query, null: true, foreign_key: { to_table: :pg_insights_queries }
      t.text :sql_text, null: false
      t.string :execution_type, null: false, default: "execute" # 'execute', 'analyze', 'both'
      t.string :status, null: false, default: "pending" # 'pending', 'running', 'completed', 'failed'

      # Execution Results
      t.json :result_data, null: true # Query results when execution_type includes 'execute'
      t.integer :result_rows_count, null: true
      t.integer :result_columns_count, null: true

      # Analysis Results
      t.json :execution_plan, null: true # EXPLAIN ANALYZE output
      t.text :plan_summary, null: true # Human-readable summary

      # Performance Metrics
      t.decimal :planning_time_ms, precision: 10, scale: 3, null: true
      t.decimal :execution_time_ms, precision: 10, scale: 3, null: true
      t.decimal :total_time_ms, precision: 10, scale: 3, null: true
      t.decimal :query_cost, precision: 15, scale: 3, null: true

      # Analysis Metadata
      t.json :performance_insights, null: true # Optimization suggestions
      t.json :execution_stats, null: true # Buffer usage, cache hits, etc.

      # Error handling
      t.text :error_message, null: true
      t.text :error_detail, null: true

      # Audit fields
      t.timestamp :started_at, null: true
      t.timestamp :completed_at, null: true
      t.decimal :duration_ms, precision: 10, scale: 3, null: true

      t.timestamps
    end

    add_index :pg_insights_query_executions, :execution_type
    add_index :pg_insights_query_executions, :status
    add_index :pg_insights_query_executions, :created_at
    add_index :pg_insights_query_executions, [ :query_id, :created_at ]
  end
end
