#!/bin/bash
# templates/updater/update.sh against releases in a folder (HERALD_BASE=file://...), in a throwaway HOME.
# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"
export HOME=$scratch/home XDG_DATA_HOME=$scratch/home/.local/share
mkdir -p "$HOME"
releases=$scratch/releases
export HERALD_BASE=file://$releases
# The project's updater, as adopting it would set it up.
sed -e 's/^name=PROJECT /name=demo /' -e 's|^repo=Edward-Pratt/PROJECT |repo=Edward-Pratt/demo |' \
  "$herald/templates/updater/update.sh" > "$scratch/demo-update"
chmod +x "$scratch/demo-update"
update() { "$scratch/demo-update" "$@"; }

release() { # tag: a release like herald's workflow makes, whose install.sh records the version it installed
  local tag=$1 version=${1#v} src
  src=$scratch/src/demo-$version
  mkdir -p "$src" "$releases/$tag"
  # shellcheck disable=SC2016 # the release's install script, expanded when it runs
  printf '#!/bin/sh\nmkdir -p "$HOME/.local/bin"\necho "$HERALD_VERSION" > "$HOME/.local/bin/demo-installed"\n' > "$src/install.sh"
  chmod +x "$src/install.sh"
  tar -czf "$releases/$tag/demo-$version.tar.gz" -C "$scratch/src" "demo-$version"
  (cd "$releases/$tag" && sha256sum "demo-$version.tar.gz" > SHA256SUMS)
}
installed() { cat "$HOME/.local/bin/demo-installed" 2>/dev/null; }

release v1.0.0
release v1.1.0
# Any gh call from here to the private-repo checks is a mistake: the public path must not use it.
: > "$scratch/gh.log"
export HERALD_LATEST=v1.0.0
check "a check before installing reports what's available" bash -c "'$scratch/demo-update' --check | grep -qx 'available v1.0.0'"
check "and remembers it said so" grep -qx v1.0.0 "$XDG_DATA_HOME/demo/notified"
check "nothing is installed by a check" test -z "$(installed)"
update >/dev/null
check "an update runs the release's install script" test "$(installed)" = 1.0.0
check "running again says it's up to date" bash -c "'$scratch/demo-update' | grep -q 'up to date: v1.0.0'"
export HERALD_LATEST=v1.1.0
update >/dev/null
check "a newer release is installed" test "$(installed)" = 1.1.0
update --rollback >/dev/null
check "rollback reinstalls the one before" test "$(installed)" = 1.0.0
check "only the two newest releases are kept" test "$(find "$XDG_DATA_HOME/demo/releases" -mindepth 1 -maxdepth 1 | wc -l)" = 2

release v1.2.0
echo tampered >> "$releases/v1.2.0/demo-1.2.0.tar.gz"
export HERALD_LATEST=v1.2.0
check "a download that doesn't match its checksum is refused" refuses "doesn't match its checksum" update
check "and what's installed stays" test "$(installed)" = 1.0.0
release v1.3.0
: > "$releases/v1.3.0/SHA256SUMS"
export HERALD_LATEST=v1.3.0
check "a release with no checksum for the file is refused" refuses "no checksum" update
export HERALD_LATEST=build-main
check "a latest that isn't a vX.Y.Z tag means no stable release" refuses "no stable release" update
check "and a check with no stable release reports none without failing" bash -c "'$scratch/demo-update' --check | grep -qx 'available none'"

# A clone install sitting on a release tag records that release, so the first check doesn't announce it.
clone=$scratch/clone
git init -q "$clone"
git -C "$clone" commit -q --allow-empty -m one
git -C "$clone" tag -a v1.3.0 -m v1.3.0
rm -f "$XDG_DATA_HOME/demo/installed"
update --record "$clone"
check "--record notes a clone on a release tag" grep -qx v1.3.0 "$XDG_DATA_HOME/demo/installed"
git -C "$clone" commit -q --allow-empty -m two
rm -f "$XDG_DATA_HOME/demo/installed"
update --record "$clone"
check "but not a clone between releases" test ! -e "$XDG_DATA_HOME/demo/installed"

check "a public repo never called gh" test ! -s "$scratch/gh.log"

# A private repo asks gh, which says "release not found" when there's no stable release.
unset HERALD_LATEST
sed -i 's/^private=no /private=yes/' "$scratch/demo-update"
: > "$scratch/gh.log"
check "a private repo with no stable release reports none" env GH_RELEASE_VIEW="release not found" \
  bash -c "'$scratch/demo-update' --check | grep -qx 'available none'"
check "through gh" grep -q '^gh release view --repo Edward-Pratt/demo' "$scratch/gh.log"
check "another gh failure is a failure" refuses "HTTP 401" env GH_RELEASE_VIEW="HTTP 401" "$scratch/demo-update" --check
finish
