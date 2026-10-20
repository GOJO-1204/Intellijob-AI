require "test_helper"

class ProfilesUploadTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def signed_in_user
    User.create!(email: "t#{SecureRandom.hex(4)}@example.com", password: "password123").tap { |u| sign_in u }
  end

  def upload(file)
    post profile_path, params: { profile: { resume: file } }
  end

  test "create requires sign in" do
    upload(fixture_file_upload("sample.pdf", "application/pdf", true))
    assert_redirected_to new_user_session_path
  end

  test "no file shows an error" do
    signed_in_user
    post profile_path
    assert_response :unprocessable_entity
    assert_includes response.body, "Please choose a resume file."
  end

  test "an unsupported file type is refused and nothing is enqueued" do
    user = signed_in_user
    txt = Rack::Test::UploadedFile.new(StringIO.new("hello"), "text/plain", original_filename: "cv.txt")
    assert_no_enqueued_jobs { upload(txt) }
    assert_response :unprocessable_entity
        assert_includes response.body, "Resume must be a PDF or DOCX file"
    assert_nil user.profile.reload.resume_text
  end

  test "a valid PDF saves the text and enqueues the analysis" do
    user = signed_in_user
    upload(fixture_file_upload("sample.pdf", "application/pdf", true))
    assert_redirected_to profile_path
    assert user.profile.reload.resume_text.present?
    assert_enqueued_with(job: ResumeAnalysisJob, args: [ user.profile.id ])
  end

    test "a PDF without readable text sends the user back to upload" do
    original = ResumeParser.method(:call)
    ResumeParser.define_singleton_method(:call) { |_attachment| "" }
    signed_in_user
    upload(fixture_file_upload("sample.pdf", "application/pdf", true))
    follow_redirect!
    assert_redirected_to new_profile_path
  ensure
    ResumeParser.define_singleton_method(:call, original)
  end
end
