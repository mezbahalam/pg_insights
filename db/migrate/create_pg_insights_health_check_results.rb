class CreatePgInsightsHealthCheckResults < ActiveRecord::Migration[7.0]
  def change
    create_table :pg_insights_health_check_results do |t|
      t.string :check_type, null: false, limit: 50
      t.json :result_data
      t.string :status, null: false, default: 'pending', limit: 20
      t.text :error_message
      t.datetime :executed_at
      t.integer :execution_time_ms
      t.timestamps

      t.index [ :check_type, :executed_at ], name: 'idx_pg_insights_health_check_type_executed_at'
      t.index [ :status, :executed_at ], name: 'idx_pg_insights_health_status_executed_at'
    end
  end
end
