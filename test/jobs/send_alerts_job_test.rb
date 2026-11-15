require "test_helper"

class SendAlertsJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  def make_user(frequency = "daily")
    user = User.create!(email: "alerts-#{SecureRandom.hex(4)}@example.com", password: "password123")
    user.profile.update!(alert_frequency: frequency)
    user
  end

  def make_application(user, number, attrs = {})
    job = Job.create!(url: "https://example.com/a/#{user.id}-#{number}", title: "Job #{number}",
                      company: "Acme", posted_at: 1.day.ago)
    JobApplication.create!({ user_id: user.id, job: job, status: "matched", score: number / 10.0 }.merge(attrs))
  end

  # Fake mailer. Records [ user, apps ] in mails and the user id of every deliver_later call.
  # It raises "boom secret" for the user whose email is fail_for.
  def with_mailer(fail_for: nil)
    mails = []
    deliveries = []
    JobAlertMailer.define_singleton_method(:new_matches) do |user, apps|
      raise "boom secret" if user.email == fail_for
      mails << [ user, apps ]
      Object.new.tap { |mail| mail.define_singleton_method(:deliver_later) { deliveries << user.id } }
    end
    yield mails, deliveries
  ensure
    if JobAlertMailer.singleton_class.instance_methods(false).include?(:new_matches)
      JobAlertMailer.singleton_class.send(:remove_method, :new_matches)
    end
  end

  # Runs the job and returns the captured log text.
  def run_job(frequency)
    original = Rails.logger
    io = StringIO.new
    Rails.logger = ActiveSupport::Logger.new(io)
    SendAlertsJob.perform_now(frequency)
    io.string
  ensure
    Rails.logger = original
  end

  def user_ids(mails)
    mails.map { |user, _apps| user.id }
  end

  def app_ids(mail)
    mail.last.map(&:id)
  end

  test "other frequencies do nothing" do
    app = make_application(make_user("daily"), 1)

    with_mailer do |mails, _deliveries|
      [ "paused", "hourly", nil, "DAILY" ].each { |frequency| run_job(frequency) }
      assert_empty mails
    end
    assert_nil app.reload.notified_at
  end

  test "each frequency emails only the users with that frequency" do
    daily = make_user("daily")
    weekly = make_user("weekly")
    paused = make_user("paused")
    apps = [ daily, weekly, paused ].map { |user| make_application(user, 1) }

    with_mailer do |mails, _deliveries|
      run_job("daily")
      assert_equal [ daily.id ], user_ids(mails)
      run_job("weekly")
      assert_equal [ daily.id, weekly.id ], user_ids(mails)
    end
    assert_equal [ true, true, false ], apps.map { |app| app.reload.notified_at.present? }
  end

  test "emails only the top 5 alertable applications by score" do
    user = make_user
    apps = (1..7).map { |number| make_application(user, number) }

    with_mailer do |mails, deliveries|
      run_job("daily")
      assert_equal 1, mails.size
      assert_equal apps.reverse.first(5).map(&:id), app_ids(mails.first)
      assert_equal [ user.id ], deliveries
    end
    assert_equal [ false, false, true, true, true, true, true ], apps.map { |app| app.reload.notified_at.present? }
  end

  test "leftover applications go out in the next run" do
    user = make_user
    apps = (1..7).map { |number| make_application(user, number) }

    with_mailer do |mails, _deliveries|
      run_job("daily")
      assert_equal 5, mails.last.last.size
      run_job("daily")
      assert_equal [ apps[1].id, apps[0].id ], app_ids(mails.last)
      run_job("daily")
      assert_equal 2, mails.size
    end
    assert(apps.all? { |app| app.reload.notified_at })
  end

  test "applications that are not alertable are never included" do
    user = make_user
    old = 2.days.ago
    others = (JobApplication.statuses.keys - [ "matched" ]).each_with_index.map do |status, index|
      make_application(user, index + 2, status: status)
    end
    notified = make_application(user, 20, notified_at: old)
    alertable = make_application(user, 1)

    with_mailer do |mails, _deliveries|
      run_job("daily")
      assert_equal [ alertable.id ], app_ids(mails.first)
    end
    assert_equal [ nil ] * others.size, others.map { |app| app.reload.notified_at }
    assert_equal old.to_i, notified.reload.notified_at.to_i
  end

  test "a user with no alertable applications gets no mail" do
    make_user
    done = make_application(make_user, 1, notified_at: 1.day.ago)
    before = done.reload.notified_at
    log = nil

    with_mailer do |mails, _deliveries|
      log = run_job("daily")
      assert_empty mails
    end
    assert_equal before, done.reload.notified_at
    assert_includes log, "SendAlertsJob daily: emailed 0 users"
  end

  test "each user gets their own mail with their own applications" do
    first = make_user
    second = make_user
    first_apps = [ make_application(first, 1), make_application(first, 2) ]
    second_apps = [ make_application(second, 1) ]
    paused = make_application(make_user("paused"), 1)

    with_mailer do |mails, _deliveries|
      run_job("daily")
      by_user = mails.to_h { |user, apps| [ user.id, apps.map(&:id) ] }
      assert_equal({ first.id => first_apps.reverse.map(&:id), second.id => second_apps.map(&:id) }, by_user)
    end
    assert((first_apps + second_apps).all? { |app| app.reload.notified_at })
    assert_nil paused.reload.notified_at
  end

  test "notified_at is set to about now" do
    app = make_application(make_user, 1)
    with_mailer { |_mails, _deliveries| run_job("daily") }

    assert_in_delta Time.current.to_f, app.reload.notified_at.to_f, 5
  end

  test "a failing user does not stop the others" do
    bad = make_user
    good = make_user
    bad_app = make_application(bad, 1)
    good_app = make_application(good, 1)
    log = nil

    with_mailer(fail_for: bad.email) do |mails, deliveries|
      log = run_job("daily")
      assert_equal [ good.id ], user_ids(mails)
      assert_equal [ good.id ], deliveries
    end
    assert_nil bad_app.reload.notified_at
    assert_not_nil good_app.reload.notified_at
    assert_includes log, "user_id=#{bad.id} error=RuntimeError"
    assert_not_includes log, "boom secret"
  end

  test "the info log says how many users were emailed" do
    2.times { make_application(make_user, 1) }
    make_user
    daily_log = weekly_log = nil

    with_mailer do |_mails, _deliveries|
      daily_log = run_job("daily")
      weekly_log = run_job("weekly")
    end
    assert_includes daily_log, "SendAlertsJob daily: emailed 2 users"
    assert_includes weekly_log, "SendAlertsJob weekly: emailed 0 users"
  end

  test "with the real mailer one mail is enqueued and nothing is delivered" do
    app = make_application(make_user, 1)

    SendAlertsJob.perform_now("daily")

    assert_enqueued_jobs 1, only: ActionMailer::MailDeliveryJob
    assert_not_nil app.reload.notified_at
  end
end
