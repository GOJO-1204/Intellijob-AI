require "test_helper"

class InlineNotesTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  TURBO = { "Accept" => "text/vnd.turbo-stream.html" }.freeze

  def new_user
    User.create!(email: "t#{SecureRandom.hex(4)}@example.com", password: "password123")
  end

  def app_for(user, status: "matched", notes: nil)
    job = Job.create!(title: "Dev", company: "Acme", description: "Ruby",
                      url: "https://example.com/#{SecureRandom.hex(6)}")
    user.job_applications.create!(job: job, status: status, notes: notes)
  end

  def save_note(record, text)
    patch job_application_path(record),
          params: { job_application: { notes: text } }, headers: TURBO
  end

  test "saving a note stores it and shows it with Saved." do
    me = new_user
    record = app_for(me)
    sign_in me
    save_note(record, "Call on Monday")
    assert_response :success
    assert_equal "Call on Monday", record.reload.notes
    assert_includes response.body, "Call on Monday"
    assert_includes response.body, "Saved."
  end

  test "saving only a note leaves the status unchanged" do
    me = new_user
    record = app_for(me)
    sign_in me
    save_note(record, "Hello")
    assert_equal "matched", record.reload.status
  end

  test "another user's application cannot get a note" do
    other = app_for(new_user)
    sign_in new_user
    save_note(other, "Mine now")
    assert_response :not_found
    assert_nil other.reload.notes
  end

  test "a note with HTML is shown escaped" do
    me = new_user
    record = app_for(me)
    sign_in me
    save_note(record, "<script>alert(1)</script>")
    assert_includes response.body, "&lt;script&gt;alert(1)&lt;/script&gt;"
    assert_not_includes response.body, "<script>alert(1)</script>"
  end

  test "the dashboard card shows the saved note" do
    me = new_user
    app_for(me, status: "saved", notes: "Call on Monday")
    sign_in me
    get dashboard_path
    assert_select "p.whitespace-pre-line", "Call on Monday"
    assert_select "summary", text: /Edit note/
  end
end
