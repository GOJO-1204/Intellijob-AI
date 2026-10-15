# PROJECT_STATE.md (update after every merged task; signatures only)
## Done
- Environment verified on both machines (Ruby 3.4.11, Rails 8.1.4, PG 18, Memurai)
- B-1.1: CLAUDE.md, REGISTRY.md, PROJECT_STATE.md added; .gitattributes set to eol=lf
- B-1.1: Adzuna keys added to Rails credentials
- A-1.2: models, migrations and model tests merged; importmap setup merged
- A-1.3: App shell merged. HomeController#index (public landing, signed-in users go to dashboard_path), DashboardController#show (empty placeholder), shared/_navbar and shared/_flash partials, routes: root, devise_for :users, resource :dashboard
- A: Anthropic key added to credentials (Rails.application.credentials.anthropic.api_key)
- B-1.2: db/seeds.rb (demo@example.com, 1 ready profile, 10 jobs with source 'seed')
## In progress
- none
## Known issues
- Seed user has a known password: delete or change it before production (Day 14)