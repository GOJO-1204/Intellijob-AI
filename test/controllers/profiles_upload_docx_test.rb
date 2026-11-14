require "test_helper"
require "zip"

class ProfilesUploadDocxTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  DOCX = Profile::RESUME_TYPES.last

  def sample_parts
    parts = {}
    Zip::File.open(Rails.root.join("test/fixtures/files/sample.docx").to_s) do |zip|
      zip.each { |entry| parts[entry.name] = entry.get_input_stream.read }
    end
    parts
  end

  def docx_with_extra_xml(bytes)
    parts = sample_parts
    para = "<w:p><w:r><w:t>Ruby Rails developer</w:t></w:r></w:p>"
    extra = para * (bytes / para.bytesize)
    parts["word/document.xml"] = parts["word/document.xml"].sub("<w:body>") { "<w:body>" + extra }
    Zip::OutputStream.write_buffer do |zip|
      parts.each do |name, body|
        zip.put_next_entry(name)
        zip.write(body)
      end
    end.string
  end

  def sign_in_new_user
    User.create!(email: "d#{SecureRandom.hex(4)}@example.com", password: "password123").tap { |u| sign_in u }
  end

  test "the real sample DOCX is accepted" do
    user = sign_in_new_user
    post profile_path, params: { profile: { resume: fixture_file_upload("sample.docx", DOCX, true) } }
    assert_redirected_to profile_path
    assert user.profile.reload.resume_text.present?
  end

  test "a small DOCX that opens to over 1 MB of XML is refused and leaves no file" do
    user = sign_in_new_user
    blobs = ActiveStorage::Blob.count
    file = Rack::Test::UploadedFile.new(StringIO.new(docx_with_extra_xml(1_100_000)), DOCX, original_filename: "cv.docx")
    assert_no_enqueued_jobs { post profile_path, params: { profile: { resume: file } } }
    assert_response :unprocessable_entity
    assert_includes response.body, "That file has too much content. Please upload a normal resume."
    assert_nil user.profile.reload.resume_text
    assert_not user.profile.resume.attached?
    assert_equal blobs, ActiveStorage::Blob.count
  end
end
