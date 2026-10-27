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
finish
