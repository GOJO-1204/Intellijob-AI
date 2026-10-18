require "test_helper"

class ResumeAnalysisJobTest < ActiveSupport::TestCase
  TIP = { "original" => "a", "improved" => "b", "why" => "c" }.freeze
  TEXT = "Jane Doe\njane@example.com\n+1 555 123 4567\nSummary\nSkills\nRuby, Rails\nExperience\n- Built apps\nEducation".freeze

  def profile_with(text)
    user = User.create!(email: "t#{SecureRandom.hex(4)}@example.com", password: "password123")
    user.profile.tap { |p| p.update!(resume_text: text, target_role: "Rails Developer", target_skills: [ "ruby" ]) }
  end

  def with_reviewer(tips)
    fake = Struct.new(:call).new(tips)
    ResumeAiReviewer.define_singleton_method(:new) { |*_args, **_opts| fake }
    yield
  ensure
    ResumeAiReviewer.singleton_class.send(:remove_method, :new)
  end

  test "saves the ATS score, feedback and AI tips" do
    profile = profile_with(TEXT)
    with_reviewer([ { original: "a", improved: "b", why: "c" } ]) { ResumeAnalysisJob.perform_now(profile.id) }
    profile.reload
    assert_kind_of Integer, profile.ats_score
    assert_equal %w[checks shortcomings], profile.ats_feedback.keys.sort
    assert_equal [ TIP ], profile.ai_suggestions
  end

  test "keeps the ATS result when the reviewer returns nothing" do
    profile = profile_with(TEXT)
    with_reviewer([]) { ResumeAnalysisJob.perform_now(profile.id) }
    assert_not_nil profile.reload.ats_score
    assert_equal [], profile.ai_suggestions
  end

  test "ignores a missing profile" do
    assert_nothing_raised { ResumeAnalysisJob.perform_now(0) }
  end

  test "skips a profile without resume text" do
    profile = profile_with("")
    with_reviewer([]) { ResumeAnalysisJob.perform_now(profile.id) }
    assert_nil profile.reload.ats_score
  end
end
