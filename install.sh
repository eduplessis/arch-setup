#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STAGES_DIR="$SCRIPT_DIR/scripts/stages"

DEFAULT_PROFILE="framework-7840u"
DEFAULT_STAGES=(
  "00-preflight"
  "10-packages-official"
  "20-packages-aur"
  "30-configs"
  "40-system-services"
  "50-user-services"
  "60-hardware"
  "90-verify"
)

COMMAND="all"
STAGE_NAME=""
ARCH_SETUP_PROFILE="$DEFAULT_PROFILE"
ARCH_SETUP_DRY_RUN=0
ARCH_SETUP_FORCE=0
ARCH_SETUP_SKIP_AUR=0
ARCH_SETUP_STRICT_AUR=0
ARCH_SETUP_LOG_FILE=""

RUN_ID="$(date +%Y%m%d_%H%M%S)"
ARCH_SETUP_STATE_DIR="${HOME}/.local/state/arch-setup"
ARCH_SETUP_STAGE_STATE_DIR="$ARCH_SETUP_STATE_DIR/stages"
ARCH_SETUP_BACKUP_ROOT="$ARCH_SETUP_STATE_DIR/backups/$RUN_ID"
ARCH_SETUP_FAILED_AUR_FILE="$ARCH_SETUP_STATE_DIR/failed-aur-packages.txt"
ARCH_SETUP_DEGRADED_FILE="$ARCH_SETUP_STATE_DIR/degraded"
ARCH_SETUP_ROOT="$SCRIPT_DIR"

SUDO_KEEPALIVE_PID=""

usage() {
  cat << 'USAGE'
Usage:
  ./install.sh [all] [options]
  ./install.sh stage <name> [options]
  ./install.sh verify [options]

Options:
  --profile <name>      Hardware profile (default: framework-7840u)
  --dry-run             Print actions without applying changes
  --force               Re-run completed stages in "all"
  --no-aur              Skip AUR stage
  --strict-aur          Fail immediately if any AUR package fails
  --log-file <path>     Explicit log file path
  -h, --help            Show this help

Examples:
  ./install.sh all
  ./install.sh stage 30-configs --profile framework-7840u
  ./install.sh verify
USAGE
}

log() {
  printf '[INFO] %s\n' "$*"
}

warn() {
  printf '[WARN] %s\n' "$*"
}

die() {
  printf '[ERROR] %s\n' "$*" >&2
  exit 1
}

ensure_sudo() {
  if [[ "$ARCH_SETUP_DRY_RUN" == "1" ]]; then
    return
  fi

  if ! sudo -n true 2>/dev/null; then
    log "This installer requires sudo access."
    sudo -v
  fi
}

start_sudo_keepalive() {
  if [[ "$ARCH_SETUP_DRY_RUN" == "1" ]]; then
    return
  fi

  while true; do
    sudo -n true
    sleep 60
  done >/dev/null 2>&1 &
  SUDO_KEEPALIVE_PID="$!"
}

cleanup() {
  if [[ -n "$SUDO_KEEPALIVE_PID" ]]; then
    kill "$SUDO_KEEPALIVE_PID" >/dev/null 2>&1 || true
  fi
}

trap cleanup EXIT

normalize_stage_name() {
  local raw="$1"
  raw="${raw%.sh}"
  printf '%s' "$raw"
}

stage_exists() {
  local stage="$1"
  [[ -f "$STAGES_DIR/${stage}.sh" ]]
}

