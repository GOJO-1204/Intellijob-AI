require "test_helper"

class MatchesEmptyStateTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  TURBO = { "Accept" => "text/vnd.turbo-stream.html" }.freeze

  def new_user
    User.create!(email: "t#{SecureRandom.hex(4)}@example.com", password: "password123")
  end

  def match_for(user)
    job = Job.create!(title: "Dev", company: "Acme", description: "Ruby",
                      url: "https://example.com/#{SecureRandom.hex(6)}")
    user.job_applications.create!(job: job)
  end

  def dismiss(record)
    patch job_application_path(record),
          params: { job_application: { status: "dismissed" } }, headers: TURBO
  end

  test "dismissing the last match swaps in the empty state" do
    me = new_user
    record = match_for(me)
    sign_in me
    dismiss(record)
    assert_response :success
    assert_includes response.body, 'target="matches_list"'
    assert_includes response.body, "No matches yet"
  end

  test "dismissing one of two matches leaves the list alone" do
    me = new_user
    first = match_for(me)
    match_for(me)
    sign_in me
    dismiss(first)
    assert_response :success
    assert_not_includes response.body, 'target="matches_list"'
  end

  test "the matches page wraps the empty state in the list container" do
    sign_in new_user
    get matches_path
    assert_select "#matches_list p", "No matches yet"
  end
end
