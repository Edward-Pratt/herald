# Brief: self-hosted auto-updates for Edward's plugins

Edward wants every plugin/addon he makes to update itself automatically. His idea is to host the update packages on
the Oracle Cloud server that will also host his website (https://edward-pratt.github.io/ today, on GitHub Pages, with a
custom domain planned). Each program would point at that server as its update source.

That needs two halves:
1. **Publishing:** getting new releases from GitHub onto the server (e.g. a GitHub Action pushing on tag/release, a
   webhook the server listens for, or the server polling the GitHub Releases API).
2. **Updating:** each program checking the server for a newer version, downloading it and installing it safely.

## What to do first: research, not code

Look into this and come back with a recommendation, before building anything:

- **Which programs are in scope**, and how each one installs and updates today. Candidates on Edward-Pratt's GitHub:
  - `claude-operator` and `community-plugins`: Noctalia shell plugins. Check whether Noctalia already has a plugin
    registry or update mechanism to hook into rather than replace.
  - `burrow`: GTK4 desktop app with an addon protocol (M5). Addons will need updating too.
  - `orrery`: Forge 1.7.10 mod + Discord hub that already "self-deploys". See how it does that.
  - `Level-Maintainer` (OpenComputers program), `autocopy`, `claude-code-mods`.
  Ask Edward which of these he actually means if it isn't clear.
- **Is a self-hosted server worth it vs GitHub Releases directly?** Programs can query
  `api.github.com/repos/<owner>/<repo>/releases/latest` with no server at all. Weigh what the Oracle server adds
  (one stable URL, a custom domain, private repos, a single manifest for everything, download stats) against what it
  costs (uptime, maintenance, a single point of failure, security of serving executable code).
- **Design for the server option:** a manifest format (e.g. `/updates/<plugin>/latest.json` with version, URL, sha256,
  signature), how releases get there from GitHub, and the web server setup on Oracle (Caddy/nginx, TLS).
- **Security:** updates are code execution on Edward's machines. Cover checksums, signing (minisign/signify or
  similar, with the private key only in CI or on the desktop), HTTPS only, and rollback if an update is bad.
- **Client side:** a small shared update-check pattern each program can reuse, given they're in different languages
  (QML/JS, Rust, Java, Lua).

Write the findings and a recommended plan up for Edward (a doc or a markdown file in this repo), and ask him the open
questions. Don't touch the other repos yet.

## Context

- This repo (`Edward-Pratt/update-server`, private) is the home for the server side: scripts, config, CI templates.
- It runs on warren, Edward's always-on Arch laptop, driven from his phone. See `~/ClaudeCode/CLAUDE.md`.
- The Oracle server isn't set up yet as far as this brief knows. Ask Edward for its details when needed.
