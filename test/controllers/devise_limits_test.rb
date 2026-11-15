require "test_helper"

class DeviseLimitsTest < ActionDispatch::IntegrationTest
  setup { RATE_LIMIT_STORE.clear }
  teardown { RATE_LIMIT_STORE.clear }

  def login(email)
    post user_session_path, params: { user: { email: email, password: "wrong-password" } }
  end

  def reset(email)
    post user_password_path, params: { user: { email: email } }
  end

  def sign_up
    post user_registration_path, params: { user: { email: "", password: "", password_confirmation: "" } }
  end

  def assert_allowed
    assert_not_equal 429, response.status
  end

  test "login: the 31st attempt in 5 minutes from one IP gets 429" do
    30.times do |i|
      login("u#{i}@example.com")
      assert_allowed
    end
    login("u30@example.com")
    assert_response :too_many_requests
  end

  test "login: the 6th attempt for one email gets 429 whatever the letter case" do
    5.times do |i|
      login(i.even? ? "Same@Example.com" : "same@example.com")
      assert_allowed
    end
    login("SAME@example.com")
    assert_response :too_many_requests
    login("other@example.com")
    assert_allowed
  end

  test "sign up: the 31st attempt in an hour from one IP gets 429" do
    30.times do
      sign_up
      assert_allowed
    end
    sign_up
    assert_response :too_many_requests
  end

  test "password reset: the 11th request in an hour from one IP gets 429" do
    10.times do |i|
      reset("nobody#{i}@example.com")
      assert_allowed
    end
    reset("nobody10@example.com")
    assert_response :too_many_requests
  end

  test "password reset: the 4th request for one email gets 429" do
    3.times do
      reset("nobody@example.com")
      assert_allowed
    end
    reset("nobody@example.com")
    assert_response :too_many_requests
    reset("someone@example.com")
    assert_allowed
  end

  test "opening the pages is never counted" do
    35.times do
      get new_user_session_path
      assert_response :success
      get new_user_registration_path
      assert_response :success
      get new_user_password_path
      assert_response :success
    end
  end

  test "a text value instead of the form fields is not a server error" do
    post user_session_path, params: { user: "text" }
    assert_not_equal 500, response.status
  end

  test "login: blank emails are counted by IP, the 6th gets 429" do
    5.times do
      login("")
      assert_allowed
    end
    login("")
    assert_response :too_many_requests
  end
end
