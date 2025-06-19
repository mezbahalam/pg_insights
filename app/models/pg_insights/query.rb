module PgInsights
  class Query < ApplicationRecord
    self.table_name = "pg_insights_queries"

    validates :name, presence: true, uniqueness: { case_sensitive: false }
    validates :sql, presence: true
    validates :description, length: { maximum: 500 }
    validates :category, presence: true
  end
end
