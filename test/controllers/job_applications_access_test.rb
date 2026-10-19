require "test_helper"

class JobApplicationsAccessTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def new_user
    User.create!(email: "t#{SecureRandom.hex(4)}@example.com", password: "password123")
  end

  def match_for(user)
    job = Job.create!(title: "Dev", company: "Acme", description: "Ruby",
                      url: "https://example.com/#{SecureRandom.hex(6)}")
    user.job_applications.create!(job: job)
  end

  test "another user's application is not found and stays unchanged" do
    other = match_for(new_user)
    sign_in new_user
    patch job_application_path(other), params: { job_application: { status: "saved" } }
    assert_response :not_found
    assert_equal "matched", other.reload.status
  end

  test "an unknown status is refused" do
    me = new_user
    record = match_for(me)
    sign_in me
    patch job_application_path(record), params: { job_application: { status: "bogus" } }
    assert_response :unprocessable_entity
    assert_equal "matched", record.reload.status
  end

  test "the layout loads Turbo" do
    sign_in new_user
    get matches_path
    assert_select "script[type=importmap]", text: %r{@hotwired/turbo-rails}
  end
end
