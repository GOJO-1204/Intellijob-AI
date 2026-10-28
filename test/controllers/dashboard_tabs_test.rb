require "test_helper"

class DashboardTabsTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def new_user
    User.create!(email: "t#{SecureRandom.hex(4)}@example.com", password: "password123")
  end

  def app_for(user, status)
    job = Job.create!(title: "Dev", company: "Acme", description: "Ruby",
                      url: "https://example.com/#{SecureRandom.hex(6)}")
    user.job_applications.create!(job: job, status: status)
  end

  test "the default tab is saved" do
    me = new_user
    saved = app_for(me, "saved")
    applied = app_for(me, "applied")
    sign_in me
    get dashboard_path
    assert_select "li#job_application_#{saved.id}"
    assert_select "li#job_application_#{applied.id}", false
  end

  test "params status picks the tab and marks it current" do
    me = new_user
    saved = app_for(me, "saved")
    applied = app_for(me, "applied")
    sign_in me
    get dashboard_path(status: "applied")
    assert_select "li#job_application_#{applied.id}"
    assert_select "li#job_application_#{saved.id}", false
    assert_select "a[aria-current=page]", text: /Applied/
  end

  test "unknown or matched status falls back to saved without an error" do
    me = new_user
    saved = app_for(me, "saved")
    sign_in me
    [ "bogus", "matched", "" ].each do |value|
      get dashboard_path(status: value)
      assert_response :success
      assert_select "li#job_application_#{saved.id}"
    end
  end

  test "an array status falls back to saved" do
    sign_in new_user
    get dashboard_path, params: { status: [ "applied" ] }
    assert_response :success
    assert_select "a[aria-current=page]", text: /Saved/
  end

  test "another user's applications are never listed" do
    other = app_for(new_user, "saved")
    sign_in new_user
    get dashboard_path
    assert_select "li#job_application_#{other.id}", false
  end

  test "six tabs show real counts" do
    me = new_user
    2.times { app_for(me, "saved") }
    sign_in me
    get dashboard_path
    assert_select "nav[aria-label=?] a", "Application status", count: 6
    assert_select "nav[aria-label=?] a", "Application status", text: /Saved\s+2/
  end
end
