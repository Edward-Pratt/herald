# herald

Releases and updates for Edward's projects. A project's default branch is its dev channel, a `vX.Y.Z` tag is a stable
release, and GitHub Releases is where updates come from: there's no update server. [docs/decisions.md](docs/decisions.md)
says why.

## Setup

```sh
ln -s ~/ClaudeCode/herald/bin/herald ~/.local/bin/herald
```

## Releasing a project

From the project's default branch, clean and up to date:

```sh
herald release minor        # or patch, major, or 1.4.0
herald release minor --rc   # a release candidate (a pre-release), v1.5.0-rc.1, then rc.2
```

It works out the version from the project's tags. If the project has an executable `.github/bump-version`, it runs it
with the version to write it into the project's files (`Cargo.toml`, `plugin.toml`...). When that changes anything,
herald opens a `release/vX.Y.Z` pull request; merge it once CI passes, pull, and run the same command again to tag.
It asks before pushing anything.

## Adopting a project

```sh
herald adopt build    # the project builds what users download: fill in the template's build job
herald adopt source   # the project ships its source; releases carry a source archive
```

That writes `.github/workflows/release.yml`, which calls the [shared workflow](.github/workflows/release.yml) at
`@v1`. On each tag it checks the tag, writes `SHA256SUMS` and notes from the commits since the last release, and
publishes the release. Add `.github/bump-version` if the version lives in a file (see burrow's or claude-operator's).

## Layout

| Path | What |
|---|---|
| `bin/herald` | The command |
| `lib/release.sh`, `lib/adopt.sh` | Its subcommands |
| `.github/workflows/release.yml` | The shared release workflow projects call |
| `templates/` | The project workflows `herald adopt` writes |
| `test/` | Tests, run by CI: `test/run` |
| `docs/decisions.md` | Why it works this way |

## Versions

Projects call the shared workflow at `v1`. Each change gets a fixed `v1.x.y` tag, and `v1` moves to the newest
compatible one; a breaking change would start `v2`. See [CHANGELOG.md](CHANGELOG.md).
