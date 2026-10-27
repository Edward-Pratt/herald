# Self-hosted plugin updates: findings and recommendation

Research for [BRIEF.md](BRIEF.md), 2026-10-27. Nothing is built yet, and no other repo was changed.

## Short version

**Don't build a central update server yet.** Most of these programs already update through a channel they're built
around, and two have written rules against a home-made updater:

- Noctalia **already auto-updates plugins** from git sources: at startup and every 6 hours, by default. It can only
  read git repos (or local folders), so a JSON manifest on a server can't plug into it. The community catalog also
  forbids plugins that download and run code.
- burrow's design says **"AUR PKGBUILD as the main channel, with no self-updater"**. Its addon approvals are pinned
  to a hash of every file, so addon updates *can't* be silent by design.
- orrery **already self-deploys from GitHub Releases** without an update server. It runs on what looks like the very
  Oracle box the brief means.

The Oracle server buys most for **Level-Maintainer** (OpenComputers): there a short, stable URL and a version file
really help. Even then, GitHub Pages or the GitHub API can do the same job for free. My recommendation is to fix
each program's own channel (table below). Keep the server design in [Contingency](#contingency-the-server-design)
for when there's a real need: private repos, many outside users, or a single dashboard.

## What's in scope and how each updates today

The brief's language list needs correcting. The Noctalia plugins are **Luau**, not QML/JS. orrery is TypeScript
(the hub) plus a Java mod jar. claude-code-mods are TypeScript hooks. autocopy is shell.

| Program | What it is | Installs / updates today | Recommended channel | Effort |
|---|---|---|---|---|
| `claude-operator` | Noctalia plugin (Luau) | `path` source from a clone, so no updates until you `git pull`. Submitted to the community catalog in noctalia-dev/community-plugins#1176. | **Community catalog** once #1176 merges: Noctalia auto-updates it. Until then, add the repo as a **`git` source** (see note 1). | None / tiny |
| `community-plugins` | Edward's fork of noctalia-dev/community-plugins, used to send PRs | Not something users install. Its `claude-operator` branch carries the copy that feeds PR #1176. | Nothing to do: it's the publishing route for claude-operator. | None |
| `burrow` | GTK4 app (Rust) + daemon, agent, CLI | `burrow-git` PKGBUILD builds `main`. CI publishes a rolling `build-main` release (`burrow-x86_64.tar.gz`, `SHA256SUMS`, `commit`). | **Keep AUR/pacman** (a tagged `burrow` package next to `burrow-git` when releases start). A self-updater would reverse DESIGN.md, so that's a question for you. | Small |
| burrow addons (M5) | Sidecar processes, any language | Not built yet. A changed addon re-asks for approval. | Later: an addon index that *offers* updates, with approval re-prompting as designed. Not silent. | Future |
| `orrery` | Hub (Node/TS), dashboard, Forge 1.7.10 mod | Hub polls `api.github.com/.../releases`. You pick a deploy (Discord/dashboard). A systemd oneshot runs `deploy-hub.sh` **from the running release**, health-gates for 30 s, flips `current`, rolls back on failure, keeps 3 releases and writes `deploy-status.json`. | **Already done.** Use it as the reference pattern. One gap: it doesn't check asset checksums. | Tiny |
| `Level-Maintainer` | OpenComputers Lua (fork) | `installer.lua` `wget`s raw files from `master` on raw.githubusercontent.com, then reboots. No versions, no integrity check. The README says the Internet Card is "for the installer only". | **Tagged releases + a `version` file + sha256 check** in an `update` command. This is the one place a short stable URL helps (see note 2). | Medium |
| `autocopy` | Shell + systemd user unit | `git clone && ./install.sh`; update = `git pull && ./install.sh` | A **PKGBUILD** (AUR or local), so `pacman`/`paru` updates it like everything else on warren. | Tiny |
| `claude-code-mods` | Claude Code hook mods (TS), private | Git clone in `~/.claude/mods`, loaded via `CLAUDE_CODE_PLUGIN_DIRS`. Read-only on warren; changed on the desktop. | **Git is the channel.** If you want it hands-free on warren, add a `git pull --ff-only` timer. | Tiny |

