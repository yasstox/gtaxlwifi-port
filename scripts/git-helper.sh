#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "$0")/lib/common.sh"
require_not_root

choose_repo() {
  echo "Repositories:"
  echo "  1) meta      $GTAXL_ROOT"
  echo "  2) linux     $GTAXL_ROOT/src/linux"
  echo "  3) pmaports  $GTAXL_ROOT/src/pmaports"
  read -r -p "Select [1-3]: " choice
  case "$choice" in
    1) REPO="$GTAXL_ROOT" ;;
    2) REPO="$GTAXL_ROOT/src/linux" ;;
    3) REPO="$GTAXL_ROOT/src/pmaports" ;;
    *) die "Invalid selection" ;;
  esac
}

choose_repo
BRANCH="$(git -C "$REPO" branch --show-current)"
[[ -n "$BRANCH" ]] || die "Detached HEAD; refusing automatic commit/push."

log "Status: $REPO ($BRANCH)"
git -C "$REPO" status --short

if [[ "$REPO" == "$GTAXL_ROOT" ]]; then
  PMB_BRANCH="$(git -C "$GTAXL_ROOT/src/pmaports" branch --show-current 2>/dev/null || true)"
  if [[ "$PMB_BRANCH" == debug/* ]]; then
    warn "pmaports is currently on debug branch $PMB_BRANCH. Refusing an automatic meta commit so a debug gitlink is not published accidentally."
    echo "Promote/return pmaports to port/gtaxlwifi-6.19 first."
    exit 1
  fi
fi

if [[ -z "$(git -C "$REPO" status --porcelain)" ]]; then
  echo "Nothing to commit."
  exit 0
fi

if [[ "$BRANCH" == debug/* ]]; then
  warn "You are on a debug branch: $BRANCH"
  confirm "Continue anyway?" || exit 0
fi

log "Diff stat"
git -C "$REPO" diff --stat
git -C "$REPO" diff --submodule=log || true

confirm "Stage ALL changes shown above?" || exit 0
git -C "$REPO" add -A

log "Staged diff"
git -C "$REPO" diff --cached --stat
git -C "$REPO" diff --cached --submodule=log || true

read -r -p "Commit message: " MSG
[[ -n "$MSG" ]] || die "Empty commit message"
confirm "Create commit '$MSG'?" || exit 0
git -C "$REPO" commit -m "$MSG"

REMOTE="${GTAXL_GIT_REMOTE:-origin}"
git -C "$REPO" fetch "$REMOTE" --prune

UPSTREAM="$(git -C "$REPO" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)"
if [[ -n "$UPSTREAM" ]]; then
  read -r BEHIND AHEAD < <(git -C "$REPO" rev-list --left-right --count "$UPSTREAM...HEAD")
  echo "Compared with $UPSTREAM: behind=$BEHIND ahead=$AHEAD"
  if (( BEHIND > 0 )); then
    confirm "Rebase onto $UPSTREAM before push?" || die "Refusing to push while behind."
    git -C "$REPO" rebase "$UPSTREAM"
  fi
fi

confirm "Push $BRANCH to $REMOTE?" || exit 0
git -C "$REPO" push "$REMOTE" "$BRANCH"
