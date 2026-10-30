require "test_helper"

class JobAlertMailerTest < ActionMailer::TestCase
  UNSUBSCRIBE_URL = %r{/unsubscribe/([^"\s<]+)}

  setup do
    @user = User.create!(email: "mailer-test@example.com", password: "password123")
  end

  test "subject and recipient" do
    mail = build_mail(
      create_application("https://example.com/jobs/1"),
      create_application("https://example.com/jobs/2")
    )

    assert_equal "2 new job matches for you", mail.subject
    assert_equal [ @user.email ], mail.to
  end

  test "unsubscribe link is a signed token that finds the user" do
    mail = build_mail(create_application("https://example.com/jobs/1"))

    bodies(mail).each do |body|
      assert_match UNSUBSCRIBE_URL, body
      token = body[UNSUBSCRIBE_URL, 1]
      assert_equal @user, User.find_signed(token, purpose: :unsubscribe)
    end
  end

  test "company and location are separated by a comma" do
    text, html = bodies(build_mail(create_application("https://example.com/jobs/1")))

    assert_includes text, "Acme, Pune"
    assert_includes html, "Acme, Pune"
    assert_not_includes text, "Acme - Pune"
    assert_not_includes html, "Acme - Pune"
  end

  test "blank location leaves no separator after the company" do
    text, _html = bodies(build_mail(create_application("https://example.com/jobs/1", location: nil)))

    assert_not_includes text, "Acme,"
    assert_not_includes text, "Acme -"
  end

  test "APPLY only for http and https urls" do
    mail = build_mail(
      create_application("https://example.com/jobs/1"),
      create_application("http://example.com/jobs/2"),
      create_application("javascript:alert(1)")
    )
    text, html = bodies(mail)

    assert_equal 2, html.scan("APPLY").size
    assert_equal 2, text.scan("APPLY:").size
    assert_not_includes text, "javascript:"
    assert_not_includes html, "javascript:"
  end

  test "html part follows the design rules" do
    _text, html = bodies(build_mail(create_application("https://example.com/jobs/1")))

    assert_match(/#0F766E/i, html)
    assert_no_match(/#2563eb/i, html)
    assert_no_match(/gradient/i, html)
  end

  test "html part has no spaced hyphen inside any text node" do
    _text, html = bodies(build_mail(create_application("https://example.com/jobs/1")))

    assert_no_match(%r{>[^<]* - [^<]*<}, html)
  end

  private

  def create_application(url, company: "Acme", location: "Pune")
    job = Job.create!(
      title: "Ruby Developer", company: company, url: url,
      location: location, source: "seed", posted_at: Time.current
    )
    JobApplication.create!(user: @user, job: job, status: "matched", score: 0.82)
  end

  def build_mail(*applications)
    JobAlertMailer.new_matches(@user, applications)
  end

  # Returns [ text, html ] bodies.
  def bodies(mail)
    [ mail.text_part.body.decoded, mail.html_part.body.decoded ]
  end
end
