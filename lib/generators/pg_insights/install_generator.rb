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

      def create_initializer
        initializer_path = File.join(destination_root, "config", "initializers", "pg_insights.rb")

        if File.exist?(initializer_path)
          say_status("skipped", "Initializer 'config/initializers/pg_insights.rb' already exists", :yellow)
        else
          puts "Creating PgInsights initializer..."
          create_file "config/initializers/pg_insights.rb", initializer_content
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
        puts ""
        puts "Next steps:"
        puts "1. Run 'rails db:migrate' to create the necessary tables"
        puts "2. Review and customize 'config/initializers/pg_insights.rb'"
        puts "3. Configure background jobs (optional, see initializer comments)"
        puts "4. Visit '/pg_insights' in your browser to start using the dashboard"
        puts ""
        puts "For background job integration, see: config/initializers/pg_insights.rb"
        puts "To check status: rails pg_insights:status"
        puts "To uninstall: rails generate pg_insights:clean"
      end

      private

      def initializer_content
        <<~RUBY
          # PgInsights Configuration
          ##{' '}
          # This file contains the configuration for PgInsights, a PostgreSQL database
          # performance monitoring and health check engine.

          PgInsights.configure do |config|
            # === Background Jobs Configuration ===
            ##{' '}
            # Enable background job processing for health checks.
            # When enabled, health checks will run asynchronously if your app has ActiveJob configured.
            # When disabled or if ActiveJob is not available, health checks run synchronously.
            #
            # Default: true
            config.enable_background_jobs = true

            # Queue name for PgInsights background jobs
            # Make sure this queue is processed by your job processor (Sidekiq, Resque, etc.)
            #
            # Default: :pg_insights_health
            config.background_job_queue = :pg_insights_health

            # === Cache and Timeout Settings ===
          #{'  '}
            # How long to cache health check results before considering them stale
            # Stale results will trigger background refresh when accessed
            #
            # Default: 5.minutes
            config.health_cache_expiry = 5.minutes

            # Timeout for individual health check queries to prevent long-running queries
            # from blocking the application
            #
            # Default: 10.seconds#{'  '}
            config.health_check_timeout = 10.seconds

            # Maximum execution time for user queries in the insights interface
            #
            # Default: 30.seconds
            config.max_query_execution_time = 30.seconds
          end

          # === Background Job Integration ===
          #
          # If you want automatic recurring health checks, add one of these to your job scheduler:
          #
          # ** Whenever (crontab) **
          # Add to config/schedule.rb:
          #   every 15.minutes do
          #     runner "PgInsights::RecurringHealthChecksJob.perform_later"
          #   end
          #
          # ** Sidekiq-Cron **
          # Add to config/initializers/sidekiq.rb:
          #   Sidekiq::Cron::Job.create(
          #     name: 'PgInsights Health Checks',
          #     cron: '*/15 * * * *',
          #     class: 'PgInsights::RecurringHealthChecksJob'
          #   )
          #
          # ** Manual Trigger **
          # You can also trigger health checks manually:
          #   PgInsights::HealthCheckService.refresh_all!
          #
          # ** Check Status **
          # To verify your configuration:
          #   rails pg_insights:status

          # === Environment-Specific Settings ===
          #
          # You may want different settings per environment:
          #
          # if Rails.env.development?
          #   PgInsights.configure do |config|
          #     config.health_cache_expiry = 1.minute  # Shorter cache in development
          #     config.enable_background_jobs = false  # Synchronous in development
          #   end
          # end
          #
          # if Rails.env.production?
          #   PgInsights.configure do |config|
          #     config.health_cache_expiry = 15.minutes  # Longer cache in production
          #     config.health_check_timeout = 30.seconds # More generous timeout
          #   end
          # end
        RUBY
      end

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
