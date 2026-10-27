require "test_helper"

class UnsubscribesControllerTest < ActionDispatch::IntegrationTest
  def create_user(email, frequency)
    user = User.create!(email: email, password: "password123")
    profile = user.profile || user.build_profile
    profile.update!(alert_frequency: frequency)
    user
  end

  test "a valid link pauses alerts" do
    user = create_user("unsub-a@example.com", "daily")

    get unsubscribe_path(token: user.signed_id(purpose: :unsubscribe))

    assert_response :ok
    assert_select "h1", "Alerts paused"
    assert_equal "paused", user.profile.reload.alert_frequency
  end

  test "another user's alert frequency stays unchanged" do
    user = create_user("unsub-b@example.com", "daily")
    other = create_user("unsub-c@example.com", "weekly")

    get unsubscribe_path(token: user.signed_id(purpose: :unsubscribe))

    assert_equal "weekly", other.profile.reload.alert_frequency
  end

  test "a tampered token returns 404 and changes nothing" do
    user = create_user("unsub-d@example.com", "daily")
    token = user.signed_id(purpose: :unsubscribe)

    get unsubscribe_path(token: "#{token}tampered")

    assert_response :not_found
    assert_select "h1", "This link is not valid"
    assert_equal "daily", user.profile.reload.alert_frequency
  end

  test "a token with a different purpose returns 404 and changes nothing" do
    user = create_user("unsub-e@example.com", "daily")

    get unsubscribe_path(token: user.signed_id(purpose: :other))

    assert_response :not_found
    assert_select "h1", "This link is not valid"
    assert_equal "daily", user.profile.reload.alert_frequency
  end

  test "an already paused user gets 200 and stays paused" do
    user = create_user("unsub-f@example.com", "paused")

    get unsubscribe_path(token: user.signed_id(purpose: :unsubscribe))

    assert_response :ok
    assert_select "h1", "Alerts paused"
    assert_equal "paused", user.profile.reload.alert_frequency
  end
end
