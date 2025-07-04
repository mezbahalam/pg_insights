class CreatePgInsightsQueries < ActiveRecord::Migration[6.1]
  def change
    create_table :pg_insights_queries do |t|
      t.string :name, null: false
      t.text :sql, null: false
      t.string :description
      t.string :category, null: false, default: "saved"
      t.timestamps
    end
    add_index :pg_insights_queries, :name, unique: true
  end
end
