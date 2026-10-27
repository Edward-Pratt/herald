# Changelog

`v1` points at the newest `v1.x.y`.

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
