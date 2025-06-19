module PgInsights
  class InsightQueryService
    def self.all
      @all_queries ||= new.load_queries
    end

    def self.find_by_id(id)
      all.find { |query| query["id"] == id }
    end

    def self.reload!
      @all_queries = nil
    end

    def load_queries
      file_path = Rails.root.join("db", "data", "insight_queries.json")
      return [] unless File.exist?(file_path)

      JSON.parse(File.read(file_path))["queries"]
    rescue => e
      Rails.logger.error "Failed to load insight queries: #{e.message}"
      []
    end
  end
end
