require "test_helper"

class ResumeParserTest < ActiveSupport::TestCase
  def attachment(name, type)
    profile = User.create!(email: "parser@example.com", password: "password123").profile
    profile.resume.attach(io: file_fixture(name).open, filename: name, content_type: type)
    profile.resume
  end

  def fake(type, data)
    blob = Struct.new(:content_type).new(type)
    Struct.new(:blob, :data) { def attached? = true; def download = data }.new(blob, data)
  end

  test "reads text from a PDF" do
    text = ResumeParser.call(attachment("sample.pdf", "application/pdf"))
    assert_includes text, "JANE SAMPLE"
  end

  test "reads text from a DOCX" do
    type = "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
    text = ResumeParser.call(attachment("sample.docx", type))
    assert_includes text, "Ruby, Rails, SQL"
  end

  test "raises when there is no file" do
    error = assert_raises(ResumeParser::Error) { ResumeParser.call(nil) }
    assert_equal "Please upload your resume.", error.message
  end

  test "raises for an unsupported file type" do
    error = assert_raises(ResumeParser::Error) { ResumeParser.call(fake("text/plain", "hello")) }
    assert_equal "Please upload a PDF or DOCX file.", error.message
  end

  test "raises for a corrupt file" do
    error = assert_raises(ResumeParser::Error) { ResumeParser.call(fake("application/pdf", "not a pdf")) }
    assert_equal "We couldn't read that file. It may be corrupt.", error.message
  end
end
