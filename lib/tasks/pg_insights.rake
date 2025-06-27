namespace :pg_insights do
  desc "Show PgInsights configuration and background job status"
  task status: :environment do
    puts "PgInsights Configuration Status"
    puts "==============================="

    status = PgInsights::Integration.status

    puts "Background Jobs: #{status[:background_jobs_available] ? '✅ Available' : '❌ Not Available'}"
    puts "Queue Adapter: #{status[:queue_adapter]}"
    puts "Queue Name: #{status[:configuration][:background_job_queue]}"
    puts "Cache Expiry: #{status[:configuration][:health_cache_expiry]}"
    puts "Enabled: #{status[:configuration][:enable_background_jobs] ? 'Yes' : 'No'}"

    if defined?(PgInsights::RecurringHealthChecksJob)
      puts "\nRecurring Job Status:"
      validation = PgInsights::RecurringHealthChecksJob.validate_setup
      if validation[:valid]
        puts "✅ #{validation[:message]}"
      else
        puts "❌ Issues found:"
        validation[:issues].each { |issue| puts "   - #{issue}" }
      end
    end

    puts "\nIntegration Help:"
    if status[:background_jobs_available]
      puts "✅ Your application is ready for PgInsights background jobs!"
      puts "   Add this to your job scheduler (whenever, sidekiq-cron, etc.):"
      puts "   PgInsights::RecurringHealthChecksJob.perform_later"
    else
      puts "ℹ️  Background jobs are not configured. PgInsights will work in synchronous mode."
      puts "   To enable background processing:"
      puts "   1. Configure ActiveJob in your Rails application"
      puts "   2. Set up a job queue backend (Sidekiq, Resque, etc.)"
      puts "   3. Add to config/initializers/pg_insights.rb:"
      puts "      PgInsights.configure { |c| c.enable_background_jobs = true }"
    end
  end

  desc "Test background job functionality"
  task test_jobs: :environment do
    puts "Testing PgInsights Background Jobs"
    puts "=================================="

    test_result = PgInsights::Integration.test_background_jobs

    if test_result[:success]
      puts "✅ #{test_result[:message]}"

      # Try scheduling a real health check
      if defined?(PgInsights::HealthCheckJob)
        if PgInsights::HealthCheckJob.perform_check("parameter_settings")
          puts "✅ Successfully enqueued a test health check"
        else
          puts "❌ Failed to enqueue test health check"
        end
      end
    else
      puts "❌ #{test_result[:error]}"
    end
  end

  desc "Run health checks synchronously (without background jobs)"
  task health_check: :environment do
    puts "Running PgInsights Health Checks (Synchronous)"
    puts "=============================================="

    start_time = Time.current

    begin
      PgInsights::HealthCheckService.execute_all_checks_synchronously
      execution_time = Time.current - start_time

      puts "✅ Health checks completed in #{execution_time.round(2)} seconds"
      puts "Visit /pg_insights/health in your browser to see the results"
    rescue => e
      puts "❌ Health checks failed: #{e.message}"
    end
  end

  desc "Clean up all PgInsights data and migrations"
  task clean: :environment do
    puts "Cleaning up PgInsights data..."

    # Remove data from database
    begin
      if defined?(PgInsights::Query)
        query_count = PgInsights::Query.count
        PgInsights::Query.destroy_all
        puts "Removed #{query_count} PgInsights queries"
      end
    rescue => e
      puts "Could not remove queries: #{e.message}"
    end

    begin
      if defined?(PgInsights::HealthCheckResult)
        result_count = PgInsights::HealthCheckResult.count
        PgInsights::HealthCheckResult.destroy_all
        puts "Removed #{result_count} PgInsights health check results"
      end
    rescue => e
      puts "Could not remove health check results: #{e.message}"
    end

    puts "PgInsights data cleanup completed!"
    puts "To remove migrations and routes, run: rails generate pg_insights:clean"
  end

  desc "Reset PgInsights data (clears all stored queries and health check results)"
  task reset: :environment do
    puts "Resetting PgInsights data..."

    begin
      if defined?(PgInsights::Query)
        PgInsights::Query.destroy_all
        puts "Cleared all PgInsights queries"
      end
    rescue => e
      puts "Could not clear queries: #{e.message}"
    end

    begin
      if defined?(PgInsights::HealthCheckResult)
        PgInsights::HealthCheckResult.destroy_all
        puts "Cleared all PgInsights health check results"
      end
    rescue => e
      puts "Could not clear health check results: #{e.message}"
    end

    puts "PgInsights data reset completed!"
  end

  desc "Show PgInsights statistics"
  task stats: :environment do
    puts "PgInsights Statistics:"
    puts "====================="

    begin
      if defined?(PgInsights::Query)
        query_count = PgInsights::Query.count
        puts "Stored queries: #{query_count}"
      end
    rescue => e
      puts "Queries table not available: #{e.message}"
    end

    begin
      if defined?(PgInsights::HealthCheckResult)
        result_count = PgInsights::HealthCheckResult.count
        recent_results = PgInsights::HealthCheckResult.where("executed_at > ?", 24.hours.ago).count
        puts "Health check results: #{result_count}"
        puts "Recent results (24h): #{recent_results}"

        # Show results by type
        PgInsights::HealthCheckResult::VALID_CHECK_TYPES.each do |check_type|
          latest = PgInsights::HealthCheckResult.latest_for_type(check_type)
          if latest
            freshness = latest.fresh? ? "fresh" : "stale"
            puts "  #{check_type}: #{latest.status} (#{freshness})"
          else
            puts "  #{check_type}: no data"
          end
        end
      end
    rescue => e
      puts "Health check results table not available: #{e.message}"
    end
  end
end
