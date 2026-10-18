class FetchJobsJob < ApplicationJob
  def perform
    JobSources.all.each { |source| import_source(source) }
    EmbedRecordsJob.perform_later
  end

  private

  # One source never stops the others: any error is rescued per source.
  def import_source(source)
    fetched = saved = skipped = 0

    source.fetch.each do |hash|
      fetched += 1
      job = Job.upsert_from(hash)
      if job&.persisted?
        saved += 1
      else
        skipped += 1
      end
    end

    Rails.logger.info("[FetchJobsJob] #{source.name}: fetched=#{fetched} saved=#{saved} skipped=#{skipped}")
  rescue StandardError => e
    Rails.logger.warn("[FetchJobsJob] #{source.name} failed: #{e.class}")
  end
end
