# IntelliJob

IntelliJob matches job seekers with open jobs. A user uploads a resume, gets an ATS score and AI tips, sets preferences, and receives matches and email alerts.

## Requirements (Windows, PowerShell)

- Ruby 3.4.11
- PostgreSQL (psql on the PATH)
- Redis compatible server: Memurai. Check with `memurai-cli -h 127.0.0.1 ping`, expect `PONG`.
- `config/master.key`, copied by hand from the project owner. It is not in git. Without it the Gemini key cannot be read and the AI tips fail.

## Setup

1. `git clone git@github.com:GOJO-1204/jobmatch.git` and open the folder.
2. database.yml holds no username or password. Set the PostgreSQL login in the same window, for example `$env:PGUSER = 'postgres'` and `$env:PGPASSWORD = '<your password>'`.
3. Copy `master.key` into the `config` folder.
4. `bundle install`
5. `rails db:create db:migrate db:seed`
6. `rails tailwindcss:build` (needed once, before the server starts, or the site has no styles)

## Run

Use one window for each command, from the project folder.

1. `rails server` and open http://127.0.0.1:3000
2. `$env:RAILS_MAX_THREADS = "5"; bundle exec sidekiq -q default -q mailers`

Run only one Sidekiq worker. All workers share the same Redis queue. Redis is read from `REDIS_URL`, default `redis://127.0.0.1:6379/0`.

Alert emails open in the browser through letter_opener. Links in them point to localhost:3000.

## Demo login

`demo@example.com` with the password `password123`. This user is for the demo only and is removed before any real launch.

## Tests

- `rails test`
- `ruby bin/rubocop`
