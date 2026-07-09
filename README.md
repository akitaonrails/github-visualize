# github-visualize

Self-hosted dashboard that monitors your GitHub repositories and replays their
progress with animated visualizations, inspired by the charts embedded in
Bun's ["How we made Bun's TypeScript 100x faster by rewriting it in Rust"](https://bun.com/blog/bun-in-rust)
blog post.

For each monitored repository you get:

- **Commit timeline replay** — lines added (pink) and deleted (cyan) over the
  full history, with animated counters and a scrolling `git log` feed.
- **Day-by-hour heatmap** — commits per hour over the last 42 days on a
  purple-to-yellow heat ramp.
- **The race to green** — one lane per GitHub Actions workflow, one tick per
  run, green/red, revealed chronologically.
- **Dashboard overview** — commits-per-repo bars, per-repo daily activity
  chips, sync state, and latest CI status.

Every chart has a ⟳ replay button. Animations respect `prefers-reduced-motion`.

## Stack

Rails 8.1 (slim: no mailer/storage/cable/action-text), SQLite, Solid Queue
(background sync, no Redis), Tailwind CSS 4, importmap + Stimulus with
hand-rolled canvas charts. No authentication in v1 — deploy it on a trusted
network only.

Data is fetched with the **minimum possible API calls**: commit history comes
from the GitHub GraphQL API (which returns additions/deletions in bulk, 100
commits per request) and workflow runs from the REST API. Syncs are
incremental and idempotent (`upsert_all`), and run every 30 minutes in
production (`config/recurring.yml`).

## Configuration

All secrets come from the environment — nothing sensitive is committed.
Copy `.env.example` to `.env` (gitignored) and fill in:

| Variable | Required | Purpose |
|---|---|---|
| `GITHUB_TOKEN` | yes | Token with read access to the repos (fine-grained: Contents + Actions read) |
| `SECRET_KEY_BASE` | production | `openssl rand -hex 64` |
| `PORT` | no | Host port for Docker (default 7592) |
| `APP_TIME_ZONE` | no | Timezone used to bucket charts (default UTC; compose sets America/Sao_Paulo) |
| `STORAGE_PATH` | no | Host dir for the SQLite volume (default `./storage`) |

## Development

```bash
bin/setup            # bundle + db:prepare
bin/dev              # server + tailwind watcher on :3000
bin/rails test       # test suite, SimpleCov report in coverage/
bin/rubocop          # omakase style
bin/brakeman         # static security analysis
bin/bundler-audit    # known-vulnerable gems
bin/importmap audit  # JS dependency advisories
```

Add a repository from the dashboard form (`owner/name`) — the first sync is
enqueued automatically. To sync from the console:

```ruby
repo = Repository.create!(owner: "akitaonrails", name: "ai-memory")
SyncRepositoryJob.perform_now(repo)
```

In development, run queued jobs with `bin/jobs` (or inline via the console as above).

## Docker

```bash
echo "SECRET_KEY_BASE=$(openssl rand -hex 64)" >> .env
echo "GITHUB_TOKEN=ghp_..." >> .env
docker compose up -d --build
# http://localhost:7592
```

Single container: Thruster + Puma with the Solid Queue supervisor running
in-process (`SOLID_QUEUE_IN_PUMA=1`). SQLite databases (app, cache, queue)
persist in the `storage/` volume. Healthcheck hits `/up`.

### Homelab (openSUSE MicroOS) notes

- Stack root: `/var/opt/docker/github-visualize/`.
- The bind mount must **not** use `:Z` — the compose file sets
  `security_opt: label:disable` instead (SQLite + SELinux relabeling do not mix).
- Container runs as uid 1000 (`rails`); `chown -R 1000:1000 storage/` if the
  directory pre-exists.

## CI

GitHub Actions (`.github/workflows/ci.yml`): Brakeman, bundler-audit,
importmap audit, RuboCop (cached), and the test suite with a coverage
artifact.
