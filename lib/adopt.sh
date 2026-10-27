#!/bin/bash
# Gives the project in the current folder herald's release workflow, as .github/workflows/release.yml:
#
#   herald adopt build     the project builds what users download (fill in the template's build job)
#   herald adopt source    the project ships its source as it is; releases carry a source archive
#
# It refuses to overwrite a release.yml the project already has, unless given --force. Nothing is committed.
set -euo pipefail

die() { echo "herald adopt: $*" >&2; exit 1; }
usage() { sed -n '4,5s/^# //p' "$0" >&2; exit 2; }

kind=${1:-}
[[ $kind == build || $kind == source ]] || usage
force=
if [[ $# -eq 2 ]]; then [[ $2 == --force ]] || usage; force=1; fi
[[ $# -le 2 ]] || usage

git rev-parse --show-toplevel >/dev/null 2>&1 || die "not in a git repository"
cd "$(git rev-parse --show-toplevel)"
target=.github/workflows/release.yml
[[ ! -e $target || -n $force ]] || die "$target already exists; --force replaces it"

templates=$(dirname "$(dirname "$(readlink -f "$0")")")/templates
mkdir -p .github/workflows
cp "$templates/release-$kind.yml" "$target"
echo "Wrote $target."
[[ $kind == source ]] || echo "Next: replace the template's Build step with the project's build."
if [[ ! -x .github/bump-version ]]; then
  echo "If the project keeps its version in a file, add an executable .github/bump-version that writes it."
fi
echo "Then commit, and release with: herald release minor --rc"
