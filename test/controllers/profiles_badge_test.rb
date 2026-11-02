require "test_helper"

class ProfilesBadgeTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def show_with(checks, score)
    user = User.create!(email: "b#{SecureRandom.hex(4)}@example.com", password: "password123")
    sign_in user
    user.profile.update!(resume_text: "x", ats_score: score, ats_feedback: { checks: checks, shortcomings: [] })
    get profile_path
    assert_response :success
  end

  def assert_bar(name, color, width)
    assert_select "[role='progressbar'][aria-label='#{name}'] div.#{color}[style='width: #{width}%']"
  end

  [ [ 100, "Strong", "bg-green-600" ], [ 70, "Strong", "bg-green-600" ], [ 69, "Fair", "bg-amber-500" ],
    [ 40, "Fair", "bg-amber-500" ], [ 39, "Weak", "bg-red-600" ], [ 0, "Weak", "bg-red-600" ] ].each do |score, word, color|
    test "badge and bar for #{score} out of 100 are #{word}" do
      show_with([ { name: "Edge", score: score, max: 100 } ], score)
      assert_select "span.rounded-md", count: 1, text: word
      assert_bar "Edge", color, score
    end
  end

  test "a check with max 0 is Not rated and has an empty gray bar" do
    show_with([ { name: "Empty", score: 0, max: 0 } ], 0)
    assert_select "span.rounded-md", count: 1, text: "Not rated"
    assert_select "[role='progressbar'][aria-label='Empty'][aria-valuemax='0']"
    assert_bar "Empty", "bg-gray-500", 0
  end

  test "each check bar uses its own tone and the real width" do
    checks = [
      { name: "Contact details", score: 15, max: 15 },
      { name: "Section headings", score: 10, max: 20 },
      { name: "Bullet points", score: 0, max: 15 },
      { name: "Skills coverage", score: 20, max: 20 },
      { name: "Length", score: 7, max: 15 },
      { name: "ATS-safe formatting", score: 15, max: 15 }
    ]
    show_with(checks, 67)
    assert_select "span.rounded-md", count: 1, text: "Fair"
    assert_select "p span", "/ 100"
    assert_bar "Contact details", "bg-green-600", 100
    assert_bar "Section headings", "bg-amber-500", 50
    assert_bar "Bullet points", "bg-red-600", 0
    assert_bar "Skills coverage", "bg-green-600", 100
    assert_bar "Length", "bg-amber-500", 47
    assert_bar "ATS-safe formatting", "bg-green-600", 100
  end

  test "a score above max is capped at a full bar" do
    show_with([ { name: "Over", score: 20, max: 15 } ], 20)
    assert_bar "Over", "bg-green-600", 100
  end

  test "the total is the sum of the check maxes" do
    show_with([ { name: "A", score: 20, max: 20 }, { name: "B", score: 10, max: 40 } ], 30)
    assert_select "p span", "/ 60"
    assert_select "span.rounded-md", count: 1, text: "Fair"
    assert_bar "B", "bg-red-600", 25
  end
end
