# frozen_string_literal: true

module PgInsights
  class ApplicationJob < ActiveJob::Base
    queue_as do
      PgInsights.background_job_queue
    end
  end
end
