# Safe to run repeatedly: every record is looked up before it is created.
user = User.find_or_create_by!(email: 'demo@example.com') do |u|
  u.password = 'password123'
  u.password_confirmation = 'password123'
end

# The profile already exists (User after_create), so update it, never create another.
user.profile.update!(
  resume_text: <<~RESUME,
    Riya Das - Full Stack Developer
    Bhubaneswar, India | demo@example.com
    - Built a Rails 7 job portal used by 2,000 students with Devise and PostgreSQL
    - Wrote React dashboards with Tailwind and reusable component libraries
    - Cut API response time by 40% with SQL indexing and fragment caching
    - Created background jobs with Sidekiq to send daily email digests
    - Trained a text classifier in Python to tag support tickets
    - Led a team of 4 on a final year project and ran weekly code reviews
    Skills: ruby, rails, javascript, react, postgresql, sidekiq
    Education: B.Tech CSE, CGPA 8.2
  RESUME
  target_role: 'Ruby on Rails Developer',
  target_skills: %w[ruby rails postgresql react sidekiq],
  location: 'Bhubaneswar',
  remote: true,
  salary_min: 60_000,
  alert_frequency: 'daily'
)

# [title, company, location, remote, salary_min, description]
JOBS = [
  [ 'Ruby on Rails Developer', 'Acme Labs', 'Bengaluru', false, 90_000, 'Build Rails APIs and Hotwire views.' ],
  [ 'Full Stack Engineer', 'Northwind', 'Remote', true, 110_000, 'Ship features across React and Rails.' ],
  [ 'Backend Engineer', 'Pixelforge', 'Hyderabad', false, nil, 'Design services on PostgreSQL and Redis.' ],
  [ 'Junior Web Developer', 'Brightpath', 'Bhubaneswar', false, 45_000, 'Fix bugs and build small UI features.' ],
  [ 'Machine Learning Engineer', 'DataNest', 'Pune', true, 130_000, 'Train and deploy NLP models.' ],
  [ 'DevOps Engineer', 'CloudWorks', 'Remote', true, nil, 'Own CI pipelines and Docker deployments.' ],
  [ 'Frontend Developer', 'Layerly', 'Mumbai', false, 70_000, 'Create accessible Tailwind interfaces.' ],
  [ 'Software Engineer Intern', 'Startly', 'Remote', true, 20_000, 'Pair with seniors on a Rails codebase.' ],
  [ 'Data Analyst', 'Insightful', 'Chennai', false, nil, 'Build SQL reports and dashboards.' ],
  [ 'Senior Rails Engineer', 'Orbit Systems', 'Remote', true, 150_000, 'Lead background job and API design.' ]
].freeze

JOBS.each_with_index do |(title, company, location, remote, salary_min, description), i|
  n = i + 1
  job = Job.find_or_initialize_by(url: "https://example.com/jobs/#{n}")
  job.assign_attributes(
    title: title, company: company, location: location, remote: remote,
    salary_min: salary_min, description: description,
    source: 'seed', external_id: n.to_s
  )
  job.posted_at ||= (n % 10).days.ago # set once, so reruns do not change it
  job.save!
end

puts "Users: #{User.count}, Jobs: #{Job.count}"
