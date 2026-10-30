require "test_helper"

class LayoutTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "head links the brand icons" do
    get privacy_path
    assert_select "link[rel=icon][href=?]", "/favicon.ico"
    assert_select "link[rel=icon][href=?]", "/favicon.svg"
    assert_select "link[rel=apple-touch-icon][href=?]", "/apple-touch-icon.png"
  end

  test "footer links to privacy and terms on a public page" do
    get privacy_path
    assert_select "footer a[href=?]", privacy_path, text: "Privacy"
    assert_select "footer a[href=?]", terms_path, text: "Terms"
  end

  test "footer also shows for a signed in user" do
    sign_in User.create!(email: "layout@example.com", password: "password123")
    get dashboard_path
    assert_response :success
    assert_select "footer a[href=?]", privacy_path
    assert_select "footer a[href=?]", terms_path
  end
end
