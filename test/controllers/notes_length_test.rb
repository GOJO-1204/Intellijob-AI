require "test_helper"

class NotesLengthTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  TURBO = { "Accept" => "text/vnd.turbo-stream.html" }.freeze

  def new_user
    User.create!(email: "t#{SecureRandom.hex(4)}@example.com", password: "password123")
  end

  def app_for(user, notes: nil)
    job = Job.create!(title: "Dev", company: "Acme", description: "Ruby",
                      url: "https://example.com/#{SecureRandom.hex(6)}")
    user.job_applications.create!(job: job, notes: notes)
  end

  def save_note(record, text, headers: TURBO)
    patch job_application_path(record),
          params: { job_application: { notes: text } }, headers: headers
  end

  test "a note of exactly 500 characters is saved" do
    me = new_user
    record = app_for(me)
    sign_in me
    save_note(record, "a" * 500)
    assert_response :success
    assert_equal 500, record.reload.notes.length
  end

  test "a note of 501 characters is refused and the old note stays" do
    me = new_user
    record = app_for(me, notes: "Old note")
    sign_in me
    save_note(record, "a" * 501)
    assert_response :unprocessable_entity
    assert_equal "Old note", record.reload.notes
    assert_includes response.body, "Use 500 characters or fewer."
    assert_includes response.body, "Old note"
    assert_not_includes response.body, "Saved."
  end

  test "a too long note over html is refused without an error page" do
    me = new_user
    record = app_for(me)
    sign_in me
    save_note(record, "a" * 501, headers: {})
    assert_response :unprocessable_entity
    assert_nil record.reload.notes
  end

  test "dismiss still removes the card" do
    me = new_user
    record = app_for(me, notes: "Keep")
    sign_in me
    patch job_application_path(record),
          params: { job_application: { status: "dismissed" } }, headers: TURBO
    assert_response :success
    assert_includes response.body, 'action="remove"'
    assert_equal "dismissed", record.reload.status
  end
end
