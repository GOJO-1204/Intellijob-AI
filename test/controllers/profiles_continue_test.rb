require "test_helper"

class ProfilesContinueTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def profile_with(attrs)
    user = User.create!(email: "t#{SecureRandom.hex(4)}@example.com", password: "password123")
    sign_in user
    user.profile.update!(attrs)
  end

  test "the results page links on to preferences" do
    profile_with(resume_text: "x", ats_score: 70, ats_feedback: { checks: [], shortcomings: [] })
    get profile_path
    assert_select "a[href=?]", edit_preferences_path, text: "Continue"
  end

  test "the continue link is also shown while the analysis is running" do
    profile_with(resume_text: "x")
    get profile_path
    assert_select "a[href=?]", edit_preferences_path, text: "Continue"
  end
end
