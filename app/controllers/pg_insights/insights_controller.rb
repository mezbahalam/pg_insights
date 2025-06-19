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
      sql = params.require(:sql)

      unless read_only?(sql)
        flash.now[:alert] = "Only single SELECT statements are allowed"
        return render :index, status: :unprocessable_entity
      end

      sql = append_limit(sql, MAX_ROWS) unless sql.match?(/limit\s+\d+/i)

      begin
        ActiveRecord::Base.connection.transaction do
          ActiveRecord::Base.connection.execute("SET LOCAL statement_timeout = #{TIMEOUT}")
          @result = ActiveRecord::Base.connection.exec_query(sql)
        end
      rescue ActiveRecord::StatementInvalid, PG::Error => e
        flash.now[:alert] = "Query Error: #{e.message}"
        return render :index, status: :unprocessable_entity
      end

      render :index
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
