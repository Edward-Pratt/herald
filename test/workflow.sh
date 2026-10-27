#!/bin/bash
# The shared workflow's shell steps, run here the way the runner runs them. Needs Python with PyYAML (PYTHON=...).
# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"
workflow=$herald/.github/workflows/release.yml
step() { # name: prints that step's script
  "${PYTHON:-python3}" -c '
import sys, yaml
for s in yaml.safe_load(open(sys.argv[1]))["jobs"]["release"]["steps"]:
    if s.get("name") == sys.argv[2]: print(s["run"])' "$workflow" "$1"
}
run_step() { bash -euo pipefail -c "$(step "$1")"; }

for ref in refs/tags/v1.2.3 refs/tags/v1.2.3-rc.4; do
  check "$ref is a release tag" env REF=$ref GITHUB_OUTPUT=/dev/null bash -c "$(step 'Check the tag')"
done
for ref in refs/tags/build-main refs/tags/v1.2 refs/heads/main; do
  check "$ref is refused" bash -c "! REF=$ref GITHUB_OUTPUT=/dev/null bash -c \"\$0\"" "$(step 'Check the tag')"
done
out=$(REF=refs/tags/v1.2.3-rc.4 GITHUB_OUTPUT=/dev/stdout run_step 'Check the tag')
check "an rc tag is a pre-release" grep -qx 'prerelease=true' <<<"$out"

project main 2
git tag -a v0.1.0 -m v0.1.0 HEAD~1
git tag -a v0.2.0 -m v0.2.0
# The checkout has a dist/ folder of its own, like burrow's.
mkdir -p dist/systemd
export RUNNER_TEMP=$scratch/runner GITHUB_ENV=$scratch/env
mkdir -p "$RUNNER_TEMP"
: > "$GITHUB_ENV"
run_step "Folder for the release's files"
FILES=$(sed -n 's/^FILES=//p' "$GITHUB_ENV")
export FILES
NAME=p TAG=v0.2.0 VERSION=0.2.0 run_step 'Source archive'
(cd "$FILES" && run_step Checksums) >/dev/null
check "the release files are outside the checkout" test "${FILES#"$PWD"}" = "$FILES"
check "SHA256SUMS covers the archive" bash -c "cd '$FILES' && sha256sum --check --quiet SHA256SUMS"
check "SHA256SUMS doesn't list itself" bash -c "! grep -q ' SHA256SUMS$' '$FILES/SHA256SUMS'"
rm "$FILES/SHA256SUMS"
mkdir "$FILES/folder"
check "a folder in the release files is refused" bash -c "! (cd '$FILES' && bash -c \"\$0\")" "$(step Checksums)"

TAG=v0.2.0 PRERELEASE=false run_step Notes >/dev/null
check "notes list the commits since the last stable release" grep -qx 'Changes since v0.1.0:' notes.md
TAG=v0.1.0 PRERELEASE=false run_step Notes >/dev/null
check "the first release says so" grep -qx 'First release.' notes.md
finish
