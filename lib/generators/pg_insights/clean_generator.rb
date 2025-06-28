require "rails/generators/base"

module PgInsights
  module Generators
    class CleanGenerator < Rails::Generators::Base
      source_root File.expand_path("../../../..", __FILE__)

      def remove_routes
        routes_file = File.join(destination_root, "config", "routes.rb")
        route_to_remove = "mount PgInsights::Engine => '/pg_insights'"

        if File.exist?(routes_file)
          routes_content = File.read(routes_file)
          if routes_content.include?(route_to_remove)
            puts "Removing PgInsights engine mount from routes..."
            updated_content = routes_content.gsub(/^\s*#{Regexp.escape(route_to_remove)}\s*\n?/, "")
            File.write(routes_file, updated_content)
            say_status("removed", "PgInsights engine mount from config/routes.rb", :green)
          else
            say_status("skipped", "PgInsights engine mount not found in config/routes.rb", :yellow)
          end
        end
      end

      def remove_initializer
        initializer_path = "config/initializers/pg_insights.rb"
        initializer_full_path = File.join(destination_root, initializer_path)

        if File.exist?(initializer_full_path)
          puts "Removing PgInsights initializer..."
          remove_file initializer_path
          say_status("removed", initializer_path, :green)
        else
          say_status("skipped", "#{initializer_path} not found", :yellow)
        end
      end

      def show_migration_rollback_instructions
        puts "\nPgInsights has been cleaned up!"
        puts ""
        puts "To complete the uninstallation, you may also want to:"
        puts "1. Roll back the migrations:"

        migration_files = find_pg_insights_migrations
        if migration_files.any?
          puts "   rails db:rollback STEP=#{migration_files.count}"
          puts ""
          puts "2. Or manually remove the migration files:"
          migration_files.each do |file|
            puts "   rm #{file}"
          end
        else
          puts "   (No PgInsights migrations found)"
        end

        puts ""
        puts "3. Remove any PgInsights data from your database:"
        puts "   rails runner 'PgInsights::Query.destroy_all'"
        puts "   rails runner 'PgInsights::HealthCheckResult.destroy_all'"
        puts ""
        puts "4. If you want to reinstall later, run: rails generate pg_insights:install"
      end

      private

      def find_pg_insights_migrations
        migrate_path = File.join(destination_root, "db", "migrate")
        return [] unless File.directory?(migrate_path)

        Dir.glob("#{migrate_path}/*_create_pg_insights_*.rb").sort
      end
    end
  end
end
