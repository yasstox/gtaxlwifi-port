#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "$0")/lib/common.sh"
require_not_root
require_ssh_config

log "SSH $GTAXL_SSH_USER@$GTAXL_SSH_HOST"
ssh_device "$@"
