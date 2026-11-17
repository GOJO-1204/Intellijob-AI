require "test_helper"

class UnsubscribesControllerTest < ActionDispatch::IntegrationTest
  def create_user(email, frequency = "daily")
    user = User.create!(email: email, password: "password123")
    profile = user.profile || user.build_profile
    profile.update!(alert_frequency: frequency)
    user
  end

  def token_for(user)
    user.signed_id(purpose: :unsubscribe)
  end

  def frequency_of(user)
    user.profile.reload.alert_frequency
  end

  # Every kind of bad token, as request params.
  def bad_params(user)
    { "tampered" => { token: "#{token_for(user)}tampered" },
      "wrong purpose" => { token: user.signed_id(purpose: :other) },
      "missing" => {},
      "empty" => { token: "" },
      "array" => { token: [ "x" ] },
      "hash" => { token: { a: "b" } } }
  end

  def assert_invalid_page(name)
    assert_response :not_found, name
    assert_select "h1", "This link is not valid"
  end

  def with_forgery_protection
    original = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    yield
  ensure
    ActionController::Base.allow_forgery_protection = original
  end

  test "GET with a valid token shows the confirm form and changes nothing" do
    user = create_user("unsub-get-1@example.com")
    token = token_for(user)
    2.times { get unsubscribe_path, params: { token: token } }

    assert_response :success
    assert_select "h1", "Pause your job alerts"
    assert_select "form[method=post][action='/unsubscribe'][data-turbo=false]", count: 1
    assert_select "form input[type=hidden][name=token][value=?]", token
    assert_select "form button[type=submit]", "Pause my alerts"
    assert_equal "daily", frequency_of(user)
  end

  test "GET leaves a weekly user on weekly" do
    user = create_user("unsub-get-2@example.com", "weekly")
    get unsubscribe_path, params: { token: token_for(user) }

    assert_response :success
    assert_equal "weekly", frequency_of(user)
  end

  test "GET never shows the email address" do
    user = create_user("unsub-get-3@example.com")
    get unsubscribe_path, params: { token: token_for(user) }

    assert_response :success
    assert_not_includes response.body, user.email
  end

  test "GET with a bad token shows the invalid page and changes nothing" do
    user = create_user("unsub-get-4@example.com")
    bad_params(user).each do |name, request_params|
      get unsubscribe_path, params: request_params
      assert_invalid_page(name)
      assert_equal "daily", frequency_of(user), name
    end
  end

  test "POST with a valid token pauses the alerts" do
    user = create_user("unsub-post-1@example.com")
    post unsubscribe_path, params: { token: token_for(user) }

    assert_response :success
    assert_select "h1", "Alerts paused"
    assert_equal "paused", frequency_of(user)
  end

  test "POST works without signing in" do
    user = create_user("unsub-post-2@example.com", "weekly")
    post unsubscribe_path, params: { token: token_for(user) }

    assert_response :success
    assert_equal "paused", frequency_of(user)
  end

  test "POST leaves another user alone" do
    user = create_user("unsub-post-3@example.com")
    other = create_user("unsub-post-4@example.com", "weekly")
    post unsubscribe_path, params: { token: token_for(user) }

    assert_equal "paused", frequency_of(user)
    assert_equal "weekly", frequency_of(other)
  end

  test "POST with a bad token shows the invalid page and changes nothing" do
    user = create_user("unsub-post-5@example.com")
    bad_params(user).each do |name, request_params|
      post unsubscribe_path, params: request_params
      assert_invalid_page(name)
      assert_equal "daily", frequency_of(user), name
    end
  end

  test "POST for an already paused user stays paused" do
    user = create_user("unsub-post-6@example.com", "paused")
    post unsubscribe_path, params: { token: token_for(user) }

    assert_response :success
    assert_select "h1", "Alerts paused"
    assert_equal "paused", frequency_of(user)
  end

  test "POST when the profile was destroyed shows the invalid page" do
    user = create_user("unsub-post-7@example.com")
    token = token_for(user)
    user.profile.destroy

    assert_nothing_raised { post unsubscribe_path, params: { token: token } }
    assert_invalid_page("no profile")
  end

  test "the confirm form carries an authenticity token" do
    user = create_user("unsub-csrf-1@example.com")
    with_forgery_protection do
      get unsubscribe_path, params: { token: token_for(user) }
      assert_select "form input[type=hidden][name=authenticity_token]", count: 1
    end
  end

  test "POST with the form's authenticity token pauses the alerts" do
    user = create_user("unsub-csrf-2@example.com")
    token = token_for(user)
    with_forgery_protection do
      get unsubscribe_path, params: { token: token }
      form_token = css_select("form input[name=authenticity_token]").first["value"]
      post unsubscribe_path, params: { token: token, authenticity_token: form_token }

      assert_response :success
      assert_select "h1", "Alerts paused"
    end
    assert_equal "paused", frequency_of(user)
  end

  test "POST without an authenticity token is refused" do
    user = create_user("unsub-csrf-3@example.com")
    with_forgery_protection do
      post unsubscribe_path, params: { token: token_for(user) }
      assert_response :unprocessable_entity
    end
    assert_equal "daily", frequency_of(user)
  end
end
