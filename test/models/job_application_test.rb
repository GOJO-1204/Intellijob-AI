require "test_helper"

class JobApplicationTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email: "a@example.com", password: "password123")
    @job = Job.create!(title: "Dev", company: "Acme", description: "Build things", url: "https://example.com/1", posted_at: 1.day.ago)
    @application = JobApplication.create!(user: @user, job: @job, status: :matched)
  end

  test "stamps applied_at when status changes to applied" do
    assert_nil @application.applied_at
    @application.update!(status: :applied)
    assert_not_nil @application.applied_at
  end

  test "does not overwrite an existing applied_at" do
    original = 3.days.ago.change(usec: 0)
    @application.update!(status: :applied, applied_at: original)
    @application.update!(status: :interview)
    assert_equal original, @application.reload.applied_at
  end

  test "does not stamp applied_at for other statuses" do
    @application.update!(status: :saved)
    assert_nil @application.applied_at
  end

  test "alertable returns only matched, un-notified applications" do
    other_job = Job.create!(title: "B", company: "C", url: "https://example.com/2", posted_at: 1.day.ago)
    notified = JobApplication.create!(user: @user, job: other_job, status: :matched, notified_at: Time.current)

    assert_includes JobApplication.alertable, @application
    assert_not_includes JobApplication.alertable, notified
  end

  test "a user cannot apply to the same job twice" do
    duplicate = JobApplication.new(user: @user, job: @job)
    assert_not duplicate.valid?
  end

  test "does not stamp applied_at for dismissed" do
    @application.update!(status: :dismissed)

    assert_nil @application.applied_at
  end

  test "keeps applied_at on a second save while still applied" do
    first = nil

    travel_to Time.zone.local(2026, 3, 2, 10, 0, 0) do
      @application.update!(status: :applied)
      first = @application.applied_at
    end
    assert_not_nil first

    travel_to Time.zone.local(2026, 3, 4, 10, 0, 0) do
      @application.update!(notes: "follow up")
    end

    assert_equal first.change(usec: 0), @application.reload.applied_at.change(usec: 0)
  end

  test "keeps the first applied_at when moving applied, interview, applied" do
    start = Time.zone.local(2026, 3, 2, 10, 0, 0)
    first = nil

    travel_to start do
      @application.update!(status: :applied)
      first = @application.applied_at
    end
    assert_not_nil first

    travel_to start + 1.day do
      @application.update!(status: :interview)
    end

    travel_to start + 2.days do
      @application.update!(status: :applied)
    end

    assert_equal first.change(usec: 0), @application.reload.applied_at.change(usec: 0)
  end
end
