require "test_helper"

class ProfilesUploadSizeTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "a PDF of exactly 5 MB is refused with the size message and leaves no file" do
    user = User.create!(email: "z#{SecureRandom.hex(4)}@example.com", password: "password123")
    sign_in user
    blobs = ActiveStorage::Blob.count
    bytes = ("%PDF-1.4\n".b + ("a" * Profile::MAX_RESUME_SIZE)).byteslice(0, Profile::MAX_RESUME_SIZE)
    file = Rack::Test::UploadedFile.new(StringIO.new(bytes), "application/pdf", original_filename: "big.pdf")
    assert_no_enqueued_jobs { post profile_path, params: { profile: { resume: file } } }
    assert_response :unprocessable_entity
    assert_includes response.body, "Resume must be under 5 MB"
    assert_nil user.profile.reload.resume_text
    assert_not user.profile.resume.attached?
    assert_equal blobs, ActiveStorage::Blob.count
  end
end
