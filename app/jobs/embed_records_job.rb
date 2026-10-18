class EmbedRecordsJob < ApplicationJob
  def perform
    embed_group("Job", Job.recent.where(embedding: nil))
    embed_group("Profile", Profile.ready.where(embedding: nil))
    MatchJobsJob.perform_later
  end

  private

  def embed_group(label, scope)
    embedded = failed = 0

    scope.find_each do |record|
      if embed(record)
        embedded += 1
      else
        failed += 1
      end
    end

    Rails.logger.info("[EmbedRecordsJob] #{label}: embedded=#{embedded} failed=#{failed}")
  end

  # Returns true only when the record was saved with its embedding.
  # Rescued per record so one bad record never stops the rest. Logs the error class only.
  def embed(record)
    record.update(embedding: Embedder.call(record.embedding_text))
  rescue StandardError => e
    Rails.logger.warn("[EmbedRecordsJob] record failed: #{e.class}")
    false
  end
end
