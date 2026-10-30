require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "privacy page is public and shows its heading" do
    get privacy_path
    assert_response :success
    assert_select "h1", "Privacy Policy"
  end

  test "terms page is public and shows its heading" do
    get terms_path
    assert_response :success
    assert_select "h1", "Terms of Use"
  end

  test "a signed in user can open both pages without a redirect" do
    user = User.create!(email: "pages@example.com", password: "password123")
    sign_in user

    get privacy_path
    assert_response :success
    get terms_path
    assert_response :success
  end

  test "both pages link back to the home page" do
    [ privacy_path, terms_path ].each do |path|
      get path
      assert_select "div a[href=?]", root_path, text: "Go to the home page"
    end
  end
end
