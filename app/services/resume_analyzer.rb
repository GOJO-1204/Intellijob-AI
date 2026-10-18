class ResumeAnalyzer
  COMMON_SKILLS = %w[ruby rails python javascript typescript sql react git docker aws c++ java c# golang html css node.js
                     postgresql mysql mongodb redis linux kubernetes azure gcp graphql sidekiq api testing rspec agile
                     scrum tailwind django flask jenkins pandas tensorflow angular vue].freeze
  def initialize(text, target_skills:, page_count:)
    @text = text.to_s.dup.force_encoding(Encoding::UTF_8).scrub
    @targets = Array(target_skills).map { |s| s.to_s.downcase.strip }.reject(&:empty?)
    @pages = page_count
  end
  def call
    rows = [ contact, sections, bullets, skills, length, ats_safe ].map do |name, score, max, issue, fix|
      { name: name, score: score.clamp(0, max), max: max, issue: issue, fix: fix }
    end
    checks = rows.map { |r| r.slice(:name, :score, :max) }
    if @text.strip.empty?
      none = { name: "Resume text", issue: "No text could be read from the resume.", fix: "Upload a text-based PDF or DOCX, not a scan." }
      return { score: 0, checks: checks.map { |c| c.merge(score: 0) }, shortcomings: [ none ] }
    end
    weak = rows.select { |r| r[:score] < r[:max] * 0.7 }
    { score: checks.sum { |c| c[:score] }, checks: checks, shortcomings: weak.map { |r| r.slice(:name, :issue, :fix) } }
  end

  private
  def found?(skill)
    @text.match?(/(?<![[:alnum:]+#])#{Regexp.escape(skill)}(?![[:alnum:]+#])/i)
  end
  def contact
    email = @text.match?(/[\w.+-]+@[\w-]+(\.[\w-]+)+/)
    phone = @text.scan(/\+?[\d(][\d ().-]{8,}[\d)]/).any? { |m| m.count("0-9").between?(10, 13) }
    [ "Contact details", (email ? 8 : 0) + (phone ? 7 : 0), 15, "Email or phone number not found.", "Put your email and phone number as plain text at the top of page 1." ]
  end
  def sections
    all = %w[summary skills experience education]
    missing = all.reject { |h| @text.lines.any? { |l| l.strip.size <= 40 && l.match?(/\b#{h}\b/i) } }
    [ "Section headings", (all.size - missing.size) * 5, 20, "Missing headings: #{missing.join(', ')}.",
     "Add plain-text headings: Summary, Skills, Experience, Education." ]
  end
  def bullets
    n = @text.lines.count { |l| l.match?(/\A\s*([•●▪◦]|-\s)\s*\S/) }
    [ "Bullet points", n * 15 / 8, 15, "Only #{n} bullet lines found (aim for 8+).", 'Describe each role with short lines starting with "•" or "-".' ]
  end
  def skills
    common = COMMON_SKILLS.count { |s| found?(s) }
    missing = @targets.reject { |s| found?(s) }
    hit = @targets.empty? ? 10 : (@targets.size - missing.size) * 10 / @targets.size
    [ "Skills coverage", [ common * 10 / 8, 10 ].min + hit, 20, "#{common} common skills found; #{missing.size} target skills missing (#{missing.join(', ')}).",
     "Add the skills you really have, using the exact wording from the job posting." ]
  end
  def length
    words = @text.split.size
    pts = ((300..900).cover?(words) ? 8 : (150..1200).cover?(words) ? 4 : 0) + (@pages.nil? || (1..2).cover?(@pages) ? 7 : @pages == 3 ? 3 : 0)
    [ "Length", pts, 15, "#{words} words on #{@pages || 'an unknown number of'} pages.", "Aim for 300-900 words on 1-2 pages." ]
  end
  def ats_safe
    bad = @text.scan(/[|\t]|[^\x00-\x7F•●▪◦–—‘’“”]/).size
    [ "ATS-safe formatting", bad.zero? ? 15 : bad <= 5 ? 8 : 0, 15, "#{bad} table or special characters found.", "Use a single column with no tables, text boxes, icons or symbols." ]
  end
end
