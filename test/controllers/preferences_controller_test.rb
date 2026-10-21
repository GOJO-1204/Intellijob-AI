require "test_helper"

class PreferencesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def new_user
    User.create!(email: "t#{SecureRandom.hex(4)}@example.com", password: "password123")
  end

  def signed_in_profile(attrs = { resume_text: "I use Ruby and Rails daily" })
    user = new_user
    sign_in user
    user.profile.tap { |p| p.update!(attrs) }
  end

  def good_params(extra = {})
    form = { target_role: "Rails Developer", target_skills: [ "ruby", "rails" ], extra_skills: "Go, ruby",
             location: "Pune", remote: "1", salary_min: "50000", experience_level: "mid", alert_frequency: "weekly" }
    { profile: form.merge(extra) }
  end

  test "edit requires sign in" do
    get edit_preferences_path
    assert_redirected_to new_user_session_path
  end

  test "edit redirects to the upload page without resume text" do
    signed_in_profile({})
    get edit_preferences_path
    assert_redirected_to new_profile_path
  end

  test "edit offers skills found in the resume" do
    signed_in_profile
    get edit_preferences_path
    assert_response :success
    assert_select "input[type=checkbox][value=ruby][checked]"
    assert_select "input[type=checkbox][value=rails][checked]"
  end

  test "edit keeps saved skills and shows extra ones" do
    signed_in_profile(resume_text: "Ruby developer", target_skills: [ "ruby", "go" ])
    get edit_preferences_path
    assert_select "input[type=checkbox][value=ruby][checked]"
    assert_select "input[name='profile[extra_skills]'][value=go]"
  end

  test "update saves preferences, clears the embedding and enqueues the embed job" do
    profile = signed_in_profile(resume_text: "Ruby", embedding: [ 0.1, 0.2 ])
    assert_enqueued_with(job: EmbedRecordsJob) { patch preferences_path, params: good_params }
    assert_redirected_to matches_path
    profile.reload
    assert_equal [ "ruby", "rails", "go" ], profile.target_skills
    assert_equal "weekly", profile.alert_frequency
    assert_equal 50_000, profile.salary_min
    assert profile.remote
    assert_nil profile.embedding
  end

  test "update rejects a blank role and enqueues nothing" do
    profile = signed_in_profile
    assert_no_enqueued_jobs { patch preferences_path, params: good_params(target_role: "") }
    assert_response :unprocessable_entity
    assert_select "div", /Target role can't be blank/
    assert_nil profile.reload.target_role
  end

  test "update rejects invalid values" do
    signed_in_profile
    [ { alert_frequency: "hourly" }, { salary_min: "-5" }, { experience_level: "wizard" } ].each do |bad|
      patch preferences_path, params: good_params(bad)
      assert_response :unprocessable_entity
    end
  end

  test "update ignores attributes outside the form" do
    profile = signed_in_profile
    patch preferences_path, params: good_params(ats_score: "99")
    assert_redirected_to matches_path
    assert_nil profile.reload.ats_score
  end

  test "update never touches another user's profile" do
    other = new_user.profile.tap { |p| p.update!(resume_text: "x", target_role: "Other") }
    signed_in_profile
    patch preferences_path, params: good_params
    assert_equal "Other", other.reload.target_role
  end
end
