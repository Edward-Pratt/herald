#!/bin/bash
# herald adopt writes the template for the kind of project.
# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"
adopt() { "$herald/bin/herald" adopt "$@"; }

project main 1
adopt source >/dev/null
check "source writes the source template" cmp .github/workflows/release.yml "$herald/templates/release-source.yml"
check "an existing release.yml is kept" refuses "already exists" adopt build
adopt build --force >/dev/null
check "--force replaces it" cmp .github/workflows/release.yml "$herald/templates/release-build.yml"
check "an unknown kind is refused" refuses "herald adopt build" adopt binary
check "the templates call this repo's workflow at v1" grep -q 'Edward-Pratt/herald/.github/workflows/release.yml@v1' \
  "$herald/templates/release-build.yml" "$herald/templates/release-source.yml"
git remote set-url origin https://github.com/Edward-Pratt/Demo.git
adopt updater >/dev/null
check "updater writes the command named after the repo" test -x updater/demo-update
check "with the repo filled in" grep -qx 'repo=Edward-Pratt/Demo .*' updater/demo-update
check "and its timer units" grep -q 'demo-update --check' updater/demo-update.service
check "an existing updater is kept" refuses "already exists" adopt updater
finish
