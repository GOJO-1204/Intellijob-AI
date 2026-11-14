require "test_helper"

class AuthorizationTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  [
    [ :get, "/dashboard" ], [ :get, "/profile" ], [ :get, "/profile/new" ], [ :post, "/profile" ],
    [ :get, "/preferences/edit" ], [ :patch, "/preferences" ], [ :put, "/preferences" ],
    [ :get, "/matches" ], [ :get, "/job_applications/new" ], [ :post, "/job_applications" ],
    [ :patch, "/job_applications/1" ], [ :put, "/job_applications/1" ]
  ].each do |verb, route|
    test "signed out #{verb.upcase} #{route} goes to log in" do
      send(verb, route)
      assert_redirected_to new_user_session_path
    end
  end

  test "another user's application cannot be changed with PUT either" do
    owner = User.create!(email: "o#{SecureRandom.hex(4)}@example.com", password: "password123")
    job = Job.create!(title: "Dev", company: "Acme", description: "Ruby",
                      url: "https://example.com/#{SecureRandom.hex(6)}")
    record = owner.job_applications.create!(job: job)
    sign_in User.create!(email: "i#{SecureRandom.hex(4)}@example.com", password: "password123")
    put job_application_path(record), params: { job_application: { status: "saved" } }
    assert_response :not_found
    assert_equal "matched", record.reload.status
  end
end
