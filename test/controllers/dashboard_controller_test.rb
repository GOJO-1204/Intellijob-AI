require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "signed-out visitors are sent to log in" do
    get dashboard_path
    assert_redirected_to new_user_session_path
  end

  test "a signed-in user sees the empty state and the Profile link" do
    sign_in User.create!(email: "t#{SecureRandom.hex(4)}@example.com", password: "password123")
    get dashboard_path
    assert_response :success
    assert_select "p", "No applications yet"
    assert_select "nav a[href=?]", profile_path, text: "Profile"
  end
end
