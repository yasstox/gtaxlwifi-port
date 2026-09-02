#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "$0")/lib/common.sh"
require_not_root

PMAPORTS="$GTAXL_ROOT/src/pmaports"
META="$GTAXL_ROOT"
SUBJECT='linux-postmarketos-exynos7870: enable Samsung PMIC support'
CLEAN_BRANCH='port/gtaxlwifi-7.1'

FIX="$(git -C "$PMAPORTS" log --all --format='%H' --grep="^${SUBJECT}$" -n1)"
[[ -n "$FIX" ]] || die "Could not find PMIC fix commit by subject"

log "Candidate fix"
git -C "$PMAPORTS" show --stat --oneline "$FIX"
CHANGED="$(git -C "$PMAPORTS" diff-tree --no-commit-id --name-only -r "$FIX")"
echo "$CHANGED"
if echo "$CHANGED" | grep -Ev '^device/testing/linux-postmarketos-exynos7870/(APKBUILD|config-postmarketos-exynos7870\.aarch64)$' >/dev/null; then
  die "PMIC commit touches unexpected paths; promote manually."
fi
confirm "Promote only this PMIC fix to $CLEAN_BRANCH?" || exit 0

log "Updating clean pmaports branch"
git -C "$PMAPORTS" fetch origin --prune
git -C "$PMAPORTS" switch "$CLEAN_BRANCH"
git -C "$PMAPORTS" pull --ff-only origin "$CLEAN_BRANCH"
if ! git -C "$PMAPORTS" merge-base --is-ancestor "$FIX" HEAD; then
  git -C "$PMAPORTS" cherry-pick "$FIX"
fi
NEW_PMAPORTS="$(git -C "$PMAPORTS" rev-parse HEAD)"
git -C "$PMAPORTS" push origin "$CLEAN_BRANCH"

log "Synchronizing meta main with GitHub before recording submodule"
# Temporarily restore the pmaports checkout to the commit currently recorded by
# the meta repository so a pull/rebase is not blocked by a modified gitlink.
git -C "$META" submodule update --checkout src/pmaports
git -C "$META" fetch origin main
git -C "$META" pull --rebase origin main

# Return pmaports to the freshly promoted clean branch/commit.
git -C "$PMAPORTS" fetch origin --prune
git -C "$PMAPORTS" switch "$CLEAN_BRANCH"
git -C "$PMAPORTS" reset --hard "$NEW_PMAPORTS"

log "Meta submodule diff"
git -C "$META" add src/pmaports
git -C "$META" diff --cached --submodule=log
confirm "Commit the new pmaports pointer to meta main?" || exit 0
git -C "$META" commit -m 'pmaports: enable Samsung PMIC support'
confirm "Push meta main?" || exit 0
git -C "$META" push origin main

log "PMIC fix promoted cleanly. Debug-only pmaports commits were not cherry-picked."
