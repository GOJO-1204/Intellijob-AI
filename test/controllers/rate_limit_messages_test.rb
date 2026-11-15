require "test_helper"

class RateLimitMessagesTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup { RATE_LIMIT_STORE.clear }
  teardown { RATE_LIMIT_STORE.clear }

  def assert_blocked_with(message)
    assert_response :too_many_requests
    assert_select "h1", "Too many requests"
    assert_includes response.body, message
  end

  test "login shows its message" do
    6.times { post user_session_path, params: { user: { email: "a@example.com", password: "x" } } }
    assert_blocked_with "Too many log in attempts. Please wait 5 minutes and try again."
  end

  test "sign up shows its message" do
    31.times { post user_registration_path, params: { user: { email: "", password: "", password_confirmation: "" } } }
    assert_blocked_with "Too many sign up attempts. Please try again in an hour."
  end

  test "password reset shows its message" do
    4.times { post user_password_path, params: { user: { email: "nobody@example.com" } } }
    assert_blocked_with "Too many password reset requests. Please try again in an hour."
  end

  test "resume upload shows its message" do
    sign_in User.create!(email: "m#{SecureRandom.hex(4)}@example.com", password: "password123")
    11.times { post profile_path }
    assert_blocked_with "You have uploaded too many resumes. Please try again in an hour."
  end
end
