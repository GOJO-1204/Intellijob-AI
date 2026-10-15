# JobMatch AI: project rules (read first, never rename anything)
Stack: Ruby 3.4, Rails 8.1, PostgreSQL, Devise, Active Storage, Hotwire, Tailwind,
  Sidekiq + sidekiq-cron + Redis, Claude API, informers (embeddings).
Machines: Windows 10/11, PowerShell, no Linux. Redis is Memurai.
Style: services in app/services, one responsibility each, under 60 lines per file.
Rules:
- Scope every query to the signed-in user: current_user.job_applications,
  never JobApplication.find(params[:id]).
- No secrets in code. Use Rails.application.credentials.dig(:anthropic, :api_key).
- Prefer Ruby/Rails built-ins over new gems. No features beyond the current task.
- Background jobs receive IDs, never objects.
- jsonb columns return STRING keys: profile.ats_feedback['shortcomings'].
- Use exactly the names, arguments and return types in REGISTRY.md. If something
  looks wrong, stop and ask. Never rename.
- Windows: use rails ... or ruby bin/rails ... . Do not use bin/dev.
Schema and registry: see REGISTRY.md.
Ownership: A = resume/user side. B = jobs/automation side.
Git: branch per task (a/..., b/...), one PR per task reviewed by the other person,
  never push to main. Credentials: one person edits at a time.