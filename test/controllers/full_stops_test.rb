require "test_helper"

class FullStopsTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def signed_in_user
    user = User.create!(email: "f#{SecureRandom.hex(4)}@example.com", password: "password123")
    sign_in user
    user
  end

  test "an upload error ends with a full stop" do
    signed_in_user
    txt = Rack::Test::UploadedFile.new(StringIO.new("hello"), "text/plain", original_filename: "cv.txt")
    post profile_path, params: { profile: { resume: txt } }
    assert_response :unprocessable_entity
    assert_select "div", /Resume must be a PDF or DOCX file\.\s*\z/
  end

  test "a preferences error ends with a full stop" do
    user = signed_in_user
    user.profile.update!(resume_text: "Ruby developer")
    patch preferences_path, params: { profile: { target_role: "", alert_frequency: "daily" } }
    assert_response :unprocessable_entity
    assert_select "div", /Target role can't be blank\.\s*\z/
  end
end
