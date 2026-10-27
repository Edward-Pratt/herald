#!/bin/bash
# Tags a stable release (or a release candidate) of the project in the current folder. The default branch (main, or
# master in older repos) is the dev branch; a release is a vX.Y.Z tag on it, and the project's release workflow turns
# the tag into a GitHub Release.
#
#   release.sh patch|minor|major     the next version after the newest stable tag
#   release.sh 1.4.0                 exactly this version
#   release.sh minor --rc            a release candidate, v1.5.0-rc.1, then -rc.2 on the next run
#
# Run it from a clean default branch that matches origin. If the project has an executable .github/bump-version, it's
# run with the version (no "v") to write it into the project's own files (Cargo.toml, plugin.toml...). When that
# changes anything, the change goes to a release/vX.Y.Z pull request, since the default branch may only take changes
# through one; once it's merged, pull and run the same command again to tag it. Nothing is pushed until you say yes.
set -euo pipefail

die() { echo "release.sh: $*" >&2; exit 1; }
usage() { sed -n '6,8s/^# //p' "$0" >&2; exit 2; }
ask() { local answer; read -r -p "$1 [y/N] " answer; [[ $answer == [yY]* ]]; }

[[ $# -ge 1 && $# -le 2 ]] || usage
bump=$1 rc=
if [[ $# -eq 2 ]]; then [[ $2 == --rc ]] || usage; rc=1; fi

git rev-parse --show-toplevel >/dev/null 2>&1 || die "not in a git repository"
cd "$(git rev-parse --show-toplevel)"
branch=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null || echo origin/main)
branch=${branch#origin/}
[[ $(git branch --show-current) == "$branch" ]] || die "releases are tagged on $branch; this is $(git branch --show-current)"
[[ -z $(git status --porcelain) ]] || die "the working tree has changes; commit or stash them first"
git fetch --quiet --tags origin "$branch"
[[ $(git rev-parse HEAD) == $(git rev-parse "origin/$branch") ]] || die "$branch and origin/$branch differ; pull or push first"

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

[[ ! -x .github/bump-version ]] || .github/bump-version "$version"
if [[ -n $(git status --porcelain) ]]; then
  # The version has to reach the default branch first, through a pull request, so its CI runs before anything is
  # tagged. Running this again once it's merged finds nothing to change and tags.
  pr=release/$tag
  git switch --quiet -c "$pr"
  git add --all
  git commit --quiet -m "Release $tag" -m "Sets the version to $version. Once this is merged, the release is tagged on $branch."
  git switch --quiet "$branch"
  echo
  git show --stat --format=%s "$pr"
  echo
  if ask "Push $pr and open its pull request?"; then
    git push --quiet -u origin "$pr"
    gh pr create --base "$branch" --head "$pr" --title "Release $tag" \
      --body "Sets the version to $version. Once this is merged, pull $branch and run \`release.sh $*\` again to tag it."
    echo "Merge it, then pull $branch and run release.sh $* again to tag $tag."
  else
    echo "Not pushed. To undo: git branch -D $pr"
  fi
  exit 0
fi

git tag -a "$tag" -m "$tag"
echo
echo "Tagged $tag (previous stable release: v$latest):"
git log --oneline -n 30 "$(git rev-parse -q --verify "refs/tags/v$latest" >/dev/null && echo "v$latest..")$tag"
echo
if ask "Push $tag to origin?"; then
  git push --quiet origin "$tag"
  echo "Pushed. The release workflow publishes $tag."
else
  echo "Not pushed. To undo: git tag -d $tag"
fi
