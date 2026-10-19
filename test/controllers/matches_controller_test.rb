require "test_helper"

class MatchesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def new_user
    User.create!(email: "t#{SecureRandom.hex(4)}@example.com", password: "password123")
  end

  def match_for(user, title, score: nil, status: "matched")
    job = Job.create!(title: title, company: "Acme", description: "Ruby",
                      url: "https://example.com/#{SecureRandom.hex(6)}")
    user.job_applications.create!(job: job, score: score, status: status)
  end

  def listed_titles
    css_select("li p.font-medium").map { |e| e.text.strip }
  end

  test "signed-out visitors are sent to log in" do
    get matches_path
    assert_redirected_to new_user_session_path
  end

  test "a user without matches sees the empty state" do
    sign_in new_user
    get matches_path
    assert_response :success
    assert_select "p", "No matches yet"
  end

  test "only the user's own matched rows are listed" do
    me = new_user
    match_for(me, "Mine")
    match_for(me, "Saved one", status: "saved")
    match_for(new_user, "Theirs")
    sign_in me
    get matches_path
    assert_equal [ "Mine" ], listed_titles
  end

  test "matches are sorted by score, unscored last, with a percent shown" do
    me = new_user
    match_for(me, "Unscored")
    match_for(me, "Low", score: 0.4)
    match_for(me, "High", score: 0.9)
    sign_in me
    get matches_path
    assert_equal [ "High", "Low", "Unscored" ], listed_titles
    assert_select "li p", /90%/
  end
end
