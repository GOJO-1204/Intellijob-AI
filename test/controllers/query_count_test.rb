require "test_helper"

class QueryCountTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def count_queries
    count = 0
    counter = lambda do |*args|
      count += 1 unless %w[SCHEMA TRANSACTION].include?(args.last[:name])
    end
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { yield }
    count
  end

  def queries_for(status, rows, path)
    user = User.create!(email: "q#{SecureRandom.hex(4)}@example.com", password: "password123")
    sign_in user
    rows.times do
      job = Job.create!(title: "Dev", company: "Acme", description: "Ruby", location: "Pune",
                        url: "https://example.com/#{SecureRandom.hex(6)}")
      user.job_applications.create!(job: job, status: status, score: 0.5)
    end
    count = count_queries { get path }
    assert_response :success
    assert_select "li[id^='job_application_']", rows
    count
  end

  test "matches page runs the same number of queries for 1 and 10 rows" do
    assert_equal queries_for("matched", 1, matches_path), queries_for("matched", 10, matches_path)
  end

  test "dashboard tab runs the same number of queries for 1 and 10 rows" do
    path = dashboard_path(status: "saved")
    assert_equal queries_for("saved", 1, path), queries_for("saved", 10, path)
  end
end
