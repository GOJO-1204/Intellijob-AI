REGISTRY (names are law)

RULES
- Model is JobApplication (table job_applications), never Application.
- Status enum: matched, saved, applied, interview, offer, rejected, dismissed.
- Profile#alert_frequency: daily, weekly, paused. Jobs de-duplicated by url.
- Background jobs receive IDs or simple values, never objects.
- jsonb columns return STRING keys: profile.ats_feedback['shortcomings'].
- Stateless services: ClassName.call(args). Only ResumeAnalyzer and
  ResumeAiReviewer use ClassName.new(args).call.
- Always scope: current_user.job_applications, never JobApplication.find(params[:id]).
- Files under 60 lines. Jobs are named VerbNounJob.

SCHEMA
Profile: user_id, resume_text:text, target_role:string, target_skills:string[]
  (array, default []), location:string, remote:boolean, salary_min:integer,
  experience_level:string, alert_frequency:string (default 'daily'),
  ats_score:integer, ats_feedback:jsonb (default {}), ai_suggestions:jsonb
  (default []), embedding:jsonb. Unique index on user_id.
Job: title, company, url (unique), description:text, location, remote:boolean,
  salary_min:integer, source, external_id, posted_at:datetime, embedding:jsonb.
JobApplication: user_id, job_id, status (string, default 'matched', null: false),
  score:float, notes:text, applied_at:datetime, notified_at:datetime.
  Unique index [user_id, job_id]; index [user_id, status].
ats_feedback = { checks: [{name, score, max}], shortcomings: [{name, issue, fix}] }
ai_suggestions = [{original, improved, why}]
Job-source hash keys (symbols, identical for every source): title, company, url,
  description, location, remote, salary_min, source, external_id, posted_at.

MODELS
user.rb (A)  Devise. has_one :profile, has_many :job_applications,
  has_many :jobs through :job_applications. after_create { create_profile! }.
profile.rb (A)  belongs_to :user. has_one_attached :resume (PDF/DOCX, under 5 MB).
  #embedding_text -> String (role + skills + resume_text).
  #ready_for_matching? -> Boolean (resume_text and target_role present). scope :ready.
job.rb (A schema, B method)  has_many :job_applications.
  Job.upsert_from(hash) -> Job (find_or_initialize_by url). [B]
  #embedding_text -> String (title + company + description). scope :recent (30 days).
job_application.rb (A)  belongs_to :user, :job. enum :status. scope :alertable
  (status matched, notified_at nil). Sets applied_at ONCE when status becomes applied.

SERVICES
resume_parser.rb (A)       ResumeParser.call(attachment) -> String
resume_analyzer.rb (A)     ResumeAnalyzer.new(text, target_skills:, page_count:).call -> Hash
resume_ai_reviewer.rb (A)  ResumeAiReviewer.new(text, target_role:).call -> Array<Hash>
gemini_client.rb (A)       GeminiClient.call(url, payload) -> String (response body)
                           Tries up to 3 times, retries only HTTP 503 and timeouts,
                           other errors raise GeminiClient::Error (code, retryable) at once.
skill_extractor.rb (A)     SkillExtractor.call(text) -> Array<String>
                           (uses ResumeAnalyzer::COMMON_SKILLS)
manual_job_adder.rb (A)    ManualJobAdder.call(user, attrs) -> Hash {application:, error:}
job_sources.rb (B)         JobSources.all -> [Remotive, Adzuna]
job_sources/remotive.rb (B) JobSources::Remotive.fetch -> Array<Hash>
job_sources/adzuna.rb (B)   JobSources::Adzuna.fetch -> Array<Hash> (same keys)
embedder.rb (B)            Embedder.call(text) -> Array<Float>
matcher.rb (B)             Matcher.call(profile, limit: 20) -> Array<[Job, Float]>
dashboard_stats.rb (B)     DashboardStats.call(user) -> Hash {counts, avg_score,
                           applied_this_week}