run_stage() {
  local stage="$1"
  local skip_allowed="$2"
  local stage_file="$STAGES_DIR/${stage}.sh"
  local marker="$ARCH_SETUP_STAGE_STATE_DIR/${stage}.done"

  stage_exists "$stage" || die "Unknown stage: $stage"

  if [[ "$skip_allowed" == "1" && "$ARCH_SETUP_FORCE" == "0" && -f "$marker" ]]; then
    log "Skipping stage $stage (already completed). Use --force to rerun."
    return
  fi

  log "Running stage: $stage"
  if bash "$stage_file"; then
    if [[ "$ARCH_SETUP_DRY_RUN" == "0" ]]; then
      date -Is > "$marker"
    fi
    log "Stage complete: $stage"
  else
    die "Stage failed: $stage"
  fi
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      all)
        COMMAND="all"
        shift
        ;;
      verify)
        COMMAND="verify"
        shift
        ;;
      stage)
        COMMAND="stage"
        shift
        [[ $# -gt 0 ]] || die "Missing stage name after 'stage'."
        STAGE_NAME="$(normalize_stage_name "$1")"
        shift
        ;;
      --profile)
        shift
        [[ $# -gt 0 ]] || die "Missing value for --profile"
        ARCH_SETUP_PROFILE="$1"
        shift
        ;;
      --dry-run)
        ARCH_SETUP_DRY_RUN=1
        shift
        ;;
      --force)
        ARCH_SETUP_FORCE=1
        shift
        ;;
      --no-aur)
        ARCH_SETUP_SKIP_AUR=1
        shift
        ;;
      --strict-aur)
        ARCH_SETUP_STRICT_AUR=1
        shift
        ;;
      --log-file)
        shift
        [[ $# -gt 0 ]] || die "Missing value for --log-file"
        ARCH_SETUP_LOG_FILE="$1"
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        die "Unknown argument: $1"
        ;;
    esac
  done

  if [[ "$COMMAND" == "stage" && -z "$STAGE_NAME" ]]; then
    die "Stage name is required: ./install.sh stage <name>"
  fi
}

setup_logging() {
  if [[ -z "$ARCH_SETUP_LOG_FILE" ]]; then
    ARCH_SETUP_LOG_FILE="$ARCH_SETUP_STATE_DIR/install-$RUN_ID.log"
  fi

  if [[ "$ARCH_SETUP_DRY_RUN" == "0" ]]; then
    mkdir -p "$ARCH_SETUP_STATE_DIR" "$ARCH_SETUP_STAGE_STATE_DIR" "$ARCH_SETUP_BACKUP_ROOT"
    mkdir -p "$(dirname "$ARCH_SETUP_LOG_FILE")"
    exec > >(tee -a "$ARCH_SETUP_LOG_FILE") 2>&1
    ln -sfn "$ARCH_SETUP_LOG_FILE" "$ARCH_SETUP_STATE_DIR/latest.log"
  fi
}

print_run_context() {
  log "Arch setup root: $ARCH_SETUP_ROOT"
  log "Command: $COMMAND"
  if [[ "$COMMAND" == "stage" ]]; then
    log "Stage: $STAGE_NAME"
  fi
  log "Profile: $ARCH_SETUP_PROFILE"
  log "Dry run: $ARCH_SETUP_DRY_RUN"
  log "Force rerun: $ARCH_SETUP_FORCE"
  log "Skip AUR: $ARCH_SETUP_SKIP_AUR"
  log "Strict AUR: $ARCH_SETUP_STRICT_AUR"
  log "State dir: $ARCH_SETUP_STATE_DIR"
  log "Backup dir: $ARCH_SETUP_BACKUP_ROOT"
  log "Log file: $ARCH_SETUP_LOG_FILE"
}

run_all() {
  local stage
  for stage in "${DEFAULT_STAGES[@]}"; do
    run_stage "$stage" "1"
  done
}

run_verify() {
  run_stage "90-verify" "0"
}

run_single_stage() {
  run_stage "$STAGE_NAME" "0"
}

print_completion_summary() {
  log "Run complete."
  if [[ -f "$ARCH_SETUP_DEGRADED_FILE" ]]; then
    warn "Completed with degraded status (typically AUR failures)."
    if [[ -f "$ARCH_SETUP_FAILED_AUR_FILE" ]]; then
      warn "Failed AUR packages:"
      sed 's/^/  - /' "$ARCH_SETUP_FAILED_AUR_FILE"
    fi
  fi

  log "Detailed log: $ARCH_SETUP_LOG_FILE"
  log "Backups: $ARCH_SETUP_BACKUP_ROOT"
}

main() {
  parse_args "$@"
  setup_logging

  export ARCH_SETUP_ROOT
  export ARCH_SETUP_PROFILE
  export ARCH_SETUP_DRY_RUN
  export ARCH_SETUP_FORCE
  export ARCH_SETUP_SKIP_AUR
  export ARCH_SETUP_STRICT_AUR
  export ARCH_SETUP_LOG_FILE
  export ARCH_SETUP_STATE_DIR
  export ARCH_SETUP_STAGE_STATE_DIR
  export ARCH_SETUP_BACKUP_ROOT
  export ARCH_SETUP_FAILED_AUR_FILE
  export ARCH_SETUP_DEGRADED_FILE

  print_run_context
  ensure_sudo
  start_sudo_keepalive

  case "$COMMAND" in
    all)
      run_all
      ;;
    verify)
      run_verify
      ;;
    stage)
      run_single_stage
      ;;
    *)
      die "Unsupported command: $COMMAND"
      ;;
  esac

  print_completion_summary
}

main "$@"
