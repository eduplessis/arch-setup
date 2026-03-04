#!/usr/bin/env bash

if [[ -z "${ARCH_SETUP_ROOT:-}" ]]; then
  ARCH_SETUP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fi

: "${ARCH_SETUP_PROFILE:=framework-7840u}"
: "${ARCH_SETUP_DRY_RUN:=0}"
: "${ARCH_SETUP_SKIP_AUR:=0}"
: "${ARCH_SETUP_STRICT_AUR:=0}"
: "${ARCH_SETUP_STATE_DIR:=$HOME/.local/state/arch-setup}"
: "${ARCH_SETUP_STAGE_STATE_DIR:=$ARCH_SETUP_STATE_DIR/stages}"
: "${ARCH_SETUP_BACKUP_ROOT:=$ARCH_SETUP_STATE_DIR/backups/manual}"
: "${ARCH_SETUP_FAILED_AUR_FILE:=$ARCH_SETUP_STATE_DIR/failed-aur-packages.txt}"
: "${ARCH_SETUP_DEGRADED_FILE:=$ARCH_SETUP_STATE_DIR/degraded}"
: "${ARCH_SETUP_LOG_FILE:=$ARCH_SETUP_STATE_DIR/install.log}"

if [[ -t 1 ]]; then
  _C_RED='\033[0;31m'
  _C_GREEN='\033[0;32m'
  _C_YELLOW='\033[1;33m'
  _C_BLUE='\033[0;34m'
  _C_RESET='\033[0m'
else
  _C_RED=''
  _C_GREEN=''
  _C_YELLOW=''
  _C_BLUE=''
  _C_RESET=''
fi

log() {
  printf '%b[INFO]%b %s\n' "$_C_BLUE" "$_C_RESET" "$*"
}

success() {
  printf '%b[OK]%b %s\n' "$_C_GREEN" "$_C_RESET" "$*"
}

warn() {
  printf '%b[WARN]%b %s\n' "$_C_YELLOW" "$_C_RESET" "$*"
}

die() {
  printf '%b[ERROR]%b %s\n' "$_C_RED" "$_C_RESET" "$*" >&2
  exit 1
}

run_cmd() {
  if [[ "$ARCH_SETUP_DRY_RUN" == "1" ]]; then
    log "DRY-RUN: $*"
    return 0
  fi
  "$@"
}

sudo_cmd() {
  if [[ "$ARCH_SETUP_DRY_RUN" == "1" ]]; then
    log "DRY-RUN: sudo $*"
    return 0
  fi
  sudo "$@"
}

require_command() {
  local cmd
  for cmd in "$@"; do
    command -v "$cmd" >/dev/null 2>&1 || die "Required command is missing: $cmd"
  done
}

require_sudo() {
  if [[ "$ARCH_SETUP_DRY_RUN" == "1" ]]; then
    return
  fi

  if ! sudo -n true 2>/dev/null; then
    log "Requesting sudo access..."
    sudo -v || die "Failed to obtain sudo access"
  fi
}

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

read_package_list() {
  local file="$1"
  local -n out_ref="$2"
  local raw line

  out_ref=()
  while IFS= read -r raw || [[ -n "$raw" ]]; do
    line="${raw%%#*}"
    line="$(trim "$line")"
    [[ -z "$line" ]] && continue
    out_ref+=("$line")
  done < "$file"
}

sanitize_path() {
  local path="$1"
  path="${path#/}"
  path="${path//\//__}"
  printf '%s' "$path"
}

backup_user_path() {
  local path="$1"
  local backup_target timestamp

  [[ -e "$path" ]] || return 0
  timestamp="$(date +%Y%m%d_%H%M%S)"
  backup_target="$ARCH_SETUP_BACKUP_ROOT/$(sanitize_path "$path").$timestamp"

  if [[ "$ARCH_SETUP_DRY_RUN" == "1" ]]; then
    log "DRY-RUN: mv $path $backup_target"
    return 0
  fi

  mkdir -p "$ARCH_SETUP_BACKUP_ROOT"
  mv "$path" "$backup_target"
  log "Backed up $path -> $backup_target"
}

backup_system_file() {
  local path="$1"
  local backup_target timestamp

  [[ -e "$path" ]] || return 0
  timestamp="$(date +%Y%m%d_%H%M%S)"
  backup_target="$ARCH_SETUP_BACKUP_ROOT/$(sanitize_path "$path").$timestamp"

  if [[ "$ARCH_SETUP_DRY_RUN" == "1" ]]; then
    log "DRY-RUN: sudo cp -a $path $backup_target"
    return 0
  fi

  mkdir -p "$ARCH_SETUP_BACKUP_ROOT"
  sudo cp -a "$path" "$backup_target"
  log "Backed up $path -> $backup_target"
}

load_profile() {
  local common_file="$ARCH_SETUP_ROOT/profiles/common.env"
  local profile_file="$ARCH_SETUP_ROOT/profiles/${ARCH_SETUP_PROFILE}.env"
  local local_env_file="$ARCH_SETUP_ROOT/configs/local/.env"

  [[ -f "$common_file" ]] || die "Missing common profile: $common_file"
  [[ -f "$profile_file" ]] || die "Missing profile: $profile_file"

  # shellcheck source=/dev/null
  source "$common_file"
  # shellcheck source=/dev/null
  source "$profile_file"

  if [[ -f "$local_env_file" ]]; then
    # shellcheck source=/dev/null
    source "$local_env_file"
    log "Loaded local overrides from configs/local/.env"
  fi

  PROFILE_NAME="${PROFILE_NAME:-$ARCH_SETUP_PROFILE}"
  log "Profile loaded: $PROFILE_NAME"
}
