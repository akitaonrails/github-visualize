# Planned: "Connect GitHub" via OAuth Device Flow

Status: **designed, not implemented** (2026-07-09). Blocked only on a
one-time manual step by the repo owner (see "Prerequisite" below).

## Goal

Replace manual `GITHUB_TOKEN` configuration with a "Connect GitHub" button
for people self-hosting the public Docker image. Public-repo behavior keeps
working as today; private repos become reachable after login.

## Why Device Flow (not the classic OAuth web flow, not a GitHub App)

- **Classic OAuth web flow** needs a client ID + client **secret** + a
  registered callback URL matching the server address. Every self-hoster
  would have to register their own OAuth App — three config values instead
  of one token, and callback URLs on LAN IPs (`http://192.168.x.x:7592`) are
  finicky. Strictly worse onboarding than a PAT.
- **Device Flow** (what the `gh` CLI uses): the app shows a short code, the
  user enters it at <https://github.com/login/device>, the app polls and
  receives the token. No callback URL, no client secret — only a **public**
  client ID that can ship in the codebase. One OAuth App registered once by
  the project owner serves every self-hosted install with zero config.
- **GitHub App** would allow fine-grained read-only permissions but costs
  JWTs, private keys, installations, and webhooks — overkill for this app.

## Security tradeoff (be explicit in the README when shipping)

OAuth Apps only have coarse scopes: reading private repos requires `repo`,
which also grants **write** access to all the user's repos. A fine-grained
PAT (Contents: read + Actions: read) is strictly least-privilege. Therefore:

- The login button is the *convenience* path.
- The env `GITHUB_TOKEN` stays supported as the *least-privilege* path and
  as an override. Document both.

## Design

1. **Prerequisite (manual, owner-only — cannot be done via API):**
   GitHub → Settings → Developer settings → OAuth Apps → New OAuth App
   ("github-visualize", homepage = repo URL, callback = any placeholder),
   tick **"Enable Device Flow"**. The resulting Client ID is public; commit
   it as a default (`GITHUB_OAUTH_CLIENT_ID` env override).
2. **Token storage:** new `settings` key-value table; the OAuth token stored
   with Active Record encryption (derive keys from `SECRET_KEY_BASE` via
   `config.active_record.encryption` so no new secrets are needed).
3. **Token precedence:** `Setting` (OAuth) token → `ENV["GITHUB_TOKEN"]` →
   none. Single accessor consumed by `Github::Client.new`; sync jobs,
   suggestions, and the header owner badge all read through it.
4. **Flow:** header button → `POST https://github.com/login/device/code`
   (scope `repo`) → show `user_code` + verification URL → Stimulus poller
   hits `POST https://github.com/login/oauth/access_token`
   (`grant_type=urn:ietf:params:oauth:grant-type:device_code`) respecting
   `interval`/`slow_down` → store token, refresh header to
   "connected as <login> (disconnect)".
5. **Disconnect:** delete the Setting row (optionally revoke via
   `DELETE /applications/{client_id}/grant` — needs client secret, so
   probably just link to GitHub's app-revocation settings page).
6. **No token at all:** dashboard renders, but add/sync/suggestions surface
   a "connect GitHub or set GITHUB_TOKEN" prompt instead of erroring.
7. **Tests:** webmock the two device-flow endpoints; precedence unit tests;
   system behavior for the no-token prompt.
