# AGENTS.md — github-visualize

Self-hosted Rails 8.1 dashboard that monitors GitHub repositories and replays
their progress with animated canvas charts (commit timeline, day×hour heatmap,
CI race-to-green), styled after the visualizations in
https://bun.com/blog/bun-in-rust. Primarily deployed on a trusted LAN without
user authentication.

## Commands

```bash
bin/setup            # bundle + db:prepare
bin/dev              # server + tailwind watcher on :3000
bin/rails test       # full suite (minitest + webmock + SimpleCov)
bin/rubocop          # omakase style — zero offenses is the bar
bin/brakeman --no-pager
bin/bundler-audit
bin/importmap audit
DEPLOY_HOST=user@server bin/deploy   # build → push → pull → compose up (see script header)
```

**Gate before every commit:** `bin/rails test && bin/rubocop`. Don't pipe test
output through `grep` as a pass signal — check the exit status.

## Architecture

- `app/models/` — `Repository` (owner/name unique, sync lifecycle),
  `Commit` (sha, message, committed_at, additions/deletions),
  `WorkflowRun` (github_id, conclusion). SQLite everywhere; Solid Queue for
  jobs, Solid Cache for caching — no Redis, no external services.
- `app/services/github/client.rb` — the only place that talks to GitHub.
  Commit history via **GraphQL** (returns additions/deletions in bulk; the
  REST equivalent costs one request per commit — do not regress this),
  workflow runs and user repos via REST. Token from `ENV["GITHUB_TOKEN"]`.
- `app/jobs/sync_repository_job.rb` — page-by-page upserts (idempotent,
  `unique_by`) with `sync_progress` updates for the live UI. Recurring
  on an activity-tiered recurring schedule in production
  (`config/recurring.yml`): hot ≤7d → 10 min, warm ≤30d → hourly,
  cold → 6 hours; tiers computed in `SyncAllRepositoriesJob`.
- `app/presenters/visualizations/` — POROs that compute chart series
  server-side; views embed them as JSON in Stimulus values.
- `app/javascript/controllers/` — canvas chart controllers extend
  `lib/playback_controller.js` and implement `render(progress)` (+ optional
  `static duration`). The base class owns ghost-frame, play-on-scroll
  (IntersectionObserver ≥ 20% ratio), reduced-motion skip, resize, replay.
- `app/controllers/` — no auth by design (v1); opt-in HTTP Basic via
  `HTTP_BASIC_USER`/`HTTP_BASIC_PASSWORD` lives in `ApplicationController`.
  Dashboard adds repos in place via Turbo Streams (`repositories#create`).

## Invariants — do not break these

1. **Secrets never enter the repo or the image.** Everything comes from env
   (`GITHUB_TOKEN`, `SECRET_KEY_BASE`, …). `.env*` and `.deploy.env` are
   gitignored and dockerignored; `bin/deploy` seeds the server `.env` over
   stdin. Never print tokens.
2. **`Repository.default_owner` is the single read point for
   `GITHUB_OWNER`.** Don't scatter `ENV[]` reads through app code.
3. **Owner/name validation is a security boundary** — the values become URL
   path segments for the GitHub API (`NAME_FORMAT` forbids `/`, spaces, and
   dot-only segments). Widen it only with a test proving no traversal.
4. **Tests are hermetic**: `test_helper.rb` scrubs `GITHUB_TOKEN`/
   `GITHUB_OWNER` and WebMock blocks real HTTP. Stub GitHub with the helpers
   in `test_helper.rb` (`graphql_history_body`, `rest_workflow_run`, …).
5. **Ruby/JS duplication is deliberate in exactly one place**: the heat color
   ramp (`ApplicationHelper::HEAT_STOPS` ↔ `heatmap_controller.js` stops).
   Change both together.
6. **Serve plain HTTP by default** — `assume_ssl`/`force_ssl` are env-gated
   (`ASSUME_SSL`/`FORCE_SSL`); enabling them unconditionally breaks CSRF for
   LAN users (Secure cookies never come back over http).
7. **Fetch the minimum from GitHub**: incremental syncs (`since:` = newest
   commit), capped pages, upserts. Never fetch per-commit details in a loop.

## UI conventions

Dark theme (`#0b0a10`), monospace, Tailwind utilities inline (no custom CSS
files). Chart aesthetics follow the Bun post: plasma heat ramp, pink
additions / cyan deletions, green/red CI ticks, scan-bar reveals. Numbers are
formatted with `number_with_delimiter` / `Intl.NumberFormat`. Escape
everything; user-influenced text goes through ERB escaping or `textContent`
(never `innerHTML`).

## Verification

Chart changes can't be asserted by the test suite — verify visually:

```bash
bin/rails server -p 3057 -d
chromium --headless --disable-gpu --force-prefers-reduced-motion \
  --window-size=1400,2400 --screenshot=/tmp/gv.png --virtual-time-budget=8000 \
  "http://localhost:3057/repos/<owner>/<name>"
```

(`--force-prefers-reduced-motion` renders the final frame; drop it plus use a
short `--virtual-time-budget` to inspect mid-animation frames.)

## Audit trail

Post-merge audits use phase-labelled commits (`fix(audit-P1):`,
`refactor(audit-P2):`, `chore(audit-P3):`) — keep that convention so
`git log --grep='audit-P'` reconstructs the history.
