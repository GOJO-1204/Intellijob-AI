require "test_helper"

class NotesLinebreaksTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  TURBO = { "Accept" => "text/vnd.turbo-stream.html" }.freeze

  def signed_in_record
    user = User.create!(email: "n#{SecureRandom.hex(4)}@example.com", password: "password123")
    job = Job.create!(title: "Dev", company: "Acme", description: "Ruby",
                      url: "https://example.com/#{SecureRandom.hex(6)}")
    sign_in user
    user.job_applications.create!(job: job)
  end

  def save_note(record, text)
    patch job_application_path(record),
          params: { job_application: { notes: text } }, headers: TURBO
  end

  # 10 lines of 49 letters, each followed by one line break.
  def note_with(line_break)
    ("a" * 49 + line_break) * 10
  end

  test "a note with LF line breaks and 500 characters is saved" do
    record = signed_in_record
    note = note_with("\n")
    assert_equal 500, note.length
    save_note(record, note)
    assert_response :success
    assert_equal 500, record.reload.notes.length
  end

  test "the same note with CRLF line breaks is stored with LF and saved" do
    record = signed_in_record
    note = note_with("\r\n")
    assert_equal 510, note.length
    save_note(record, note)
    assert_response :success
    saved = record.reload.notes
    assert_equal 500, saved.length
    assert_not_includes saved, "\r"
  end

  test "a CRLF note of 501 characters after normalizing is still refused" do
    record = signed_in_record
    note = note_with("\r\n") + "a"
    assert_equal 511, note.length
    save_note(record, note)
    assert_response :unprocessable_entity
    assert_nil record.reload.notes
  end
end
