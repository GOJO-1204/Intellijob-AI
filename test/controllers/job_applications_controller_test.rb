require "test_helper"

class JobApplicationsControllerTest < ActionDispatch::IntegrationTest
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

  def patch_application(record, attrs, headers: {})
    patch job_application_path(record), params: { job_application: attrs }, headers: headers
  end

  test "signed-out visitors are sent to log in" do
    patch_application(match_for(new_user), { status: "saved" })
    assert_redirected_to new_user_session_path
  end

  test "status and notes are saved and the card is replaced by turbo stream" do
    me = new_user
    record = match_for(me)
    sign_in me
    patch_application(record, { status: "saved", notes: "Call Monday" }, headers: TURBO)
    assert_response :success
    assert_select "turbo-stream[action=replace][target=job_application_#{record.id}]"
    assert_equal [ "saved", "Call Monday" ], [ record.reload.status, record.notes ]
  end

  test "a plain html request redirects to matches and stamps applied_at" do
    me = new_user
    record = match_for(me)
    sign_in me
    patch_application(record, { status: "applied" })
    assert_redirected_to matches_path
    assert_not_nil record.reload.applied_at
  end

  test "dismissing saves the status and removes the card by turbo stream" do
    me = new_user
    record = match_for(me)
    sign_in me
    patch_application(record, { status: "dismissed" }, headers: TURBO)
    assert_response :success
    assert_select "turbo-stream[action=remove][target=job_application_#{record.id}]"
    assert_equal "dismissed", record.reload.status
  end
end
