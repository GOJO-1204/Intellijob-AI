require "test_helper"

class RateLimitUploadsTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup { RATE_LIMIT_STORE.clear }
  teardown { RATE_LIMIT_STORE.clear }

  def new_user
    User.create!(email: "r#{SecureRandom.hex(4)}@example.com", password: "password123")
  end

  test "the 11th upload in an hour from one user gets 429" do
    sign_in new_user
    10.times do
      post profile_path
      assert_response :unprocessable_entity
    end
    post profile_path
    assert_response :too_many_requests
  end

  test "another user is not affected by the first user's limit" do
    sign_in new_user
    11.times { post profile_path }
    assert_response :too_many_requests
    sign_out :user
    sign_in new_user
    post profile_path
    assert_response :unprocessable_entity
  end
end
