desc "Smoke test of the job pipeline (LIVE=1 also fetches from the real sources)"
task smoke: :environment do
  previous = ActiveJob::Base.queue_adapter
  puts "smoke refuses to run in production" if Rails.env.production?
  exit 1 if Rails.env.production?
  ActiveJob::Base.queue_adapter = :test # perform_later calls are only recorded, never run
  check = ->(checks) { checks.each { |what, ok| raise "check failed: #{what}" unless ok } }
  user = User.find_by(email: "demo@example.com")
  fake = "https://smoke.invalid/job-1"
  steps = {
    "seed data" => lambda do
      check.call("demo user exists" => user.present?, "profile is ready" => user&.profile&.ready_for_matching?, "recent jobs exist" => Job.recent.count > 0)
    end,
    "fetch" => lambda do
      job = { title: "Smoke job", company: "Smoke", url: fake, description: "Smoke", location: "Nowhere", remote: true, salary_min: 1000, source: "smoke", external_id: "smoke-1", posted_at: Time.current }.with_indifferent_access
      jobs = [ Job.upsert_from(job), Job.upsert_from(job) ]
      before = Job.count
      FetchJobsJob.perform_now if ENV["LIVE"] == "1" # real network
      check.call("sources respond to fetch" => JobSources.all.is_a?(Array) && JobSources.all.all? { |s| s.respond_to?(:fetch) }, "upsert returns Jobs" => jobs.all?(Job), "one row per url" => Job.where(url: fake).count == 1, "job count did not go down" => Job.count >= before)
    ensure
      Job.where(url: fake).destroy_all
    end,
    "embed" => lambda do
      EmbedRecordsJob.perform_now
      vector = user.profile.reload.embedding
      check.call("recent jobs embedded" => Job.recent.where(embedding: nil).count.zero?, "ready profiles embedded" => Profile.ready.where(embedding: nil).count.zero?, "demo vector has 384 numbers" => vector.is_a?(Array) && vector.length == 384)
    end,
    "match" => lambda do
      MatchJobsJob.perform_now(user.id)
      before = user.job_applications.count
      check.call("has applications" => before > 0, "scores are Floats" => user.job_applications.pluck(:score).all?(Float))
      MatchJobsJob.perform_now(user.id)
      check.call("second run adds nothing" => user.job_applications.count == before)
    end,
    "alert preview" => lambda do
      apps = user.job_applications.includes(:job).order(score: :desc).first(3)
      mail = JobAlertMailer.new_matches(user, apps)
      check.call("recipient is the user" => mail.to == [ user.email ], "subject ends as expected" => mail.subject.to_s.end_with?("new job matches for you"))
      { "text" => mail.text_part, "html" => mail.html_part }.each do |kind, part|
        body = part ? part.body.decoded : ""
        check.call("#{kind} part has unsubscribe" => body.match?(/unsubscribe/i), "#{kind} part has a job url" => apps.any? { |a| [ a.job.url, a.job.url.gsub("&", "&amp;") ].any? { |u| body.include?(u) } })
      end
    end
  }
  failed = 0
  steps.each do |name, step|
    step.call
    puts "PASS #{name}"
  rescue StandardError => e
    failed += 1
    puts "FAIL #{name}: #{e.class} #{e.message[0, 200]}"
  end
  puts "Smoke: #{steps.size - failed} passed, #{failed} failed"
  exit 1 if failed > 0
ensure
  ActiveJob::Base.queue_adapter = previous
end
