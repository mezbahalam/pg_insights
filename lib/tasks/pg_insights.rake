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

  desc "Reset all PgInsights data (clears stored queries and health check results)"
  task reset: :environment do
    puts "Resetting PgInsights data..."

    begin
      if defined?(PgInsights::Query)
        query_count = PgInsights::Query.count
        PgInsights::Query.destroy_all
        puts "Cleared #{query_count} stored queries"
      end
    rescue => e
      puts "Could not clear queries: #{e.message}"
    end

    begin
      if defined?(PgInsights::HealthCheckResult)
        result_count = PgInsights::HealthCheckResult.count
        PgInsights::HealthCheckResult.destroy_all
        puts "Cleared #{result_count} health check results"
      end
    rescue => e
      puts "Could not clear health check results: #{e.message}"
    end

    puts "✅ PgInsights data reset completed!"
    puts "To completely uninstall PgInsights (remove migrations and routes), run: rails generate pg_insights:clean"
  end

  # Alias for backward compatibility
  task clear_data: :reset

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

  desc "Collect a database snapshot immediately"
  task collect_snapshot: :environment do
    puts "Collecting Database Snapshot"
    puts "==========================="

    unless PgInsights.snapshots_available?
      puts "❌ Snapshots are not enabled"
      puts "   Add to config/initializers/pg_insights.rb:"
      puts "   PgInsights.configure { |c| c.enable_snapshots = true }"
      exit 1
    end

    start_time = Time.current

    begin
      PgInsights::HealthCheckService.execute_and_cache_check("database_snapshot")
      execution_time = Time.current - start_time

      puts "✅ Snapshot collected successfully in #{execution_time.round(2)} seconds"

      latest = PgInsights::HealthCheckResult.latest_snapshot
      if latest
        puts "   Snapshot ID: #{latest.id}"
        puts "   Collected at: #{latest.executed_at}"
        puts "   Parameters tracked: #{latest.result_data['parameters']&.keys&.count || 0}"
        puts "   Metrics collected: #{latest.result_data['metrics']&.keys&.count || 0}"
      end

      puts "Visit /pg_insights/timeline to view the snapshot in the timeline"
    rescue => e
      puts "❌ Snapshot collection failed: #{e.message}"
      exit 1
    end
  end

  desc "Start recurring snapshot collection"
  task start_snapshots: :environment do
    puts "Starting Recurring Database Snapshots"
    puts "====================================="

    unless PgInsights.snapshots_available?
      puts "❌ Snapshots are not enabled"
      exit 1
    end

    unless PgInsights.background_jobs_available?
      puts "❌ Background jobs are not available"
      puts "   PgInsights needs ActiveJob to schedule recurring snapshots"
      exit 1
    end

    validation = PgInsights::DatabaseSnapshotJob.validate_configuration
    unless validation[:valid]
      puts "❌ Configuration issues found:"
      validation[:issues].each { |issue| puts "   - #{issue}" }
      exit 1
    end

    begin
      if PgInsights::DatabaseSnapshotJob.start_recurring_snapshots
        puts "✅ Recurring snapshots started successfully"
        puts "   Frequency: #{PgInsights.snapshot_frequency}"
        puts "   Queue: #{PgInsights.background_job_queue}"
        puts "   Retention: #{PgInsights.snapshot_retention_days} days"
        puts ""
        puts "Snapshots will be collected automatically based on the configured frequency."
        puts "Visit /pg_insights/timeline to monitor collection progress."
      else
        puts "❌ Failed to start recurring snapshots"
      end
    rescue => e
      puts "❌ Error starting snapshots: #{e.message}"
      exit 1
    end
  end

  desc "Show snapshot configuration and status"
  task snapshot_status: :environment do
    puts "Database Snapshot Status"
    puts "======================="

    # Configuration
    puts "Configuration:"
    puts "  Enabled: #{PgInsights.enable_snapshots ? 'Yes' : 'No'}"
    puts "  Collection Enabled: #{PgInsights.snapshot_collection_enabled ? 'Yes' : 'No'}"
    puts "  Frequency: #{PgInsights.snapshot_frequency}"
    puts "  Retention: #{PgInsights.snapshot_retention_days} days"
    puts ""

    # Availability check
    if PgInsights.snapshots_available?
      puts "✅ Snapshots are available"
    else
      puts "❌ Snapshots are not available"
      return
    end

    # Database stats
    begin
      if defined?(PgInsights::HealthCheckResult)
        snapshot_count = PgInsights::HealthCheckResult.snapshots.count
        puts "Statistics:"
        puts "  Total snapshots: #{snapshot_count}"

        latest = PgInsights::HealthCheckResult.latest_snapshot
        if latest
          puts "  Latest snapshot: #{latest.executed_at}"
          puts "  Latest status: #{latest.status}"
        else
          puts "  Latest snapshot: None"
        end

        # Recent snapshots
        recent = PgInsights::HealthCheckResult.snapshots.limit(5)
        if recent.any?
          puts ""
          puts "Recent snapshots:"
          recent.each do |snapshot|
            puts "  #{snapshot.executed_at.strftime('%Y-%m-%d %H:%M')} - #{snapshot.status}"
          end
        end

        # Parameter changes
        changes = PgInsights::HealthCheckResult.detect_parameter_changes_since(7)
        puts ""
        puts "Parameter changes (last 7 days): #{changes.count}"
        if changes.any?
          changes.first(3).each do |change_event|
            puts "  #{change_event[:detected_at].strftime('%Y-%m-%d %H:%M')} - #{change_event[:changes].keys.join(', ')}"
          end
        end
      end
    rescue => e
      puts "Could not retrieve snapshot statistics: #{e.message}"
    end

    # Background job validation
    puts ""
    validation = PgInsights::DatabaseSnapshotJob.validate_configuration
    if validation[:valid]
      puts "✅ #{validation[:message]}"
    else
      puts "❌ Configuration issues:"
      validation[:issues].each { |issue| puts "   - #{issue}" }
    end

    puts ""
    puts "Commands:"
    puts "  Collect snapshot now: rails pg_insights:collect_snapshot"
    puts "  Start recurring:      rails pg_insights:start_snapshots"
    puts "  Change frequency:     Set PgInsights.snapshot_frequency in initializer"
  end

  desc "Clean up old snapshots"
  task cleanup_snapshots: :environment do
    puts "Cleaning up old snapshots..."

    begin
      deleted_count = PgInsights::HealthCheckResult.cleanup_old_snapshots
      puts "✅ Cleaned up #{deleted_count} old snapshots"
      puts "   Retention period: #{PgInsights.snapshot_retention_days} days"
    rescue => e
      puts "❌ Cleanup failed: #{e.message}"
    end
  end

  desc "Clean up old health check results (keeps recent results, removes old ones)"
  task cleanup: :environment do
    puts "🧹 Cleaning up old PgInsights health check results..."

    # Keep results from last 30 days by default
    retention_days = 30
    cutoff_date = retention_days.days.ago

    begin
      deleted_count = PgInsights::HealthCheckResult.where("executed_at < ?", cutoff_date).delete_all
      puts "✅ Cleaned up #{deleted_count} old health check results (older than #{retention_days} days)"
    rescue => e
      puts "❌ Cleanup failed: #{e.message}"
    end
  end



  desc "Generate fake timeline data for testing (90 days)"
  task seed_timeline: :environment do
    puts "Generating fake timeline data for testing..."

    end_date = Date.current
    start_date = end_date - 90.days

    puts "📅 Generating data from #{start_date.strftime('%B %d, %Y')} to #{end_date.strftime('%B %d, %Y')}"

    PgInsights::HealthCheckResult.where(check_type: "database_snapshot").delete_all
    puts "🗑️  Cleared existing timeline data"

    base_config = {
      "shared_buffers" => "256MB",
      "work_mem" => "4MB",
      "max_connections" => "100",
      "effective_cache_size" => "1GB",
      "checkpoint_completion_target" => "0.9",
      "wal_buffers" => "16MB",
      "default_statistics_target" => "100",
      "random_page_cost" => "4.0",
      "effective_io_concurrency" => "1",
      "maintenance_work_mem" => "64MB"
    }

    config_changes = [
      { date: start_date + 15.days, changes: { "shared_buffers" => "512MB", "effective_cache_size" => "2GB" } },
      { date: start_date + 30.days, changes: { "work_mem" => "8MB", "max_connections" => "150" } },
      { date: start_date + 45.days, changes: { "checkpoint_completion_target" => "0.7" } },
      { date: start_date + 60.days, changes: { "shared_buffers" => "1GB", "maintenance_work_mem" => "128MB" } },
      { date: start_date + 75.days, changes: { "work_mem" => "6MB", "default_statistics_target" => "150" } }
    ]

    current_config = base_config.dup

    (start_date..end_date).each_with_index do |date, index|
      config_changes.each do |change|
        if date >= change[:date] && date < change[:date] + 1.day
          current_config.merge!(change[:changes])
          puts "⚙️  Config change on #{date.strftime('%m/%d/%Y')}: #{change[:changes].keys.join(', ')}"
        end
      end

      snapshots_per_day = rand(1..3)

      snapshots_per_day.times do |snapshot_index|
        hour = case snapshot_index
        when 0 then rand(6..10)
        when 1 then rand(11..15)
        when 2 then rand(16..22)
        end
        minute = rand(0..59)

        timestamp = date.beginning_of_day + hour.hours + minute.minutes

        base_cache_hit_rate = 92.0 + Math.sin(index * 0.1) * 5 + rand(-2.0..2.0)
        base_cache_hit_rate = [ [ base_cache_hit_rate, 75.0 ].max, 99.5 ].min

        base_query_time = 15.0 + Math.sin(index * 0.05) * 10 + rand(-5.0..5.0)
        base_query_time = [ base_query_time, 1.0 ].max

        base_connections = 25 + Math.sin(index * 0.08) * 15 + rand(-5..5)
        base_connections = [ [ base_connections, 5 ].max, 200 ].min

        if rand(100) < 5
          base_cache_hit_rate *= 0.8
          base_query_time *= 2.5
          base_connections = [ base_connections * 1.5, 300 ].min
        end

        metrics = {
          "cache_hit_rate" => base_cache_hit_rate.round(2),
          "avg_query_time" => base_query_time.round(2),
          "total_connections" => base_connections.to_i,
          "bloated_tables" => rand(0..8),
          "unused_indexes" => rand(0..12),
          "missing_indexes" => rand(0..5),
          "slow_queries_count" => rand(0..25),
          "dead_tuples_percent" => rand(0.0..5.0).round(2),
          "index_usage_ratio" => (85.0 + rand(-10.0..10.0)).round(2),
          "checkpoint_frequency" => rand(30..300),
          "wal_size_mb" => rand(50..500),
          "temp_files_count" => rand(0..50),
          "lock_waits_count" => rand(0..10)
        }

        extensions = [ "pg_stat_statements", "uuid-ossp", "hstore", "postgis", "pg_trgm" ]
        selected_extensions = extensions.sample(rand(3..5))

        metadata = {
          "postgresql_version" => "15.4",
          "database_size" => "#{rand(500..2000)}MB",
          "table_count" => rand(50..200),
          "index_count" => rand(100..400),
          "extensions" => selected_extensions,
          "uptime_hours" => rand(100..8760),
          "max_wal_size" => "1GB",
          "archive_mode" => "on",
          "log_statement" => "none",
          "timezone" => "UTC"
        }

        result_data = {
          "metrics" => metrics,
          "parameters" => current_config,
          "metadata" => metadata,
          "snapshot_id" => SecureRandom.uuid,
          "collection_method" => "automated"
        }

        PgInsights::HealthCheckResult.create!(
          check_type: "database_snapshot",
          status: "success",
          result_data: result_data,
          execution_time_ms: rand(50..300),
          executed_at: timestamp
        )
      end

      print "." if index % 10 == 0
    end

    puts "\n"

    total_snapshots = PgInsights::HealthCheckResult.where(check_type: "database_snapshot").count
    date_range = PgInsights::HealthCheckResult.where(check_type: "database_snapshot")
                                             .pluck(:executed_at)
                                             .minmax

    puts "✅ Generated #{total_snapshots} timeline snapshots"
    puts "📊 Date range: #{date_range[0].strftime('%B %d, %Y')} to #{date_range[1].strftime('%B %d, %Y')}"
    puts "⚙️  Configuration changes: #{config_changes.count} parameter updates"
    puts ""
    puts "🚀 Timeline feature is ready for testing!"
    puts "   Visit: /pg_insights/timeline"
    puts ""
    puts "📈 Sample metrics generated:"
    latest = PgInsights::HealthCheckResult.where(check_type: "database_snapshot").last
    if latest
      puts "   • Cache Hit Rate: #{latest.result_data.dig('metrics', 'cache_hit_rate')}%"
      puts "   • Avg Query Time: #{latest.result_data.dig('metrics', 'avg_query_time')}ms"
      puts "   • Total Connections: #{latest.result_data.dig('metrics', 'total_connections')}"
      puts "   • Database Size: #{latest.result_data.dig('metadata', 'database_size')}"
    end
  end

  desc "Generate sample data for development"
  task sample_data: :environment do
    puts "🎭 Generating sample health check data..."

    # Generate some basic health check results
    check_types = %w[
      unused_indexes
      missing_indexes
      bloated_tables
      slow_queries
      cache_hit_ratio
      connection_stats
    ]

    check_types.each do |check_type|
      3.times do |i|
        PgInsights::HealthCheckResult.create!(
          check_type: check_type,
          status: %w[success error].sample,
          result_data: generate_sample_result_data(check_type),
          execution_time_ms: rand(10..500),
          executed_at: rand(1..72).hours.ago
        )
      end
    end

    puts "✅ Generated sample health check data"
  end

  private

  def self.generate_sample_result_data(check_type)
    case check_type
    when "unused_indexes"
      {
        "indexes" => [
          { "table" => "users", "index" => "idx_users_old_email", "size" => "45MB", "scans" => 0 },
          { "table" => "orders", "index" => "idx_orders_temp", "size" => "23MB", "scans" => 2 }
        ],
        "total_wasted_space" => "68MB"
      }
    when "missing_indexes"
      {
        "suggestions" => [
          { "table" => "posts", "column" => "created_at", "seq_scans" => 1250, "estimated_benefit" => "High" },
          { "table" => "comments", "column" => "user_id", "seq_scans" => 890, "estimated_benefit" => "Medium" }
        ]
      }
    when "bloated_tables"
      {
        "tables" => [
          { "table" => "logs", "bloat_percent" => 45.2, "wasted_space" => "156MB" },
          { "table" => "events", "bloat_percent" => 32.1, "wasted_space" => "89MB" }
        ]
      }
    when "slow_queries"
      {
        "queries" => [
          { "query" => "SELECT * FROM users WHERE email LIKE...", "avg_time" => 1250.5, "calls" => 45 },
          { "query" => "UPDATE posts SET view_count...", "avg_time" => 890.2, "calls" => 123 }
        ]
      }
    when "cache_hit_ratio"
      {
        "buffer_cache_hit_ratio" => rand(85.0..99.9).round(2),
        "index_cache_hit_ratio" => rand(90.0..99.9).round(2)
      }
    when "connection_stats"
      {
        "total_connections" => rand(10..100),
        "active_connections" => rand(5..50),
        "idle_connections" => rand(5..30),
        "max_connections" => 100
      }
    else
      { "data" => "sample data", "timestamp" => Time.current }
    end
  end
end
