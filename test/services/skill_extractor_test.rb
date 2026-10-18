require "test_helper"

class SkillExtractorTest < ActiveSupport::TestCase
  test "finds known skills regardless of case" do
    assert_equal %w[ruby rails sql], SkillExtractor.call("Built apps with RUBY, Rails and sql.")
  end

  test "returns skills in list order without duplicates" do
    assert_equal %w[ruby rails], SkillExtractor.call("Rails Rails ruby ruby rails")
  end

  test "does not match java inside javascript" do
    assert_equal %w[javascript], SkillExtractor.call("Wrote JavaScript daily")
  end

  test "handles skills with symbols" do
    assert_equal %w[c++ c# node.js], SkillExtractor.call("C++, C# and Node.js")
  end

  test "does not match skills inside longer words" do
    assert_equal [], SkillExtractor.call("Uses github and reactive design")
  end

  test "returns an empty array for blank or nil text" do
    assert_equal [], SkillExtractor.call(nil)
    assert_equal [], SkillExtractor.call("  \n ")
  end

  test "does not fail on invalid bytes" do
    assert_equal %w[ruby], SkillExtractor.call("Ruby \xFF developer".b)
  end
end
