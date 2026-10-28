require "test_helper"

class ProfilesPollingTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def profile_with(attrs)
    user = User.create!(email: "t#{SecureRandom.hex(4)}@example.com", password: "password123")
    sign_in user
    profile = user.profile
    File.open(file_fixture("sample.pdf"), "rb") do |io|
      profile.resume.attach(io: io, filename: "sample.pdf", content_type: "application/pdf")
    end
    profile.update!({ resume_text: "x", ats_score: 70, ats_feedback: { checks: [], shortcomings: [] } }.merge(attrs))
  end

  test "the page polls while the tips are pending and stops after 90 seconds" do
    profile_with({})
    get profile_path
    assert_select "h2", text: "AI writing tips"
    assert_select "[data-analysis-poll]", 1

    travel 91.seconds do
      get profile_path
      assert_select "[data-analysis-poll]", 0
      assert_select "a[href=?]", profile_path, text: "Refresh"
    end
  end

  test "the page does not poll once the AI tips exist" do
    profile_with(ai_suggestions: [ { original: "Did stuff", improved: "Led a team of 4", why: "Specific" } ])
    get profile_path
    assert_select "[data-analysis-poll]", 0
    assert_select "a", text: "Refresh", count: 0
    assert_includes response.body, "Led a team of 4"
  end
end
