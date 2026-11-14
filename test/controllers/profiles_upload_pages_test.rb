require "test_helper"

class ProfilesUploadPagesTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def pdf_with_pages(count)
    objs = [ "<< /Type /Catalog /Pages 2 0 R >>" ]
    kids = (0...count).map { |i| "#{4 + 2 * i} 0 R" }.join(" ")
    objs << "<< /Type /Pages /Kids [#{kids}] /Count #{count} >>"
    objs << "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>"
    count.times do |i|
      objs << "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 200 200] " \
              "/Resources << /Font << /F1 3 0 R >> >> /Contents #{5 + 2 * i} 0 R >>"
      text = "BT /F1 12 Tf 20 100 Td (Page #{i + 1} Ruby Rails) Tj ET"
      objs << "<< /Length #{text.bytesize} >>\nstream\n#{text}\nendstream"
    end
    out = +"%PDF-1.4\n"
    offsets = objs.each_with_index.map do |body, i|
      out.bytesize.tap { out << "#{i + 1} 0 obj\n#{body}\nendobj\n" }
    end
    start = out.bytesize
    out << "xref\n0 #{objs.size + 1}\n0000000000 65535 f \n"
    offsets.each { |o| out << format("%010d 00000 n \n", o) }
    out << "trailer\n<< /Size #{objs.size + 1} /Root 1 0 R >>\nstartxref\n#{start}\n%%EOF\n"
  end

  def upload_pages(count)
    user = User.create!(email: "p#{SecureRandom.hex(4)}@example.com", password: "password123")
    sign_in user
    file = Rack::Test::UploadedFile.new(StringIO.new(pdf_with_pages(count)), "application/pdf", original_filename: "cv.pdf")
    post profile_path, params: { profile: { resume: file } }
    user
  end

  test "a PDF with 5 pages is accepted" do
    user = upload_pages(5)
    assert_redirected_to profile_path
    assert_includes user.profile.reload.resume_text, "Ruby"
  end

  test "a PDF with 6 pages is refused and leaves no file" do
    blobs = ActiveStorage::Blob.count
    user = nil
    assert_no_enqueued_jobs { user = upload_pages(6) }
    assert_response :unprocessable_entity
    assert_includes response.body, "Please upload a resume of 5 pages or fewer."
    assert_nil user.profile.reload.resume_text
    assert_not user.profile.resume.attached?
    assert_equal blobs, ActiveStorage::Blob.count
  end
end
