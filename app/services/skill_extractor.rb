class SkillExtractor
  def self.call(text)
    clean = text.to_s.dup.force_encoding(Encoding::UTF_8).scrub
    return [] if clean.strip.empty?

    ResumeAnalyzer::COMMON_SKILLS.select { |skill| found?(clean, skill) }
  end

  def self.found?(text, skill)
    text.match?(/(?<![[:alnum:]+#])#{Regexp.escape(skill)}(?![[:alnum:]+#])/i)
  end

  private_class_method :found?
end
