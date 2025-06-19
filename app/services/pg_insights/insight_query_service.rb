module PgInsights
  class InsightQueryService
    def self.all
      @all_queries ||= new.load_queries
    end

    def self.find(id)
      all.find { |q| q[:id] == id }
    end

    def load_queries
      file_path = PgInsights::Engine.root.join("config", "default_queries.yml")
      return [] unless File.exist?(file_path)

      YAML.safe_load(File.read(file_path), symbolize_names: true)
    rescue Psych::SyntaxError => e
      Rails.logger.error "[PgInsights] Failed to load default_queries.yml: #{e.message}"
      []
    end
  end
end
