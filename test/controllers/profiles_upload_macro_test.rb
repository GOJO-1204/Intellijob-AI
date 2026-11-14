require "test_helper"
require "zip"

class ProfilesUploadMacroTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  DOCX = Profile::RESUME_TYPES.last
  MACRO = "application/vnd.ms-word.document.macroEnabled.12"

  def docx_with_macro_part
    parts = {}
    Zip::File.open(Rails.root.join("test/fixtures/files/sample.docx").to_s) do |zip|
      zip.each { |entry| parts[entry.name] = entry.get_input_stream.read }
    end
    parts["word/vbaProject.bin"] = "not real macro code".b
    Zip::OutputStream.write_buffer do |zip|
      parts.each { |name, body| zip.put_next_entry(name) && zip.write(body) }
    end.string
  end

  def upload_macro(type, name)
    user = User.create!(email: "m#{SecureRandom.hex(4)}@example.com", password: "password123")
    sign_in user
    file = Rack::Test::UploadedFile.new(StringIO.new(docx_with_macro_part), type, original_filename: name)
    post profile_path, params: { profile: { resume: file } }
    user
  end

  test "a DOCX with a macro part is read as text only" do
    user = upload_macro(DOCX, "cv.docx")
    assert_redirected_to profile_path
    assert user.profile.reload.resume_text.present?
    assert_not_includes user.profile.resume_text, "macro code"
  end

  test "a macro enabled document type is refused and leaves no file" do
    blobs = ActiveStorage::Blob.count
    user = upload_macro(MACRO, "cv.docm")
    assert_response :unprocessable_entity
    assert_includes response.body, "Resume must be a PDF or DOCX file"
    assert_nil user.profile.reload.resume_text
    assert_not user.profile.resume.attached?
    assert_equal blobs, ActiveStorage::Blob.count
  end
end
