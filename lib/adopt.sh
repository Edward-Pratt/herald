#!/bin/bash
# Gives the project in the current folder herald's release workflow, as .github/workflows/release.yml:
#
#   herald adopt build     the project builds what users download (fill in the template's build job)
#   herald adopt source    the project ships its source as it is; releases carry a source archive
#   herald adopt updater   the project's own updater, in updater/: <name>-update and its daily check timer
#
# It refuses to overwrite files the project already has, unless given --force. Nothing is committed.
# See docs/ADOPTING.md for the rest of adopting a project.
set -euo pipefail

die() { echo "herald adopt: $*" >&2; exit 1; }
usage() { sed -n '4,6s/^# //p' "$0" >&2; exit 2; }

kind=${1:-}
[[ $kind == build || $kind == source || $kind == updater ]] || usage
force=
if [[ $# -eq 2 ]]; then [[ $2 == --force ]] || usage; force=1; fi
[[ $# -le 2 ]] || usage

git rev-parse --show-toplevel >/dev/null 2>&1 || die "not in a git repository"
cd "$(git rev-parse --show-toplevel)"
templates=$(dirname "$(dirname "$(readlink -f "$0")")")/templates

if [[ $kind == updater ]]; then
  # The project's name and repo come from its origin, so the updater follows the right releases.
  repo=$(git remote get-url origin | sed -E 's#^(https://github\.com/|git@github\.com:)##; s#\.git$##')
  [[ $repo =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || die "origin isn't a GitHub repo: $repo"
  name=$(tr '[:upper:]' '[:lower:]' <<<"${repo#*/}")
  for f in "updater/$name-update" "updater/$name-update.service" "updater/$name-update.timer"; do
    [[ ! -e $f || -n $force ]] || die "$f already exists; --force replaces it"
  done
  mkdir -p updater
  sed -e "s/^name=PROJECT /name=$name /" -e "s|^repo=Edward-Pratt/PROJECT |repo=$repo |" \
    "$templates/updater/update.sh" > "updater/$name-update"
  chmod +x "updater/$name-update"
  for unit in service timer; do
    sed "s/PROJECT/$name/g" "$templates/updater/PROJECT-update.$unit" > "updater/$name-update.$unit"
  done
  echo "Wrote updater/$name-update and its .service and .timer."
  echo "Next: set private=yes in it if the repo is private, and make the install script install all three"
  echo "(the timer enabled) from the release folder it runs in. See docs/ADOPTING.md."
  exit 0
fi

target=.github/workflows/release.yml
[[ ! -e $target || -n $force ]] || die "$target already exists; --force replaces it"
mkdir -p .github/workflows
cp "$templates/release-$kind.yml" "$target"
echo "Wrote $target."
[[ $kind == source ]] || echo "Next: replace the template's Build step with the project's build."
if [[ ! -x .github/bump-version ]]; then
  echo "If the project keeps its version in a file, add an executable .github/bump-version that writes it."
fi
echo "Then commit, and release with: herald release minor --rc"
