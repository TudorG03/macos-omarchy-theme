#!/bin/bash
# Static checks for the repo. Needs bash and jq; plugin validation also needs Omarchy.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1
status=0
fail() { echo "FAIL: $*"; status=1; }

for script in install.sh uninstall.sh hooks/cupertino tests/check.sh; do
  bash -n "$script" || fail "$script has a syntax error"
done

for dir in plugins/*/; do
  id=$(basename "$dir")
  jq -e . "$dir/manifest.json" >/dev/null || fail "$id has an invalid manifest"
  [[ $(jq -r .id "$dir/manifest.json") == "$id" ]] || fail "$id: manifest id doesn't match its folder"
  if command -v omarchy >/dev/null; then
    omarchy plugin validate "$dir" >/dev/null || fail "$id failed omarchy plugin validate"
  fi
  grep -q "$id" hooks/cupertino || fail "$id is not enabled by the hook"
done

[[ -z $(find . -path ./.git -prune -o -type l -print) ]] || fail "symlinks found"

# Files that would tie the repo to one person's machine.
if grep -rInE '/home/[a-z]|/Users/[a-z]|/tmp/claude|[A-Za-z0-9._%+-]+@(gmail|outlook|hotmail|yahoo|proton)' . \
  --exclude-dir=.git --exclude=bangs.tsv --exclude=check.sh; then
  fail "personal paths or email addresses found"
fi

(( status == 0 )) && echo "All checks passed."
exit "$status"
