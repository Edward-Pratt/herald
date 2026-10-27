#!/bin/bash
# herald release against scratch projects with bare origins.
# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"
release() { "$herald/bin/herald" release "$@"; }

project main 1
echo y | release patch >/dev/null
check "first patch release is v0.0.1" test "$(remote_tags)" = "v0.0.1 "
echo y | release minor --rc >/dev/null
echo y | release minor --rc >/dev/null
check "release candidates count up" test "$(remote_tags)" = "v0.0.1 v0.1.0-rc.1 v0.1.0-rc.2 "
check "an older version is refused" refuses "isn't newer" release 0.0.1
touch dirty
check "a dirty tree is refused" refuses "working tree has changes" release patch
rm dirty
git switch -q -c feature
check "another branch is refused" refuses "releases are tagged on main" release patch
git switch -q main
echo n | release patch >/dev/null
check "declining keeps the tag local" test "$(remote_tags)" = "v0.0.1 v0.1.0-rc.1 v0.1.0-rc.2 "
git tag -d v0.0.2 >/dev/null

project master 40
echo y | release minor >/dev/null
check "master is found as the default branch, and a long history doesn't stop the push" test "$(remote_tags)" = "v0.1.0 "

project main 1
mkdir .github
# shellcheck disable=SC2016 # a script for the test project, expanded when it runs
printf '#!/bin/sh\necho "$1" > VERSION\n' > .github/bump-version
chmod +x .github/bump-version
echo 0.0.0 > VERSION
git add -A && git commit -qm version && git push -q origin main
# Like a default branch that only takes pull requests.
# shellcheck disable=SC2016 # a script for the test project, expanded when it runs
printf '#!/bin/sh\nwhile read o n r; do [ "$r" = refs/heads/main ] && exit 1; done; exit 0\n' > ../origin.git/hooks/pre-receive
chmod +x ../origin.git/hooks/pre-receive
echo y | release 0.1.0 --rc >/dev/null
check "a version change goes to a release branch" git ls-remote --exit-code origin refs/heads/release/v0.1.0-rc.1
check "and opens its pull request" grep -q "pr create --base main --head release/v0.1.0-rc.1" "$scratch/gh.log"
check "and leaves main clean" test -z "$(git status --porcelain)"
check "with nothing tagged yet" test "$(remote_tags)" = ""
(cd ../origin.git && git update-ref refs/heads/main refs/heads/release/v0.1.0-rc.1)
git pull -q --ff-only origin main
echo y | release 0.1.0 --rc >/dev/null
check "after the merge, running again tags it" test "$(remote_tags)" = "v0.1.0-rc.1 "
check "on the merged version" test "$(git show v0.1.0-rc.1:VERSION)" = "0.1.0-rc.1"
finish
