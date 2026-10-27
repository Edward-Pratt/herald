# shellcheck shell=bash
# Shared by the tests: a scratch folder, a stub gh, and checks that count failures.
set -euo pipefail
# shellcheck disable=SC2034 # used by the tests that source this
herald=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
mkdir -p "$scratch/bin"
# herald release opens pull requests with gh; the stub only records the call.
# With GH_RELEASE_VIEW set it answers `gh release view` with that text: a tag succeeds, anything else
# ("release not found", "HTTP 401") fails, as gh does.
cat > "$scratch/bin/gh" <<GH
#!/bin/sh
echo "gh \$*" >> "$scratch/gh.log"
if [ "\$1 \$2" = "release view" ] && [ -n "\$GH_RELEASE_VIEW" ]; then
  echo "\$GH_RELEASE_VIEW"
  case \$GH_RELEASE_VIEW in v*) exit 0 ;; *) exit 1 ;; esac
fi
GH
chmod +x "$scratch/bin/gh"
export PATH=$scratch/bin:$PATH
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com
failures=0

ok() { echo "ok   $1"; }
fail() { echo "FAIL $1" >&2; failures=$((failures + 1)); }
check() { # name command...
  local name=$1
  shift
  if "$@" >/dev/null 2>&1; then ok "$name"; else fail "$name"; fi
}
refuses() { # pattern command...: the command fails, saying why
  local pattern=$1 out
  shift
  ! out=$("$@" </dev/null 2>&1) && grep -q -- "$pattern" <<<"$out"
}
finish() {
  [[ $failures -eq 0 ]] || { echo "$failures failed" >&2; exit 1; }
}

# A project with a bare origin whose default branch is $1, and $2 commits.
project() { # branch commits
  local dir
  dir=$(mktemp -d "$scratch/project.XXXX")
  git init -q --bare -b "$1" "$dir/origin.git"
  git clone -q "$dir/origin.git" "$dir/work" 2>/dev/null
  cd "$dir/work"
  local i
  for ((i = 1; i <= $2; i++)); do git commit -q --allow-empty -m "commit $i"; done
  git push -q origin "$1"
  git remote set-head origin -a >/dev/null
}
remote_tags() { git ls-remote --tags origin | sed -n 's|.*refs/tags/\([^^]*\)$|\1|p' | sort | tr '\n' ' '; }
