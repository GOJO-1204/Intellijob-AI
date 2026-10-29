require "test_helper"

class ProfilesReuploadTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def new_user
    User.create!(email: "t#{SecureRandom.hex(4)}@example.com", password: "password123").tap { |u| sign_in u }
  end

  def user_with_results
    user = new_user
    File.open(file_fixture("sample.pdf"), "rb") do |io|
      user.profile.resume.attach(io: io, filename: "old.pdf", content_type: "application/pdf")
    end
    user.profile.update!(resume_text: "old text", ats_score: 70, ats_feedback: { checks: [], shortcomings: [] },
                         ai_suggestions: [ { original: "a", improved: "b", why: "c" } ], embedding: [ 0.1, 0.2 ])
    user
  end

  def upload
    post profile_path, params: { profile: { resume: fixture_file_upload("sample.pdf", "application/pdf", true) } }
  end

  test "a second upload clears the old results and the page polls again" do
    user = user_with_results
    upload
    assert_redirected_to profile_path
    profile = user.profile.reload
    assert_nil profile.ats_score
    assert_equal [], profile.ai_suggestions
    assert_nil profile.embedding
    assert_not_equal "old text", profile.resume_text
    assert_enqueued_with(job: ResumeAnalysisJob, args: [ profile.id ])
    assert_enqueued_with(job: EmbedRecordsJob)
    follow_redirect!
    assert_select "p", /Analyzing your resume/
    assert_select "[data-analysis-poll]", 1
  end

  test "a first upload also queues the embedding job" do
    new_user
    upload
    assert_enqueued_with(job: EmbedRecordsJob)
  end

  test "a failed parse keeps the old file, text and results" do
    user = user_with_results
    blobs = ActiveStorage::Blob.count
    attachments = ActiveStorage::Attachment.count
    original = ResumeParser.method(:call)
    ResumeParser.define_singleton_method(:call) { |_attachment| raise ResumeParser::Error, "We couldn't read that file." }
    assert_no_enqueued_jobs { upload }
    assert_response :unprocessable_entity
    profile = user.profile.reload
    assert_equal "old text", profile.resume_text
    assert_equal 70, profile.ats_score
    assert_equal 1, profile.ai_suggestions.size
    assert_equal "old.pdf", profile.resume.filename.to_s
    assert_equal blobs, ActiveStorage::Blob.count
    assert_equal attachments, ActiveStorage::Attachment.count
  ensure
    ResumeParser.define_singleton_method(:call, original)
  end
end
