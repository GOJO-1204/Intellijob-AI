# PROJECT_STATE.md (update after every merged task; signatures only)
## Done
- Environment verified on both machines (Ruby 3.4.11, Rails 8.1.4, PG 18, Memurai)
- B-1.1: CLAUDE.md, REGISTRY.md, PROJECT_STATE.md added; .gitattributes set to eol=lf
- B-1.1: Adzuna keys added to Rails credentials
- A-1.2: models, migrations and model tests merged; importmap setup merged
- A-1.3: App shell merged. HomeController#index (public landing, signed-in users go to dashboard_path), DashboardController#show (empty placeholder), shared/_navbar and shared/_flash partials, routes: root, devise_for :users, resource :dashboard
- A: Anthropic key added to credentials (Rails.application.credentials.anthropic.api_key)
- B-1.2: db/seeds.rb (demo@example.com, 1 ready profile, 10 jobs with source 'seed')
- B-2.0: informers, sidekiq, sidekiq-cron, letter_opener gems added
- B-2.1: JobSources.all -> [Remotive]; JobSources::Remotive.fetch -> Array<Hash> (10 keys, [] on error)
- Note: Remotive returned 14 jobs on 16 Oct (plan said 20+); keys and types verified
- B-2.2: Job.upsert_from(hash) -> Job (nil when url blank); assigns only the 9 source keys, never id/url/embedding
- B-3.1: JobSources::Adzuna.fetch -> Array<Hash> (same 10 keys, country 'in', 3 keywords, 150 max, [] per failed request)
- B-3.1: JobSources.all -> [Remotive, Adzuna]
- B-3.2: FetchJobsJob.perform (no args) -> for each JobSources.all source: fetch, Job.upsert_from per hash, logs fetched/saved/skipped counts; one failing source never stops the others; EmbedRecordsJob added in B-4.2
## In progress
- none
## Known issues
- Seed user has a known password: delete or change it before production (Day 14)
- Adzuna redirect_url contains Adzuna's own utm_source (looks like our app_id). app_key is not in it. Low severity; review in B-13.1 (security) before putting these urls in emails.