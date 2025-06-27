require "rails/generators/base"
require "rails/generators/migration"
require "rails/generators/active_record"

module PgInsights
  module Generators
    class InstallGenerator < Rails::Generators::Base
      include Rails::Generators::Migration

      source_root File.expand_path("../../../..", __FILE__)

      def self.next_migration_number(dirname)
        ActiveRecord::Generators::Base.next_migration_number(dirname)
      end

      def copy_migrations
        copy_queries_migration
        copy_health_check_results_migration
      end

      def mount_engine
        route_to_add = "mount PgInsights::Engine => '/pg_insights'"
        routes_file = File.join(destination_root, "config", "routes.rb")

        if File.exist?(routes_file) && File.read(routes_file).include?(route_to_add)
          say_status("skipped", "Route `#{route_to_add}` already exists in `config/routes.rb`", :yellow)
        else
          puts "Mounting PgInsights engine..."
          route route_to_add
        end
      end

      def show_readme
        puts "\nPgInsights has been successfully installed!"
        puts "Please run 'rails db:migrate' to create the necessary tables."
        puts "Then, visit '/pg_insights' in your browser to start using the dashboard."
        puts ""
        puts "To uninstall PgInsights completely, run: rails generate pg_insights:clean"
      end

      private

      def copy_queries_migration
        if migration_exists?("create_pg_insights_queries")
          say_status("skipped", "Migration 'create_pg_insights_queries' already exists", :yellow)
        else
          puts "Copying PgInsights queries migration..."
          migration_template "db/migrate/create_pg_insights_queries.rb",
                             "db/migrate/create_pg_insights_queries.rb"
        end
      end

      def copy_health_check_results_migration
        if migration_exists?("create_pg_insights_health_check_results")
          say_status("skipped", "Migration 'create_pg_insights_health_check_results' already exists", :yellow)
        else
          puts "Copying PgInsights health check results migration..."
          migration_template "db/migrate/create_pg_insights_health_check_results.rb",
                             "db/migrate/create_pg_insights_health_check_results.rb"
        end
      end

      def migration_exists?(migration_name)
        migrate_path = File.join(destination_root, "db", "migrate")
        return false unless File.directory?(migrate_path)
        Dir.glob("#{migrate_path}/*_#{migration_name}.rb").any?
      end
    end
  end
end
