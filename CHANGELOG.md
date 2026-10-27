# Changelog

`v1` points at the newest `v1.x.y`.

## v1.3.0

- The updater: `--check` with no stable release yet reports `available none` and succeeds, instead of failing (and
  notifying a failure) every day; a private repo's "release not found" from gh counts as none.
- The updater: `--record DIR`, which a project's install script runs from a clone, so a clone on a release tag counts
  as that release.
- `herald release` asks the remote for its default branch when origin/HEAD isn't set, instead of assuming main.
- docs/ADOPTING.md: plugins whose manager can't meet the rules, installing to a fixed place, the session an update
  runs in, programs with their own updater, and committing the test.

## v1.2.0

- herald's updater, `templates/updater/`: `<name>-update` follows stable releases, checks SHA256SUMS, installs through
  the project's install script, keeps the previous release for `--rollback`, and a daily timer only notifies.
- `herald adopt updater`, and docs/ADOPTING.md, the checklist for adopting a project.
- The shared workflow is unchanged.

## v1.1.0

- Renamed from update-server to herald. Projects call `Edward-Pratt/herald/.github/workflows/release.yml@v1`.
- `herald` command: `herald release` (was `scripts/release.sh`) and `herald adopt`.
- Templates split into `release-build.yml` and `release-source.yml`.
- Actions updated off Node 20: checkout v7.0.1, download-artifact v8.0.2 (which fails on a digest mismatch).
- Tests and CI for this repo.

## v1.0.0

- The shared release workflow: checks the tag, writes SHA256SUMS and notes, publishes; rc tags become pre-releases.
  Release files are kept outside the checkout.
- `scripts/release.sh`, which sends a version change through a pull request before tagging.
