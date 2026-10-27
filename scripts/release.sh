#!/bin/bash
# Tags a stable release (or a release candidate) of the project in the current folder. main is the dev branch; a
# release is a vX.Y.Z tag on it, and the project's release workflow turns the tag into a GitHub Release.
#
#   release.sh patch|minor|major     the next version after the newest stable tag
#   release.sh 1.4.0                 exactly this version
#   release.sh minor --rc            a release candidate, v1.5.0-rc.1, then -rc.2 on the next run
#
# Run it from a clean main that matches origin/main. If the project has an executable .github/bump-version, it's run
# with the version (no "v") to write it into the project's own files (Cargo.toml, plugin.toml...), and the result is
# committed as "Release vX.Y.Z". Nothing is pushed until you say yes.
set -euo pipefail

die() { echo "release.sh: $*" >&2; exit 1; }
usage() { sed -n '5,7s/^# //p' "$0" >&2; exit 2; }

[[ $# -ge 1 && $# -le 2 ]] || usage
bump=$1 rc=
if [[ $# -eq 2 ]]; then [[ $2 == --rc ]] || usage; rc=1; fi

git rev-parse --show-toplevel >/dev/null 2>&1 || die "not in a git repository"
cd "$(git rev-parse --show-toplevel)"
[[ $(git branch --show-current) == main ]] || die "releases are tagged on main; this is $(git branch --show-current)"
[[ -z $(git status --porcelain) ]] || die "the working tree has changes; commit or stash them first"
git fetch --quiet --tags origin main
[[ $(git rev-parse HEAD) == $(git rev-parse origin/main) ]] || die "main and origin/main differ; pull or push first"

semver='^([0-9]+)\.([0-9]+)\.([0-9]+)$'
# The newest stable tag; release candidates don't count as a base.
latest=$(git tag -l 'v*' | sed 's/^v//' | grep -E "$semver" | sort -V | tail -n1 || true)
latest=${latest:-0.0.0}
[[ $latest =~ $semver ]]
major=${BASH_REMATCH[1]} minor=${BASH_REMATCH[2]} patch=${BASH_REMATCH[3]}

case $bump in
  major) version=$((major + 1)).0.0 ;;
  minor) version=$major.$((minor + 1)).0 ;;
  patch) version=$major.$minor.$((patch + 1)) ;;
  *)
    [[ $bump =~ $semver ]] || die "not a version or major|minor|patch: $bump"
    version=$bump
    [[ $(printf '%s\n%s\n' "$latest" "$version" | sort -V | tail -n1) == "$version" && $version != "$latest" ]] ||
      die "$version isn't newer than the latest release, $latest"
    ;;
esac
git rev-parse -q --verify "refs/tags/v$version" >/dev/null && die "v$version is already released"

if [[ -n $rc ]]; then
  n=$(git tag -l "v$version-rc.*" | sed "s/^v$version-rc\.//" | grep -E '^[0-9]+$' | sort -n | tail -n1 || true)
  version=$version-rc.$((${n:-0} + 1))
fi
tag=v$version

if [[ -x .github/bump-version ]]; then
  .github/bump-version "$version"
  if [[ -n $(git status --porcelain) ]]; then
    git add --all && git commit --quiet -m "Release $tag"
  fi
fi
git tag -a "$tag" -m "$tag"

echo
echo "Tagged $tag (previous stable release: v$latest):"
git log --oneline "$(git rev-parse -q --verify "refs/tags/v$latest" >/dev/null && echo "v$latest..")$tag" | head -n 30
echo
read -r -p "Push main and $tag to origin? [y/N] " answer
if [[ $answer == [yY]* ]]; then
  git push --quiet origin main "$tag"
  echo "Pushed. The release workflow publishes $tag."
else
  echo "Not pushed. To undo: git tag -d $tag$(git log -1 --format=%s | grep -qx "Release $tag" && echo ' && git reset --hard HEAD~1')"
fi
