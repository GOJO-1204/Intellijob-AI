require "test_helper"

class ProfilesUploadSafetyTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def refused_upload(bytes, type, name)
    user = User.create!(email: "s#{SecureRandom.hex(4)}@example.com", password: "password123")
    sign_in user
    blobs = ActiveStorage::Blob.count
    file = Rack::Test::UploadedFile.new(StringIO.new(bytes), type, original_filename: name)
    assert_no_enqueued_jobs { post profile_path, params: { profile: { resume: file } } }
    assert_response :unprocessable_entity
    assert_nil user.profile.reload.resume_text
    assert_not user.profile.resume.attached?
    assert_equal blobs, ActiveStorage::Blob.count
  end

  test "an exe renamed to pdf is refused and leaves no file" do
    exe = "MZ\x90\x00\x03\x00\x00\x00This program cannot be run in DOS mode.".b
    refused_upload(exe, "application/pdf", "resume.pdf")
  end

  test "a zero byte PDF is refused and leaves no file" do
    refused_upload("".b, "application/pdf", "resume.pdf")
  end

  test "a zero byte DOCX is refused and leaves no file" do
    refused_upload("".b, Profile::RESUME_TYPES.last, "resume.docx")
  end

  test "random bytes named docx are refused and leave no file" do
    refused_upload(Random.bytes(2000), Profile::RESUME_TYPES.last, "resume.docx")
  end
end
