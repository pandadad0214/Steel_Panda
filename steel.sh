#!/usr/bin/env bash
# Steel Panda 0.3.0 — local task runner.
#
# Runs every regular *.sh file in TASK_DIR (default: Tasks next to this script).
# Appends runner messages and task output to LOG_FILE (default: steel.log next
# to this script). Records each task exit code. Exit 0 when every task exits 0,
# exit 1 when a task fails, exit 2 when Steel itself cannot start.
#
# Stop after the first failure with --stop-on-error or STEEL_STOP_ON_ERROR=1.
# The default is to run every matching task.
#
# Bash 3.2 or newer. Linux, macOS, and Termux. No network.
# Invoke as: bash steel.sh
# A Watchdog Panda on-failure command can call this script. Steel does not
# start Watchdog and does not need it installed.

VERSION="0.3.0"

set -u
set -o pipefail

usage() {
  cat <<EOF
Usage: steel.sh [--stop-on-error]

Steel Panda $VERSION runs every regular *.sh file in TASK_DIR and appends
output to LOG_FILE. Bash 3.2 or newer. No network. No terminal required.

Options:
  --stop-on-error   Halt after the first task that exits non-zero.
  --help, -h        Show this help and exit 0.
  --version         Print the version and exit 0.

Environment:
  TASK_DIR              Task directory (default: Tasks next to this script)
  LOG_FILE              Log file, appended (default: steel.log next to this script)
  STEEL_STOP_ON_ERROR   1, true, yes, or on — halt after the first failure.
                        0, false, no, off, or unset — run every task (default).

The flag turns stop-on-error on as well. A value of 0 does not override the flag.

Exit codes:
  0   Every task that ran exited 0. An empty task directory also exits 0.
  1   One or more tasks exited non-zero.
  2   Bad arguments, a bad STEEL_STOP_ON_ERROR value, an unusable TASK_DIR,
      or a log file that could not be written.

Tasks are invoked as "bash task.sh". The caller's working directory and
environment are kept. Steel also exports STEEL_VERSION, STEEL_SCRIPT_DIR,
STEEL_TASK_DIR, and STEEL_LOG_FILE. When stop-on-error is active, child
tasks see STEEL_STOP_ON_ERROR=1.

Each task exit code is logged as: Finished: <path> (exit N)
Steel waits until the task process exits. It does not time out or kill a task.
EOF
}

die_early() {
  printf '[Steel Panda] %s\n' "$1" >&2
  exit 2
}

# Help and version stay available even when STEEL_STOP_ON_ERROR is invalid.
flag_stop=0
want_help=0
want_version=0
for arg in "$@"; do
  case "$arg" in
    -h|--help) want_help=1 ;;
    --version) want_version=1 ;;
    --stop-on-error) flag_stop=1 ;;
    *)
      printf '[Steel Panda] Unknown argument: %s\n' "$arg" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [ "$want_help" -eq 1 ]; then
  usage
  exit 0
fi
if [ "$want_version" -eq 1 ]; then
  printf 'steel-panda %s\n' "$VERSION"
  exit 0
fi

stop_raw=$(printf '%s' "${STEEL_STOP_ON_ERROR:-}" | tr '[:upper:]' '[:lower:]')
case "$stop_raw" in
  1|true|yes|on) env_stop=1 ;;
  ""|0|false|no|off) env_stop=0 ;;
  *)
    die_early "STEEL_STOP_ON_ERROR must be 1, true, yes, on, 0, false, no, or off (got: ${STEEL_STOP_ON_ERROR:-})"
    ;;
esac

if [ "$flag_stop" -eq 1 ] || [ "$env_stop" -eq 1 ]; then
  stop_on_error=1
else
  stop_on_error=0
fi

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd) || die_early "Cannot locate steel.sh"
self_base=$(basename -- "${BASH_SOURCE[0]}")
self="$script_dir/$self_base"

TASK_DIR=${TASK_DIR:-$script_dir/Tasks}
LOG_FILE=${LOG_FILE:-$script_dir/steel.log}

if [ -d "$LOG_FILE" ]; then
  die_early "LOG_FILE is a directory: $LOG_FILE"
fi

