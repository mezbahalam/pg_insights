require "rails/generators/base"
require "rails/generators/migration"
require "rails/generators/active_record"

module PgInsights
  module Generators
    class InstallGenerator < Rails::Generators::Base
      include Rails::Generators::Migration

      source_root File.expand_path("../../../..", __FILE__) # Set source to gem root

      # Implement the required method for Rails::Generators::Migration
      def self.next_migration_number(dirname)
        ActiveRecord::Generators::Base.next_migration_number(dirname)
      end

      def copy_migrations
        if migration_already_exists?
          say_status("skipped", "Migration 'create_pg_insights_queries' already exists", :yellow)
        else
          puts "Copying PgInsights migration..."
          migration_template "db/migrate/create_pg_insights_queries.rb",
                             "db/migrate/create_pg_insights_queries.rb"
        end
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
        puts "Please run 'rails db:migrate' to create the necessary table."
        puts "Then, visit '/pg_insights' in your browser to start using the dashboard."
      end

      private

      def migration_already_exists?
        migrate_path = File.join(destination_root, "db", "migrate")
        # Check if any file in the migrate path ends with our migration name
        return false unless File.directory?(migrate_path)
        Dir.glob("#{migrate_path}/*_create_pg_insights_queries.rb").any?
      end
    end
  end
end
