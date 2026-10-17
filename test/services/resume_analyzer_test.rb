require "test_helper"

class ResumeAnalyzerTest < ActiveSupport::TestCase
  def good_resume
    filler = (%w[delivered features for customers every sprint] * 50).join(" ")
    bullets = Array.new(8) { |i| "- Built feature number #{i}" }
    [ "Jane Doe", "jane@example.com +1 555 123 4567", "Summary", "Backend developer.", "Skills",
     "Ruby, Rails, Python, JavaScript, SQL, PostgreSQL, Git, Docker, AWS, React",
     "Experience", filler, *bullets, "Education", "B.Tech in Computer Science" ].join("\n")
  end

  def analyze(text, target_skills: %w[ruby docker], page_count: 1)
    ResumeAnalyzer.new(text, target_skills: target_skills, page_count: page_count).call
  end

  def check(result, name)
    result[:checks].find { |c| c[:name] == name }
  end

  test "a good resume scores 100 with no shortcomings" do
    result = analyze(good_resume)

    assert_equal %i[score checks shortcomings], result.keys
    assert_equal 100, result[:score]
    assert_equal 100, result[:checks].sum { |c| c[:max] }
    assert_empty result[:shortcomings]
  end

  test "nil text returns score 0 with one clear shortcoming" do
    result = analyze(nil, target_skills: [], page_count: nil)

    assert_equal 0, result[:score]
    assert_equal 100, result[:checks].sum { |c| c[:max] }
    assert_equal [ "Resume text" ], result[:shortcomings].map { |s| s[:name] }
  end

  test "empty text returns score 0 with one clear shortcoming" do
    result = analyze("", target_skills: [], page_count: nil)

    assert_equal 0, result[:score]
    assert_equal [ "Resume text" ], result[:shortcomings].map { |s| s[:name] }
  end

  test "missing headings score 0 and are listed in the shortcoming" do
    result = analyze("Jane Doe\njane@example.com\nI write code.")
    shortcoming = result[:shortcomings].find { |s| s[:name] == "Section headings" }

    assert_equal 0, check(result, "Section headings")[:score]
    assert_includes shortcoming[:issue], "education"
  end

  test "pipes and tabs lower the ATS-safe formatting score" do
    result = analyze(good_resume + "\nSkills | Level\nRuby\t5")

    assert_equal 8, check(result, "ATS-safe formatting")[:score]
    assert_equal 93, result[:score]
    assert_includes result[:shortcomings].map { |s| s[:name] }, "ATS-safe formatting"
  end

  test "binary encoded text does not raise" do
    result = analyze("caf\xC3\xA9 ruby".b, target_skills: [], page_count: nil)

    assert_kind_of Integer, result[:score]
  end
end
