# Adopting a project

What a project needs so its releases come from herald and it updates itself. Work through it in order; the project is
done when every box under **Done means** is true. Follow the project's own CLAUDE.md, branch and PR habits first.

## 1. Releases

- `herald adopt source` if users get the source as it is (scripts, plugins), or `herald adopt build` if CI builds
  what they download. Fill in the build job: write files, not folders, to `out/` (tar a folder up).
- If the version lives in a file, add an executable `.github/bump-version X.Y.Z` that writes it, and refuses a version
  older than the current one (see burrow's and claude-operator's). If there's no version file, skip it: the tag is
  the version.
- A project with no tags yet whose files already name a version gets a baseline tag `vX.Y.Z` on the commit that set
  it, so `herald release patch` doesn't start from 0.0.1. Tag a commit without the release workflow, so nothing
  publishes.

## 2. Updating

Pick the channel the program already lives in before writing anything:

| The program | Its update channel |
|---|---|
| Has its own package or plugin manager (Noctalia's catalog, Claude Code's plugin marketplaces, pacman) | That manager. Releases feed it; don't add a second updater. |
| Is installed into `~/.local` by an install script (shell, Python, systemd units) | herald's updater: `herald adopt updater` |
| Runs somewhere herald's updater can't (an OpenComputers computer, a server) | Its own small updater, following the same rules below |

herald's updater (`templates/updater/update.sh`) installs as `~/.local/bin/<name>-update`:

- `<name>-update --check` runs daily from `<name>-update.timer` and only notifies: installing is a deliberate step.
- `<name>-update` downloads the newest stable release, checks it against `SHA256SUMS`, unpacks it under
  `~/.local/share/<name>/releases/<tag>`, and runs the project's install script from there with `HERALD_VERSION` set.
- `<name>-update --rollback` reinstalls the release before. The two newest are kept.
- For a private repo, set `private=yes`: it downloads through `gh`, which has the login.

The project's install script is the one place that installs anything, whether run by hand from a clone or by the
updater from a release. It must:

- install the updater (`updater/<name>-update` to `~/.local/bin/`) and its two units, and enable the timer;
- replace files with `install` or write-then-rename, never by overwriting in place (the updater may be the file it's
  replacing, and bash reads a script as it runs);
- work from any folder it's run from, and be safe to run twice.

Every updater, herald's or a program's own, keeps these rules: HTTPS only, check the release's SHA256SUMS before
installing, follow only stable `vX.Y.Z` releases, keep the previous version to go back to, never install from the
timer.

## 3. Docs

The README says how to install, how updates arrive (the daily notice, `<name>-update`, `--rollback`), and how to
release (`herald release minor`, with `--rc` for a pre-release).

## 4. Proof

- The project's own checks pass.
- The updater works against fake releases in a throwaway HOME (see `test/updater.sh`, `HERALD_BASE=file://...` and
  `HERALD_LATEST`): a fresh install through the real install script, up to date, a newer release, rollback, and a
  tampered download refused with the old install kept. Never against the real HOME, the real timer or real services:
  stub `systemctl` and `notify-send` on PATH.
- Open a PR in the project's format. Don't merge it, and don't tag anything: after the merge, the first
  `herald release X.Y.Z --rc` exercises the release workflow.

## Done means

- [ ] `.github/workflows/release.yml` calls `Edward-Pratt/herald/.github/workflows/release.yml@v1`
- [ ] `.github/bump-version` if the version lives in a file, plus a baseline tag if one is needed
- [ ] The update channel from step 2, following stable releases and checking SHA256SUMS
- [ ] A daily check that notifies and never installs
- [ ] A way back to the previous version
- [ ] README: install, updates, releasing
- [ ] Tested as in step 4, with the project's own checks passing
- [ ] A PR, not merged
