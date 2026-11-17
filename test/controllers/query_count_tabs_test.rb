require "test_helper"

class QueryCountTabsTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  TABS = %w[applied interview offer rejected dismissed].freeze

  def count_queries
    count = 0
    counter = lambda do |*args|
      count += 1 unless %w[SCHEMA TRANSACTION].include?(args.last[:name])
    end
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { yield }
    count
  end

  def queries_for(status, rows)
    user = User.create!(email: "q#{SecureRandom.hex(4)}@example.com", password: "password123")
    sign_in user
    rows.times do
      job = Job.create!(title: "Dev", company: "Acme", description: "Ruby", location: "Pune",
                        url: "https://example.com/#{SecureRandom.hex(6)}")
      user.job_applications.create!(job: job, status: status, score: 0.5, applied_at: Time.current)
    end
    count = count_queries { get dashboard_path(status: status) }
    assert_response :success
    assert_select "li[id^='job_application_']", rows
    count
  end

  TABS.each do |status|
    test "dashboard #{status} tab runs the same number of queries for 1 and 10 rows" do
      assert_equal queries_for(status, 1), queries_for(status, 10)
    end
  end
end
