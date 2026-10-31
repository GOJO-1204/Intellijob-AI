require "test_helper"

class ProfilesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def new_user
    User.create!(email: "t#{SecureRandom.hex(4)}@example.com", password: "password123")
  end

  def signed_in_profile(attrs = {})
    user = new_user
    sign_in user
    user.profile.tap { |p| p.update!(attrs) }
  end

  test "show requires sign in" do
    get profile_path
    assert_redirected_to new_user_session_path
  end

  test "show redirects to the upload page without resume text" do
    signed_in_profile
    get profile_path
    assert_redirected_to new_profile_path
  end

  test "show says analyzing while the score is nil" do
    signed_in_profile(resume_text: "Some resume text")
    get profile_path
    assert_response :success
    assert_select "p", /Analyzing your resume/
  end

  test "show lists the score, fixes and tips" do
    checks = [ { name: "Contact details", score: 15, max: 15 } ]
    fixes = [ { name: "Bullet points", issue: "Only 2 bullet lines found", fix: "Use short bullets" } ]
    tips = [ { original: "Did stuff", improved: "Built features", why: "More specific" } ]
    signed_in_profile(resume_text: "x", ats_score: 62, ats_feedback: { checks: checks, shortcomings: fixes }, ai_suggestions: tips)
    get profile_path
    assert_response :success
    assert_select "li span", "Contact details"
    assert_select "li span", "15 / 15"
    assert_select "[role='progressbar'][aria-label='Contact details'][aria-valuemin='0'][aria-valuemax='15'][aria-valuenow='15']"
    assert_select "[role='progressbar'] div[style='width: 100%']"
    assert_select "li", /Only 2 bullet lines found/
    assert_select "li", /Built features/
  end

  test "show escapes tip text" do
    tips = [ { original: "<script>alert(1)</script>", improved: "b", why: "c" } ]
    signed_in_profile(resume_text: "x", ats_score: 10, ats_feedback: { checks: [], shortcomings: [] }, ai_suggestions: tips)
    get profile_path
    assert_response :success
    assert_not_includes response.body, "<script>alert(1)</script>"
  end

  test "show never displays another user's results" do
    other_fixes = [ { name: "Other", issue: "OTHER USER SECRET", fix: "none" } ]
    new_user.profile.update!(resume_text: "x", ats_score: 99, ats_feedback: { checks: [], shortcomings: other_fixes })
    signed_in_profile(resume_text: "x", ats_score: 11, ats_feedback: { checks: [], shortcomings: [] })
    get profile_path
    assert_response :success
    assert_not_includes response.body, "OTHER USER SECRET"
  end
end
