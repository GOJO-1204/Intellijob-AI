require "test_helper"

class DashboardStatsTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email: "stats@example.com", password: "password123")
    @other = User.create!(email: "stats-other@example.com", password: "password123")
    @job_number = 0
  end

  test "user with no applications gets zeros and nil average" do
    stats = DashboardStats.call(@user)

    assert_equal JobApplication.statuses.keys.index_with(0), stats[:counts]
    assert_nil stats[:avg_score]
    assert_equal 0, stats[:applied_this_week]
  end

  test "counts are correct for a mix of statuses" do
    2.times { add_application(@user, "matched") }
    add_application(@user, "applied")
    add_application(@user, "interview")
    add_application(@user, "dismissed")

    counts = DashboardStats.call(@user)[:counts]
    expected = JobApplication.statuses.keys.index_with(0).merge(
      "matched" => 2, "applied" => 1, "interview" => 1, "dismissed" => 1
    )

    assert_equal expected, counts
    assert counts.values.all?(Integer)
  end

  test "other users applications are never counted" do
    add_application(@user, "matched", score: 50)
    add_application(@other, "matched", score: 90)
    add_application(@other, "applied", score: 90)

    stats = DashboardStats.call(@user)

    assert_equal 1, stats[:counts]["matched"]
    assert_equal 0, stats[:counts]["applied"]
    assert_equal 50.0, stats[:avg_score]
    assert_equal 0, stats[:applied_this_week]
  end

  test "avg_score ignores dismissed and nil scores and applied_this_week ignores old dates" do
    travel_to Time.zone.local(2026, 10, 28, 12, 0, 0) do
      add_application(@user, "matched", score: 70)
      add_application(@user, "interview", score: 70)
      add_application(@user, "matched", score: 71)
      add_application(@user, "dismissed", score: 5)
      add_application(@user, "matched", score: nil)
      add_application(@user, "applied", applied_at: 6.days.ago)
      add_application(@user, "applied", applied_at: 8.days.ago)

      stats = DashboardStats.call(@user)

      assert_instance_of Float, stats[:avg_score]
      assert_equal 70.33, stats[:avg_score]
      assert_equal 1, stats[:applied_this_week]
    end
  end

  private

  def add_application(user, status, score: nil, applied_at: nil)
    @job_number += 1
    job = Job.create!(title: "Developer #{@job_number}", company: "Acme",
                      url: "https://example.com/jobs/#{@job_number}")
    application = user.job_applications.create!(job: job, status: status, score: score)
    application.update_columns(applied_at: applied_at) if applied_at
    application
  end
end
