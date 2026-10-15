require "test_helper"

require "test_helper"

class ProfileTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email: "a@example.com", password: "password123")
    @profile = @user.profile
  end

  test "ready_for_matching? needs resume_text and target_role" do
    assert_not @profile.ready_for_matching?
    @profile.assign_attributes(resume_text: "Ruby dev", target_role: "Backend")
    assert @profile.ready_for_matching?
  end

  test "ready scope returns only complete profiles" do
    @profile.update!(resume_text: "Ruby dev", target_role: "Backend")
    other = User.create!(email: "b@example.com", password: "password123").profile

    assert_includes Profile.ready, @profile
    assert_not_includes Profile.ready, other
  end

  test "embedding_text joins role, skills and resume text" do
    @profile.assign_attributes(target_role: "Dev", target_skills: %w[ruby sql], resume_text: "Resume")
    assert_equal "Dev\nruby, sql\nResume", @profile.embedding_text
  end

  test "accepts a PDF resume" do
    @profile.resume = { io: StringIO.new("%PDF-1.4 test"), filename: "cv.pdf", content_type: "application/pdf" }
    assert @profile.valid?
  end

  test "rejects a non PDF/DOCX resume" do
    @profile.resume = { io: StringIO.new("hello"), filename: "cv.txt", content_type: "text/plain" }
    assert_not @profile.valid?
    assert_includes @profile.errors[:resume], "must be a PDF or DOCX file"
  end

  test "rejects a resume of 5 MB or more" do
    big = "%PDF-1.4 " + ("a" * Profile::MAX_RESUME_SIZE)
    @profile.resume = { io: StringIO.new(big), filename: "big.pdf", content_type: "application/pdf" }
    assert_not @profile.valid?
    assert_includes @profile.errors[:resume], "must be under 5 MB"
  end
end
