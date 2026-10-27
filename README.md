# update-server

How Edward's projects ship updates. Despite the name there's no server: GitHub Releases is the update source (see
[RESEARCH.md](RESEARCH.md) for why).

## Branches and channels

- `main` is the dev branch. Everything merges there, and dev channels (`burrow-git`, burrow's `build-main`) follow it.
- A stable release is a `vX.Y.Z` tag on main. Each one becomes a GitHub Release, and the newest is
  `releases/latest`, the stable channel.
- `vX.Y.Z-rc.N` tags are release candidates: pre-releases, which `releases/latest` skips.
- To fix an old version, branch `release/X.Y` from its tag, fix it there, and tag `vX.Y.(Z+1)` on that branch.

## Releasing a project

From a clean `main` of the project:

```sh
~/ClaudeCode/update-server/scripts/release.sh patch   # or minor, major, 1.4.0; add --rc for a candidate
```

It picks the version and runs the project's `.github/bump-version <version>` if there is one (to update `Cargo.toml`,
`plugin.toml` and so on). If that changes anything, it opens a `release/vX.Y.Z` pull request with the change, because
default branches only take changes through pull requests. Merge it once CI passes, pull, and run the same command again:
with nothing left to change, it tags and pushes the tag. It asks before pushing anything.

## Adding a project

Copy [templates/release.yml](templates/release.yml) to the project's `.github/workflows/release.yml` and put its
build in the `build` job. The shared [workflow](.github/workflows/release.yml) checks the tag, adds `SHA256SUMS` and
notes from the commits since the last release, and publishes. Projects call it at `@v1`, a tag in this repo that
moves only for compatible changes.

Public repos can only call workflows in public repos, so this repo has to be public for them to use it.
