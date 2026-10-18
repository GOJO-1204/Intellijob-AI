# Ranks recent jobs against a profile embedding by cosine similarity.
class Matcher
  def self.call(profile, limit: 20)
    vector = profile.embedding
    return [] unless vector.is_a?(Array) && vector.any?

    norm = norm_of(vector)
    scored = candidates(profile).filter_map do |job|
      other = job.embedding
      next unless other.is_a?(Array) && other.length == vector.length

      [ job, similarity(vector, norm, other) ]
    end
    scored.sort_by { |_job, score| -score }.first(limit)
  end

  # All hard filters run in SQL, so only matching rows are loaded.
  def self.candidates(profile)
    scope = Job.recent
               .where("embedding IS NOT NULL")
               .where("source IS DISTINCT FROM 'manual'") # keeps NULL sources
    if profile.remote
      scope = scope.where(remote: true)
    elsif profile.location.present?
      pattern = "%#{ActiveRecord::Base.sanitize_sql_like(profile.location)}%"
      scope = scope.where("location ILIKE ? OR remote = TRUE", pattern)
    end
    if profile.salary_min.present?
      scope = scope.where("salary_min IS NULL OR salary_min >= ?", profile.salary_min)
    end
    scope
  end

  def self.similarity(vector, norm, other)
    other_norm = norm_of(other)
    return 0.0 if norm.zero? || other_norm.zero?

    dot = vector.zip(other).sum { |a, b| a * b }
    (dot / (norm * other_norm)).to_f
  end

  def self.norm_of(vector)
    Math.sqrt(vector.sum { |value| value * value })
  end

  private_class_method :candidates, :similarity, :norm_of
end