**Note 1, Noctalia `git` source.** `noctalia msg plugins source add edward git https://github.com/Edward-Pratt/claude-operator`.
The docs *recommend* a root `catalog.toml` and don't say one is required. They also don't document pinning a branch.
So claude-operator likely needs a generated `catalog.toml` (Noctalia's `update-catalog.py`) before this works. Test it
on the desktop: warren runs noctalia 5.3.0, and claude-operator needs `plugin_api = 43` (5.4), so it won't load
there until warren is updated. This is moot once #1176 merges.

**Note 2, OpenComputers limits.** `installer.lua` already fetches over `https://`. A Tier 1 Data Card has
`data.sha256` ([OC docs](https://ocdoc.cil.li/component:data)). Without one, a pure-Lua sha256 works, just slowly. So
checksum checks are realistic. Signature checks are not, unless the computer has a **Tier 3 Data Card**, and that
offers EC `ecdsa` only, so no minisign/ed25519. Auto-update also means leaving the Internet Card in.

## Is a self-hosted server worth it?

| The server adds | But |
|---|---|
| One stable URL across all programs | GitHub's `releases/latest/download/<asset>` is already a stable URL per repo. A custom domain can sit on GitHub Pages for free. |
| A custom domain | The website is moving to a custom domain anyway. `https://<domain>/updates/...` can be static files there. |
| Private repos | The only private one is claude-code-mods, and it only runs on your machines, which already have `gh` auth. |
| One manifest for everything | Noctalia can't read it, burrow goes through pacman, and orrery reads GitHub. Only Level-Maintainer would use it. |
| Download stats | GitHub already counts release-asset downloads (`download_count` in the API). |

| The server costs | |
|---|---|
| Uptime | Every client's updates fail while it's down, and so does the orrery dashboard on the same box. |
| A bigger attack surface | Whoever gets onto that box can serve code to every client. A server adds *exposure*, not trust. |
| Maintenance | TLS (Caddy makes this easy), OS updates, the publishing pipeline, disk. |

**Verdict:** the server earns its keep only for something GitHub can't do. Today that's nothing. If you still want
one URL for everything, generate `updates/<program>/latest.json` in CI and publish it to the **website** (static,
free, no uptime to manage). Moving that folder onto Oracle later only changes DNS.

## Security

Updates are code execution on your machines. In order of value:

1. **HTTPS only.** Every channel above already is. The exception is Level-Maintainer's README bootstrap command
   (`wget raw.githubusercontent.com/...`), which has no scheme. Make it `https://`.
2. **Checksums from a separate source.** sha256 in the manifest or a `SHA256SUMS` file, checked before installing.
   burrow already publishes one. orrery should check its jar and dashboard tarballs against one too. On its own, a
   checksum only catches corruption, because whoever can replace the file can usually replace the sum.
3. **Signing, where the runtime can verify it.** Use **minisign** (ed25519): `minisign -S` in CI, with the secret key
   as a GitHub Actions secret and the public key baked into each client. That keeps a hacked server or mirror from
   pushing code. It fits burrow (Rust: `minisign-verify` crate) and orrery (Node: a minisign verify library).
   It doesn't fit OC (no ed25519) or Noctalia (git source, no hook). Keep a second offline key on the desktop to
   rotate to if the CI key leaks.
4. **Rollback.** Copy orrery's pattern: install next to the old version, switch a `current` symlink, health-check,
   and switch back on failure. Keep the last N versions. pacman gives burrow/autocopy this via `downgrade` or the
   package cache. Noctalia keeps the old exported copy when a new one needs a newer `plugin_api`. The docs don't
   describe a rollback for any other kind of failure.
5. **Staged rollout.** Holding a new release for a day or two before clients take it is a cheap guard against a bad
   release. It's worth adding anywhere updates are automatic. (orrery's `newerAfterDays` is different: it only flags
   a newer release that has waited too long.)

## Client side: a shared pattern

There's no single library to share across Luau, Rust, Node, Java, OC Lua and shell. The reusable part is a
**contract**, about 30 lines in each language:

1. Fetch `latest.json` (or GitHub `releases/latest`) over HTTPS, at most once per interval, honouring `ETag`.
2. Compare semver with the installed version. Skip if not newer, or if `min_client`/API level isn't met.
3. Download to a temp path. Verify sha256 (and the minisign signature where possible).
4. Install next to the current version, switch atomically, and keep the old one.
5. Health-check. Roll back and record the outcome if it fails.
6. Log or notify the result. Never prompt from a background check.

## Contingency: the server design

If you decide you want it after all:

- **Manifest** `/updates/<program>/latest.json` (and `/updates/<program>/<version>.json` for rollback):
  ```json
  {
    "program": "level-maintainer",
    "version": "1.4.0",
    "published": "2026-10-27T12:00:00Z",
    "url": "https://<domain>/updates/level-maintainer/1.4.0/level-maintainer-1.4.0.tar",
    "sha256": "…",
    "minisig": "https://<domain>/updates/level-maintainer/1.4.0/level-maintainer-1.4.0.tar.minisig",
    "min_client": "1.0.0",
    "notes": "https://github.com/Edward-Pratt/Level-Maintainer/releases/tag/v1.4.0"
  }
  ```
- **Publishing:** push. A reusable workflow in this repo, called by each program's release job on `release: published`:
  1. download the assets;
  2. hash and sign them with minisign;
  3. write the manifest;
  4. `rsync` them over SSH to a restricted `updates` user on the server (`command=`-limited key, write access only
     to `/srv/updates`).

  A webhook listener or poller means running code on the server, so it's more to secure for no gain.
- **Server:** the Oracle box already runs Caddy with automatic TLS for `*.orrery.run`. Add a site block (e.g.
  `updates.<domain>`) with `root * /srv/updates` + `file_server`, a long cache on versioned files, and `no-cache` on
  `latest.json`. With SELinux enforcing, `/srv/updates` needs the `httpd_sys_content_t` label.

## Open questions for Edward

1. **Which programs did you mean?** My reading: claude-operator, burrow (+ addons later), Level-Maintainer, and maybe
   autocopy. orrery is already done, and claude-code-mods only runs on your own machines.
2. **Is the Oracle server the one orrery runs on** (`opc`, Caddy, `dash.orrery.run`)? Is the website's custom domain
   `orrery.run`, or a different one?
3. **"Automatically" means what:** fully silent, or "a new version is available, apply?" burrow's addon approvals
   and orrery's deploys are deliberately the second kind.
4. **burrow:** keep "AUR, no self-updater" (my recommendation), or reverse it?
5. **Level-Maintainer:** is it OK to keep the Internet Card in so it can update itself? Does the computer have a
   Tier 3 Data Card (needed for signature checks)? Its upstream (it's a fork) may already have an update path. Are
   you keeping in sync with it?
6. **Signing:** worth the minisign setup now (burrow/orrery), or checksums only until something needs more?
