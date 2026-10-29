require "test_helper"

class JobApplicationsNewTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def new_user
    User.create!(email: "t#{SecureRandom.hex(4)}@example.com", password: "password123")
  end

  def add(attrs = {})
    post job_applications_path, params: { job: {
      title: "Dev", company: "Acme", url: "https://example.com/a", status: "applied"
    }.merge(attrs) }
  end

  test "signed out is sent to sign in and nothing is saved" do
    assert_no_difference [ "Job.count", "JobApplication.count" ] do
      add
    end
    assert_redirected_to new_user_session_path
    get new_job_application_path
    assert_redirected_to new_user_session_path
  end

  test "the form page loads" do
    sign_in new_user
    get new_job_application_path
    assert_response :success
    assert_select "form[action=?]", job_applications_path
  end

  test "each allowed status is saved with a manual job" do
    me = new_user
    sign_in me
    ManualJobAdder::STATUSES.each_with_index do |status, i|
      add(url: "https://example.com/s#{i}", status: status)
      assert_redirected_to dashboard_path(status: status)
      record = me.job_applications.find_by!(status: status)
      assert_equal "manual", record.job.source
    end
  end

  test "applied sets applied_at and saved does not" do
    me = new_user
    sign_in me
    add(url: "https://example.com/x1", status: "applied")
    add(url: "https://example.com/x2", status: "saved")
    assert me.job_applications.find_by!(status: "applied").applied_at
    assert_nil me.job_applications.find_by!(status: "saved").applied_at
  end

  test "matched, dismissed and unknown statuses are refused" do
    sign_in new_user
    %w[matched dismissed bogus].each do |status|
      assert_no_difference [ "Job.count", "JobApplication.count" ] do
        add(status: status)
      end
      assert_response :unprocessable_entity
    end
  end

  test "bad or blank urls are refused" do
    sign_in new_user
    [ "", "javascript:alert(1)", "ftp://example.com/a", "not a url", "https://" ].each do |url|
      assert_no_difference [ "Job.count", "JobApplication.count" ] do
        add(url: url)
      end
      assert_response :unprocessable_entity
    end
  end

  test "a blank title or company is refused" do
    sign_in new_user
    assert_no_difference "Job.count" do
      add(title: " ")
      add(company: "")
    end
    assert_response :unprocessable_entity
  end

  test "a duplicate for the same user is refused and leaves one record" do
    me = new_user
    sign_in me
    add
    assert_no_difference [ "Job.count", "JobApplication.count" ] do
      add(title: "Other title")
    end
    assert_response :unprocessable_entity
    assert_includes response.body, "already have this job"
  end

  test "another user can add the same url and the job is not changed" do
    add_for_first = new_user
    sign_in add_for_first
    add
    job = Job.find_by!(url: "https://example.com/a")
    sign_out add_for_first
    second = new_user
    sign_in second
    assert_difference "JobApplication.count", 1 do
      assert_no_difference "Job.count" do
        add(title: "Changed", company: "Other")
      end
    end
    assert_equal job, second.job_applications.first.job
    assert_equal [ "Dev", "Acme" ], [ job.reload.title, job.company ]
  end

  test "an existing job from another source is reused and not changed" do
    existing = Job.create!(title: "Real", company: "Co", url: "https://example.com/a", source: "remotive")
    me = new_user
    sign_in me
    add(title: "Changed")
    assert_equal existing, me.job_applications.first.job
    assert_equal [ "Real", "remotive" ], [ existing.reload.title, existing.source ]
  end

  test "the Job added message is shown after the redirect" do
    sign_in new_user
    add
    follow_redirect!
    assert_response :success
    assert_includes response.body, "Job added."
  end
  test "output is escaped" do
    sign_in new_user
    add(title: "<script>x</script>", url: "bad")
    assert_includes response.body, "&lt;script&gt;"
    assert_not_includes response.body, "<script>x</script>"
  end
end
