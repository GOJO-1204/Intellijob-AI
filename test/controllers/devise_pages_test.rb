require "test_helper"

class DevisePagesTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def assert_field(name, type)
    assert_select "form input[type='#{type}'][name='user[#{name}]']"
  end

  def signed_in_user
    user = User.create!(email: "d#{SecureRandom.hex(4)}@example.com", password: "password123")
    sign_in user
    user
  end

  test "sign in page shows the form and links" do
    get new_user_session_path
    assert_response :success
    assert_select "h1", "Log in"
    assert_field :email, "email"
    assert_field :password, "password"
    assert_field :remember_me, "checkbox"
    assert_select "form input[type='submit'][value='Log in']"
    assert_select "a[href=?]", new_user_registration_path, "Sign up"
    assert_select "a[href=?]", new_user_password_path, "Forgot your password?"
  end

  test "sign up page shows the form" do
    get new_user_registration_path
    assert_response :success
    assert_select "h1", "Sign up"
    assert_field :email, "email"
    assert_field :password, "password"
    assert_field :password_confirmation, "password"
    assert_select "p", /characters minimum/
    assert_select "form input[type='submit'][value='Sign up']"
    assert_select "a[href=?]", new_user_session_path, "Log in"
  end

  test "sign up with empty fields shows the error box" do
    post user_registration_path, params: { user: { email: "", password: "", password_confirmation: "" } }
    assert_response :unprocessable_entity
    assert_select "#error_explanation[role='alert'] li", minimum: 1
  end

  test "forgot password page shows the form" do
    get new_user_password_path
    assert_response :success
    assert_select "h1", "Forgot your password?"
    assert_field :email, "email"
    assert_select "form input[type='submit'][value='Send me password reset instructions']"
    assert_select "a[href=?]", new_user_session_path, "Log in"
  end

  test "change password page shows the token and both fields" do
    get edit_user_password_path(reset_password_token: "sometoken")
    assert_response :success
    assert_select "h1", "Change your password"
    assert_select "input[type='hidden'][name='user[reset_password_token]'][value='sometoken']"
    assert_field :password, "password"
    assert_field :password_confirmation, "password"
    assert_select "form input[type='submit'][value='Change my password']"
  end

  test "edit account requires sign in" do
    get edit_user_registration_path
    assert_redirected_to new_user_session_path
  end

  test "edit account page shows the fields and the cancel form" do
    user = signed_in_user
    get edit_user_registration_path
    assert_response :success
    assert_select "input[name='user[email]'][value=?]", user.email
    assert_field :password, "password"
    assert_field :password_confirmation, "password"
    assert_field :current_password, "password"
    assert_select "form input[type='submit'][value='Update']"
    assert_select "h2", "Cancel my account"
    assert_select "form input[name='_method'][value='delete']"
  end
end
