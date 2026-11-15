require "test_helper"

class MatcherTest < ActiveSupport::TestCase
  def make_profile(attrs = {})
    user = User.create!(email: "matcher-#{SecureRandom.hex(4)}@example.com", password: "password123")
    base = { resume_text: "Ruby developer", target_role: "Backend", embedding: [ 1.0, 0.0 ] }
    user.profile.tap { |profile| profile.update!(base.merge(attrs)) }
  end

  def make_job(number, overrides = {})
    Job.create!({ url: "https://example.com/m/#{number}", title: "Job #{number}", company: "Acme",
                  posted_at: 1.day.ago, remote: true, source: "remotive", embedding: [ 1.0, 0.0 ] }.merge(overrides))
  end

  def ids(*jobs)
    jobs.map(&:id).sort
  end

  def matched_ids(profile)
    Matcher.call(profile).map { |job, _score| job.id }.sort
  end

  test "returns an empty list when the profile embedding is missing or not an array" do
    make_job(1)
    [ nil, [], { "a" => 1 } ].each do |value|
      assert_equal [], Matcher.call(make_profile(embedding: value)), value.inspect
    end
  end

  test "returns job and score pairs ranked by similarity" do
    low = make_job(1, embedding: [ 0.0, 1.0 ])
    top = make_job(2)
    mid = make_job(3, embedding: [ 1.0, 1.0 ])
    opposite = make_job(4, embedding: [ -1.0, 0.0 ])
    pairs = Matcher.call(make_profile)

    assert_equal [ top, mid, low, opposite ], pairs.map(&:first)
    assert_equal [ Float ], pairs.map { |_job, score| score.class }.uniq
    [ 1.0, Math.sqrt(0.5), 0.0, -1.0 ].zip(pairs.map(&:last)).each do |expected, score|
      assert_in_delta expected, score, 0.0001
    end
  end

  test "returns 20 results by default" do
    21.times { |index| make_job(index) }
    assert_equal 20, Matcher.call(make_profile).size
  end

  test "the limit option returns only the top results" do
    best = make_job(1)
    second = make_job(2, embedding: [ 1.0, 1.0 ])
    make_job(3, embedding: [ 0.0, 1.0 ])
    make_job(4, embedding: [ -1.0, 0.0 ])

    assert_equal [ best, second ], Matcher.call(make_profile, limit: 2).map(&:first)
  end

  test "skips jobs with no embedding or a vector of another length" do
    good = make_job(1)
    [ nil, [], [ 1.0 ], [ 1.0, 0.0, 0.0 ], { "a" => 1 } ].each_with_index do |value, index|
      make_job(index + 2, embedding: value)
    end

    assert_equal ids(good), matched_ids(make_profile)
  end

  test "only recent jobs are included" do
    fresh = make_job(1, posted_at: 29.days.ago)
    make_job(2, posted_at: 31.days.ago)
    make_job(3, posted_at: nil)

    assert_equal ids(fresh), matched_ids(make_profile)
  end

  test "excludes manual jobs and keeps other sources including nil" do
    no_source = make_job(1, source: nil)
    adzuna = make_job(2, source: "adzuna")
    make_job(3, source: "manual")

    assert_equal ids(no_source, adzuna), matched_ids(make_profile)
  end

  test "a remote profile gets only remote jobs" do
    remote = make_job(1)
    make_job(2, remote: false)
    make_job(3, remote: nil)

    assert_equal ids(remote), matched_ids(make_profile(remote: true))
  end

  test "a location matches case insensitively and remote jobs still appear" do
    pune = make_job(1, remote: false, location: "Pune, Maharashtra")
    remote = make_job(2, remote: true, location: "Berlin")
    make_job(3, remote: false, location: "Mumbai")

    assert_equal ids(pune, remote), matched_ids(make_profile(remote: false, location: "pune"))
  end

  test "a percent sign in the location is matched literally" do
    literal = make_job(1, remote: false, location: "Growth 100% Co")
    make_job(2, remote: false, location: "Pune")

    assert_equal ids(literal), matched_ids(make_profile(remote: false, location: "%"))
  end

  test "an underscore in the location is matched literally" do
    make_job(1, remote: false, location: "Pune")
    assert_empty Matcher.call(make_profile(remote: false, location: "P_ne"))
  end

  test "a non remote profile without a location is not filtered by location" do
    pune = make_job(1, remote: false, location: "Pune")
    mumbai = make_job(2, remote: false, location: "Mumbai")

    [ nil, "" ].each do |location|
      assert_equal ids(pune, mumbai), matched_ids(make_profile(remote: false, location: location))
    end
  end

  test "salary_min keeps jobs with no salary or a high enough salary" do
    none = make_job(1, salary_min: nil)
    equal = make_job(2, salary_min: 500_000)
    above = make_job(3, salary_min: 600_000)
    make_job(4, salary_min: 499_999)

    assert_equal ids(none, equal, above), matched_ids(make_profile(salary_min: 500_000))
  end

  test "a zero vector profile gives every job a score of 0.0" do
    [ [ 1.0, 0.0 ], [ 0.0, 1.0 ], [ 0.0, 0.0 ] ].each_with_index { |vector, index| make_job(index, embedding: vector) }
    pairs = Matcher.call(make_profile(embedding: [ 0.0, 0.0 ]))

    assert_equal 3, pairs.size
    pairs.each { |_job, score| assert_in_delta 0.0, score, 0.0001 }
  end

  test "a zero vector job gets a score of 0.0" do
    make_job(1, embedding: [ 0.0, 0.0 ])
    pairs = Matcher.call(make_profile)

    assert_equal 1, pairs.size
    assert_in_delta 0.0, pairs.first.last, 0.0001
  end

  test "it writes nothing" do
    make_job(1)
    profile = make_profile
    jobs = Job.count
    applications = JobApplication.count

    Matcher.call(profile)

    assert_equal jobs, Job.count
    assert_equal applications, JobApplication.count
  end
end
