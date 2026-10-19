require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def signed_in_profile(attrs = {})
    user = User.create!(email: "t#{SecureRandom.hex(4)}@example.com", password: "password123")
    sign_in user
    user.profile.tap { |p| p.update!(attrs) }
  end

  test "signed-out visitors see the landing page" do
    get root_path
    assert_response :success
    assert_select "a", "Sign up"
  end

  test "no resume sends the user to the upload page" do
    signed_in_profile
    get root_path
    assert_redirected_to new_profile_path
  end

  test "resume without a target role sends the user to preferences" do
    signed_in_profile(resume_text: "Ruby developer")
    get root_path
    assert_redirected_to edit_preferences_path
  end

  test "resume and role send the user to the dashboard" do
    signed_in_profile(resume_text: "Ruby developer", target_role: "Rails Developer")
    get root_path
    assert_redirected_to dashboard_path
  end

  test "a user without a profile row goes to the upload page" do
    user = User.create!(email: "t#{SecureRandom.hex(4)}@example.com", password: "password123")
    user.profile.destroy
    sign_in user
    get root_path
    assert_redirected_to new_profile_path
  end
end
