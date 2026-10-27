# Decisions

Why herald works the way it does. The original brief and research (a self-hosted update server on the Oracle box)
are in git history: `git show v1.0.0:BRIEF.md`, `git show v1.0.0:RESEARCH.md`.

## GitHub Releases, not an update server (2026-10-27)

The brief asked for an Oracle Cloud server hosting every project's updates. We chose GitHub Releases instead:

- Most projects already had an update channel that a server couldn't plug into. Noctalia only reads git sources and
  updates them itself every 6 hours. burrow downloads its own builds. orrery deploys from GitHub Releases on its own.
- GitHub already gives each repo a stable URL (`releases/latest/download/<file>`), HTTPS, download counts and uptime.
- A server adds exposure rather than trust: whoever gets onto it can serve code to every client. It also shares a box
  with orrery, so its downtime would be orrery's too.

The Oracle box stays orrery's. If a real need appears (private repos for outside users, one dashboard of versions),
generate `updates/<project>/latest.json` in CI and serve it statically; moving it later changes only DNS.

## Channels: the default branch is dev, tags are stable

- The default branch (main) is each project's dev channel.
- A `vX.Y.Z` tag on it is a stable release. GitHub's latest release, which stable clients follow, is the newest one.
- `vX.Y.Z-rc.N` tags are release candidates, published as pre-releases, which `releases/latest` skips.
- To fix an old version, branch `release/X.Y` from its tag and tag the fix there.

Tags rather than a long-lived stable branch: a branch has to be merged into on every release and drifts; a tag can't.

## Version changes go through a pull request

Default branches only take changes through pull requests (warren's "default branch via PR" ruleset). So when
`.github/bump-version` changes the project's files, `herald release` opens a `release/vX.Y.Z` pull request, and runs
again after the merge to tag. The version commit gets CI before anything is tagged.

## In scope

| Project | Update channel |
|---|---|
| burrow | `burrow-update`: `--release` follows builds of main, `--stable` follows tagged releases |
| claude-operator | The Noctalia community catalog, which carries tagged versions |
| autocopy, pulse, claude-code-mods, Level-Maintainer | Being adopted |

Out of scope: orrery (it deploys itself), dotfiles, the website, the profile README, community-plugins (only used to
send catalog PRs), and portfolio or coursework repos, which aren't installed anywhere.

## Security

Updates are code execution on Edward's machines.

- **HTTPS only**, redirects included.
- **SHA256SUMS** with every release, checked before installing. It comes from the same release, so it catches
  corruption and half-published releases, not someone who can change the release.
- **Signing** (minisign, key in CI secrets) would add little while CI and the repos share one GitHub account. Revisit
  if releases are ever served from somewhere else.
- **Install beside, then switch**, keeping the previous version, so a bad update can be rolled back.
- **Check, then notify** by default: a timer checks and says an update is ready; installing is a deliberate step.
- **Pinned actions**: the shared workflow pins every action to a commit, and the write token reaches only its publish
  step.
