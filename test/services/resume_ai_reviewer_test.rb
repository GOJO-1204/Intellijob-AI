require "test_helper"

class ResumeAiReviewerTest < ActiveSupport::TestCase
  def reviewer(text = "Built a Rails app", &stub)
    ResumeAiReviewer.new(text, target_role: "Developer").tap do |r|
      r.define_singleton_method(:post, &stub)
    end
  end

  def gemini_body(text)
    { candidates: [ { content: { parts: [ { text: text } ] } } ] }.to_json
  end

  test "returns tips with symbol keys" do
    body = gemini_body([ { original: "a", improved: "b", why: "c" } ].to_json)
    result = reviewer { |_payload| body }.call
    assert_equal [ { original: "a", improved: "b", why: "c" } ], result
  end

  test "drops items with missing fields" do
    items = [ { original: "a" }, { original: "a", improved: "b", why: "c" } ]
    body = gemini_body(items.to_json)
    assert_equal 1, reviewer { |_payload| body }.call.size
  end

  test "returns empty array when the answer is not JSON" do
    body = gemini_body("not json")
    assert_equal [], reviewer { |_payload| body }.call
  end

  test "returns empty array when the request fails" do
    assert_equal [], reviewer { |_payload| raise "HTTP 500" }.call
  end

  test "does not call Gemini for blank text" do
    called = false
    result = reviewer("  ") { |_payload| called = true }.call
    assert_equal [], result
    assert_not called
  end
end