log_parent=$(dirname -- "$LOG_FILE")
if [ ! -d "$log_parent" ]; then
  mkdir -p -- "$log_parent" || die_early "Cannot create log directory: $log_parent"
fi
log_parent=$(cd -- "$log_parent" && pwd) || die_early "Cannot use log directory: $log_parent"
log_base=$(basename -- "$LOG_FILE")
LOG_FILE="$log_parent/$log_base"

if ! : >> "$LOG_FILE"; then
  die_early "Cannot write log: $LOG_FILE"
fi

say() {
  printf '[Steel Panda] %s\n' "$*" | tee -a "$LOG_FILE"
  _tee_status=${PIPESTATUS[1]}
  case "${_tee_status:-}" in
    ""|*[!0-9]*) _tee_status=1 ;;
  esac
  if [ "$_tee_status" -ne 0 ]; then
    printf '[Steel Panda] Could not write log: %s\n' "$LOG_FILE" >&2
    exit 2
  fi
}

now=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date 2>/dev/null || printf 'unknown')
if [ "$stop_on_error" -eq 1 ]; then
  mode_label="on"
else
  mode_label="off"
fi

say "Starting task executor $VERSION at $now"
say "Log file: $LOG_FILE"
say "Stop on error: $mode_label"

task_dir_input=$TASK_DIR
if [ ! -d "$task_dir_input" ]; then
  say "Task directory not found: $task_dir_input"
  exit 2
fi
TASK_DIR=$(cd -- "$task_dir_input" && pwd) || {
  say "Task directory is not readable: $task_dir_input"
  exit 2
}
say "Task directory: $TASK_DIR"

STEEL_VERSION=$VERSION
STEEL_SCRIPT_DIR=$script_dir
STEEL_TASK_DIR=$TASK_DIR
STEEL_LOG_FILE=$LOG_FILE
export STEEL_VERSION STEEL_SCRIPT_DIR STEEL_TASK_DIR STEEL_LOG_FILE
export TASK_DIR LOG_FILE
if [ "$stop_on_error" -eq 1 ]; then
  STEEL_STOP_ON_ERROR=1
  export STEEL_STOP_ON_ERROR
fi

shopt -s nullglob
task_paths=( "$TASK_DIR"/*.sh )
shopt -u nullglob

ran=0
failed=0
not_run=0
stopped=0
index=0
total=${#task_paths[@]}

if [ "$total" -eq 0 ]; then
  say "No *.sh tasks in $TASK_DIR."
fi

while [ "$index" -lt "$total" ]; do
  task="${task_paths[$index]}"
  index=$((index + 1))

  if [ ! -f "$task" ]; then
    say "Skipping (not a file): $task"
    continue
  fi
  if [ "$task" = "$self" ]; then
    say "Skipping the runner itself: $task"
    continue
  fi
  if [ "$stopped" -eq 1 ]; then
    say "Not run (stop on error): $task"
    not_run=$((not_run + 1))
    continue
  fi

  say "Running task: $task"
  bash -- "$task" 2>&1 | tee -a "$LOG_FILE"
  # Both indexes must be read in this same command. A later command resets PIPESTATUS,
  # and set -u then treats the missing index as an unbound variable.
  task_status=${PIPESTATUS[0]} tee_status=${PIPESTATUS[1]}
  case "${task_status:-}" in
    ""|*[!0-9]*) task_status=1 ;;
  esac
  case "${tee_status:-}" in
    ""|*[!0-9]*) tee_status=1 ;;
  esac
  if [ "$tee_status" -ne 0 ]; then
    printf '[Steel Panda] Could not write log: %s\n' "$LOG_FILE" >&2
    exit 2
  fi

  say "Finished: $task (exit $task_status)"
  ran=$((ran + 1))
  if [ "$task_status" -ne 0 ]; then
    failed=$((failed + 1))
    if [ "$stop_on_error" -eq 1 ]; then
      stopped=1
    fi
  fi
done

if [ "$stopped" -eq 1 ]; then
  say "Stop on error: halting. $ran ran, $failed failed, $not_run not run."
  exit 1
fi
if [ "$failed" -ne 0 ]; then
  say "Finished with failures. $ran ran, $failed failed."
  exit 1
fi
say "All tasks completed. $ran ran, $failed failed."
exit 0