JOBS
resume_analysis_job.rb (A)  perform(profile_id)  calls ResumeAnalyzer, ResumeAiReviewer
fetch_jobs_job.rb (B)       perform  calls JobSources.all, Job.upsert_from, then
                            EmbedRecordsJob. Trigger: cron every 6 hours.
embed_records_job.rb (B)    perform  fills nil embeddings for Job.recent and
                            Profile.ready via Embedder, then MatchJobsJob.
match_jobs_job.rb (B)       perform(user_id = nil)  nil = all ready profiles.
                            find_or_create_by, never overwrites an existing status.
send_alerts_job.rb (B)      perform(frequency)  'daily' or 'weekly'. Top 5 alertable
                            per user via JobAlertMailer, then sets notified_at.
cleanup_jobs_job.rb (B)     perform  deletes jobs with posted_at older than 30 days, with their 'matched'
                            applications, in batches of 500. Never deletes jobs with source 'manual' or
                            jobs with an application in any other status. Jobs without posted_at are kept.

MAILER (B)
job_alert_mailer.rb  new_matches(user, applications) mails user.email.
  views job_alert_mailer/new_matches.html.erb and .text.erb use @user, @applications,
  and an unsubscribe link built from user.signed_id(purpose: :unsubscribe).

CONTROLLERS
application_controller (A)  before_action :authenticate_user!
home_controller (A)         index (landing; signed-in users routed by progress)
profiles_controller (A)     new, create (resume upload), show (ATS results)
preferences_controller (A)  edit, update (the question form)
matches_controller (A)      index (current user's matched applications by score)
job_applications_controller (A)  update (permits status, notes; turbo_stream)
                                 new, create (add a job applied elsewhere; uses ManualJobAdder)
dashboard_controller (A)    show (tabs by params[:status])
unsubscribes_controller (B) show (finds user by token, sets alert_frequency 'paused',
                            no login needed)

ROUTES (final)
  root 'home#index'
  devise_for :users
  resource :profile, only: %i[new create show]
  resource :preferences, only: %i[edit update]
  resources :matches, only: :index
  resource :dashboard, only: :show, controller: 'dashboard'
  resources :job_applications, only: %i[new create update]
  get 'unsubscribe/:token', to: 'unsubscribes#show', as: :unsubscribe

VIEWS (A unless noted)
  layouts/application, shared/_navbar, shared/_flash, shared/_empty_state (locals title, message),
  profiles/new, profiles/show (partials _results, _tips, _analysis_status), preferences/edit, preferences/_skills, matches/index,
  job_applications/_job_application (card: li with dom_id, status select, notes, Save, Dismiss,
  Apply; replaced by turbo_stream, no turbo_frame), job_applications/update.turbo_stream,
  job_applications/new (form: title, company, url, location, status),
  dashboard/show (heading, tabs, list of applications or empty state), dashboard/_tabs

CONFIG (B)
  config/initializers/sidekiq.rb, config/sidekiq_cron.yml:
    FetchJobsJob "0 */6 * * *"; SendAlertsJob args ['daily'] "0 8 * * *";
    SendAlertsJob args ['weekly'] "0 8 * * 1"; CleanupJobsJob "0 3 * * *"
  development.rb: letter_opener. production.rb: SMTP from ENV.
  db/seeds.rb, lib/tasks/smoke.rake (rails smoke prints PASS/FAIL per pipeline step).

PIPELINE (who triggers whom)
  Upload -> ProfilesController#create -> ResumeParser -> profile.update(resume_text:)
    -> ResumeAnalysisJob (ATS score + Gemini tips), and EmbedRecordsJob
  Save questions -> PreferencesController#update -> profile.update(embedding: nil)
    -> EmbedRecordsJob
  Every 6h -> FetchJobsJob -> JobSources.all -> Job.upsert_from -> EmbedRecordsJob
    -> MatchJobsJob -> Matcher -> JobApplication rows (status matched)
  Daily/weekly -> SendAlertsJob -> JobAlertMailer -> notified_at set
  User actions -> JobApplicationsController#update (status, notes), #create -> ManualJobAdder (manual job)
  Dashboard -> DashboardController#show -> DashboardStats.call(user)
