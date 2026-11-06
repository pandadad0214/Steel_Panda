#!/usr/bin/env bash
# Steel Panda smoke tests. Bash only. Run from anywhere:
#   bash tests/smoke.sh
set -u

root=$(cd -- "$(dirname -- "$0")/.." && pwd) || exit 1
cd -- "$root" || exit 1

unset TASK_DIR LOG_FILE STEEL_STOP_ON_ERROR STEEL_HEARTBEAT_FILE \
  STEEL_HEARTBEAT_ROTATE STEEL_HEARTBEAT_MAX_BYTES || true
rm -f -- "$root/steel.log" "$root/steel-heartbeat.log" "$root/steel-heartbeat.log.1"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
failures=0

ok() {
  printf 'ok - %s\n' "$1"
}

not_ok() {
  printf 'not ok - %s\n' "$1" >&2
  failures=$((failures + 1))
}

expect_status() {
  got=$1
  want=$2
  name=$3
  if [ "$got" -eq "$want" ]; then
    ok "$name"
  else
    not_ok "$name (status $got, want $want)"
  fi
}

expect_file() {
  if [ -f "$1" ]; then
    ok "$2"
  else
    not_ok "$2 (missing $1)"
  fi
}

expect_absent() {
  if [ -e "$1" ]; then
    not_ok "$2 (found $1)"
  else
    ok "$2"
  fi
}

expect_fixed() {
  file=$1
  text=$2
  name=$3
  if [ -f "$file" ] && grep -q -F -e "$text" -- "$file"; then
    ok "$name"
  else
    not_ok "$name (missing text in $file)"
  fi
}

expect_no_fixed() {
  file=$1
  text=$2
  name=$3
  if [ -f "$file" ] && grep -q -F -e "$text" -- "$file"; then
    not_ok "$name (unexpected text in $file)"
  else
    ok "$name"
  fi
}

expect_silent() {
  if [ -s "$1" ]; then
    not_ok "$2 (output was not empty)"
  else
    ok "$2"
  fi
}

expect_match_log() {
  if cmp -s "$steel_stdout" "$log"; then
    ok "$1"
  else
    not_ok "$1 (stdout and log differ)"
  fi
}

begin() {
  dir=$tmp/$1
  tasks=$dir/tasks
  log=$dir/steel.log
  rm -rf -- "$dir"
  mkdir -p -- "$tasks"
}

run_steel() {
  "$@" >"$dir/stdout" 2>"$dir/stderr"
  steel_status=$?
  steel_stdout=$dir/stdout
  steel_stderr=$dir/stderr
  return 0
}

dump_failures() {
  if [ "$failures" -eq 0 ]; then
    return 0
  fi
  printf '\n--- failure artifacts under %s ---\n' "$tmp" >&2
  find "$tmp" -type f ! -name '*.tar.gz' ! -name '*.jpg' | sort | while read -r path; do
    printf '\n===== %s =====\n' "$path" >&2
    cat -- "$path" >&2
  done
}

# --- help / version do not touch a log ---

begin help
cp -- "$root/steel.sh" "$dir/steel.sh"
run_steel bash "$dir/steel.sh" --help
expect_status "$steel_status" 0 "help exits 0"
expect_fixed "$steel_stdout" "Exit codes:" "help prints the contract"
expect_silent "$steel_stderr" "help writes nothing on stderr"
expect_absent "$dir/steel.log" "help does not create a log beside the script"
expect_absent "$root/steel.log" "help does not create a repo log"

run_steel env STEEL_STOP_ON_ERROR=maybe bash "$dir/steel.sh" --help
expect_status "$steel_status" 0 "help wins over a bad STEEL_STOP_ON_ERROR"
expect_absent "$dir/steel.log" "help with a bad env still creates no log"

run_steel bash "$dir/steel.sh" --version
expect_status "$steel_status" 0 "version exits 0"
expect_fixed "$steel_stdout" "steel-panda 0.3.0" "version string"
expect_silent "$steel_stderr" "version writes nothing on stderr"
expect_absent "$dir/steel.log" "version does not create a log"

run_steel bash "$dir/steel.sh" --help --stop-on-error
expect_status "$steel_status" 0 "help with a known flag exits 0"

run_steel bash "$root/steel.sh" --nope
expect_status "$steel_status" 2 "unknown argument exits 2"
expect_fixed "$steel_stderr" "Unknown argument" "unknown argument names itself"
expect_absent "$root/steel.log" "unknown argument does not create a repo log"

run_steel env STEEL_STOP_ON_ERROR=maybe LOG_FILE="$log" bash "$root/steel.sh"
expect_status "$steel_status" 2 "bad STEEL_STOP_ON_ERROR exits 2"
expect_fixed "$steel_stderr" "STEEL_STOP_ON_ERROR" "bad env message"
expect_absent "$log" "bad env does not create the log"

# --- log and task directory setup ---

begin log-dir
mkdir -p -- "$dir/a-dir"
run_steel env LOG_FILE="$dir/a-dir" TASK_DIR="$tasks" bash "$root/steel.sh"
expect_status "$steel_status" 2 "LOG_FILE as a directory exits 2"
expect_fixed "$steel_stderr" "LOG_FILE is a directory" "directory log is named"

begin missing-dir
run_steel env LOG_FILE="$log" TASK_DIR="$dir/no-such" bash "$root/steel.sh"
expect_status "$steel_status" 2 "missing TASK_DIR exits 2"
expect_fixed "$log" "Task directory not found" "missing directory is in the log"
expect_match_log "missing-directory stdout matches the log"
expect_silent "$steel_stderr" "missing directory after open uses the log, not stderr"

begin default-missing
cp -- "$root/steel.sh" "$dir/steel.sh"
(
  cd -- "$tmp" || exit 1
  bash "$dir/steel.sh" >"$dir/stdout" 2>"$dir/stderr"
)
steel_status=$?
steel_stdout=$dir/stdout
steel_stderr=$dir/stderr
log=$dir/steel.log
expect_status "$steel_status" 2 "default Tasks directory missing exits 2"
expect_file "$log" "default log is created beside the script"
expect_fixed "$log" "Task directory not found" "default missing path is logged"
expect_absent "$tmp/steel.log" "a missing default does not write the caller's cwd log"

begin default-ok
cp -- "$root/steel.sh" "$dir/steel.sh"
mkdir -p -- "$dir/Tasks"
printf '%s\n' '#!/bin/bash' 'echo from-default' 'exit 0' > "$dir/Tasks/ok.sh"
(
  cd -- "$tmp" || exit 1
  bash "$dir/steel.sh" >"$dir/stdout" 2>"$dir/stderr"
)
steel_status=$?
steel_stdout=$dir/stdout
steel_stderr=$dir/stderr
log=$dir/steel.log
expect_status "$steel_status" 0 "default Tasks run from another working directory"
expect_fixed "$log" "from-default" "default task output is in the script-side log"
expect_fixed "$log" "(exit 0)" "default task exit is recorded"
expect_absent "$tmp/steel.log" "default log is not the caller's cwd"
expect_match_log "default-path stdout matches the log"

# --- successful runs ---

begin success
printf '%s\n' '#!/bin/bash' 'echo spaced-ok' 'exit 0' > "$tasks/my task.sh"
printf '%s\n' '#!/bin/bash' 'echo nox' 'exit 0' > "$tasks/nox.sh"
chmod a-x "$tasks/nox.sh"
printf '%s\n' '#!/bin/bash' 'echo on-err >&2' 'exit 0' > "$tasks/err.sh"
printf '%s\n' 'notes' > "$tasks/notes.txt"
mkdir -p -- "$tasks/skip.sh"
run_steel env LOG_FILE="$log" TASK_DIR="$tasks" bash "$root/steel.sh"
expect_status "$steel_status" 0 "mixed success tasks exit 0"
expect_fixed "$log" "spaced-ok" "a task name with a space runs"
expect_fixed "$log" "nox" "a non-executable task still runs under bash"
expect_fixed "$log" "on-err" "task stderr is in the log"
expect_fixed "$log" "Skipping (not a file):" "a directory named *.sh is skipped"
expect_no_fixed "$log" "notes.txt" "non-sh files are not tasks"
expect_fixed "$log" "All tasks completed. 3 ran, 0 failed." "three real tasks counted"
expect_fixed "$log" "Stop on error: off" "default mode is logged"
expect_match_log "success stdout matches the log"
expect_silent "$steel_stderr" "success writes nothing on stderr"

begin order
printf '%s\n' '#!/bin/bash' 'echo AAA' > "$tasks/a.sh"
printf '%s\n' '#!/bin/bash' 'echo BBB' > "$tasks/b.sh"
run_steel env LOG_FILE="$log" TASK_DIR="$tasks" bash "$root/steel.sh"
expect_status "$steel_status" 0 "lexical pair exits 0"
a_line=$(grep -n -F "Running task: $tasks/a.sh" "$log" | head -n 1 | cut -d: -f1)
b_line=$(grep -n -F "Running task: $tasks/b.sh" "$log" | head -n 1 | cut -d: -f1)
if [ -n "$a_line" ] && [ -n "$b_line" ] && [ "$a_line" -lt "$b_line" ]; then
  ok "tasks run in lexical order"
else
  not_ok "tasks run in lexical order (a=$a_line b=$b_line)"
fi

begin empty
printf '%s\n' 'ignore' > "$tasks/notes.txt"
run_steel env LOG_FILE="$log" TASK_DIR="$tasks" bash "$root/steel.sh"
expect_status "$steel_status" 0 "empty task directory exits 0"
expect_fixed "$log" "No *.sh tasks in $tasks." "empty directory is logged"
expect_fixed "$log" "All tasks completed. 0 ran, 0 failed." "empty summary is explicit"
expect_no_fixed "$log" "Running task:" "empty directory runs nothing"

begin relative
rel=$dir/reltasks
mkdir -p -- "$rel"
cat > "$rel/env.sh" <<'EOF'
#!/bin/bash
printf 'version=%s\n' "$STEEL_VERSION"
printf 'task_dir=%s\n' "$STEEL_TASK_DIR"
printf 'log_file=%s\n' "$STEEL_LOG_FILE"
printf 'script_dir=%s\n' "$STEEL_SCRIPT_DIR"
case "$STEEL_TASK_DIR" in
  /*) ;;
  *) printf 'task dir is not absolute\n' >&2; exit 1 ;;
esac
EOF
(
  cd -- "$dir" || exit 1
  env LOG_FILE=rel.log TASK_DIR=reltasks bash "$root/steel.sh" >"$dir/stdout" 2>"$dir/stderr"
)
steel_status=$?
steel_stdout=$dir/stdout
steel_stderr=$dir/stderr
log=$dir/rel.log
expect_status "$steel_status" 0 "relative TASK_DIR and LOG_FILE exit 0"
expect_fixed "$log" "version=0.3.0" "STEEL_VERSION is exported"
expect_fixed "$log" "task_dir=$rel" "STEEL_TASK_DIR is absolute"
expect_fixed "$log" "log_file=$log" "STEEL_LOG_FILE is absolute"
expect_fixed "$log" "script_dir=$root" "STEEL_SCRIPT_DIR points at the runner"
expect_fixed "$log" "Task directory: $rel" "banner uses the absolute task directory"
expect_match_log "relative-path stdout matches the log"

# --- failures keep going unless stop-on-error is set ---

begin continue
printf '%s\n' '#!/bin/bash' 'echo first' 'exit 0' > "$tasks/01-ok.sh"
printf '%s\n' '#!/bin/bash' 'echo bad' 'exit 3' > "$tasks/02-bad.sh"
printf '%s\n' '#!/bin/bash' 'echo later' 'exit 0' > "$tasks/03-later.sh"
run_steel env LOG_FILE="$log" TASK_DIR="$tasks" bash "$root/steel.sh"
expect_status "$steel_status" 1 "a failed task makes Steel exit 1"
expect_fixed "$log" "Finished: $tasks/02-bad.sh (exit 3)" "the task's own exit code is logged"
expect_fixed "$log" "later" "later tasks still run by default"
expect_fixed "$log" "Finished: $tasks/03-later.sh (exit 0)" "later task exit is logged"
expect_fixed "$log" "Finished with failures. 3 ran, 1 failed." "failure summary counts every task"
expect_no_fixed "$log" "Stop on error: halting." "default run does not halt"
expect_match_log "failure stdout matches the log"

setup_pair() {
  begin "$1"
  printf '%s\n' '#!/bin/bash' 'echo bad' 'exit 4' > "$tasks/01-bad.sh"
  cat > "$tasks/02-later.sh" <<EOF
#!/bin/bash
echo later-body
echo ran > "$dir/later-ran"
exit 0
EOF
}

setup_pair stop-env
run_steel env STEEL_STOP_ON_ERROR=1 LOG_FILE="$log" TASK_DIR="$tasks" bash "$root/steel.sh"
expect_status "$steel_status" 1 "stop-on-error exits 1"
expect_fixed "$log" "Finished: $tasks/01-bad.sh (exit 4)" "stop-on-error logs the failing code"
expect_fixed "$log" "Not run (stop on error): $tasks/02-later.sh" "later task is marked not run"
expect_fixed "$log" "Stop on error: halting. 1 ran, 1 failed, 1 not run." "halt summary"
expect_fixed "$log" "Stop on error: on" "halt mode is logged at start"
expect_no_fixed "$log" "Finished: $tasks/02-later.sh" "later task has no Finished line"
expect_absent "$dir/later-ran" "later task does not run its body"
expect_no_fixed "$log" "Finished with failures." "halt uses the halt summary"

setup_pair stop-flag
# Replace the failing task so the flag test also checks the exported mode.
cat > "$tasks/01-bad.sh" <<'EOF'
#!/bin/bash
printf 'stop=%s\n' "${STEEL_STOP_ON_ERROR:-}"
exit 4
EOF
run_steel env STEEL_STOP_ON_ERROR=0 LOG_FILE="$log" TASK_DIR="$tasks" bash "$root/steel.sh" --stop-on-error
expect_status "$steel_status" 1 "--stop-on-error overrides STEEL_STOP_ON_ERROR=0"
expect_absent "$dir/later-ran" "flag halt skips the later task"
expect_fixed "$log" "stop=1" "halt mode exports STEEL_STOP_ON_ERROR=1"
expect_fixed "$log" "Stop on error: halting. 1 ran, 1 failed, 1 not run." "flag halt summary"

begin stop-yes
printf '%s\n' '#!/bin/bash' 'exit 9' > "$tasks/01-bad.sh"
printf '%s\n' '#!/bin/bash' 'echo should-not' > "$tasks/02-no.sh"
run_steel env STEEL_STOP_ON_ERROR=yes LOG_FILE="$log" TASK_DIR="$tasks" bash "$root/steel.sh"
expect_status "$steel_status" 1 "STEEL_STOP_ON_ERROR=yes halts"
expect_no_fixed "$log" "should-not" "yes-halt does not run the later body"
expect_fixed "$log" "(exit 9)" "yes-halt records exit 9"

begin stop-all-ok
printf '%s\n' '#!/bin/bash' 'echo one' > "$tasks/a.sh"
printf '%s\n' '#!/bin/bash' 'echo two' > "$tasks/b.sh"
run_steel env STEEL_STOP_ON_ERROR=1 LOG_FILE="$log" TASK_DIR="$tasks" bash "$root/steel.sh"
expect_status "$steel_status" 0 "stop-on-error with all successes exits 0"
expect_fixed "$log" "one" "first success still runs"
expect_fixed "$log" "two" "second success still runs"
expect_fixed "$log" "All tasks completed. 2 ran, 0 failed." "halt mode stays quiet when nothing fails"

begin continue-zero
printf '%s\n' '#!/bin/bash' 'echo bad' 'exit 2' > "$tasks/01-bad.sh"
printf '%s\n' '#!/bin/bash' 'echo kept-going' > "$tasks/02-ok.sh"
run_steel env STEEL_STOP_ON_ERROR=0 LOG_FILE="$log" TASK_DIR="$tasks" bash "$root/steel.sh"
expect_status "$steel_status" 1 "STEEL_STOP_ON_ERROR=0 still reports failure"
expect_fixed "$log" "kept-going" "explicit off keeps running later tasks"

# --- shipped demos ---

begin shipped
(
  cd -- "$tmp" || exit 1
  env LOG_FILE="$log" bash "$root/steel.sh" >"$dir/stdout" 2>"$dir/stderr"
)
steel_status=$?
steel_stdout=$dir/stdout
steel_stderr=$dir/stderr
expect_status "$steel_status" 0 "shipped Tasks/ exit 0"
expect_fixed "$log" "Example task executed successfully." "example task line"
expect_fixed "$log" "=== disk-health" "disk-health header"
expect_fixed "$log" "--- disk ---" "disk-health df section"
expect_fixed "$log" "heartbeat ok" "heartbeat line"
expected=0
for task in "$root"/Tasks/*.sh; do
  [ -f "$task" ] || continue
  expected=$((expected + 1))
  base=$(basename -- "$task")
  expect_fixed "$log" "$base" "shipped task ran: $base"
done
got=$(grep -c -F '(exit 0)' "$log" || true)
got=$(printf '%s' "$got" | tr -d '[:space:]')
if [ "$got" = "$expected" ]; then
  ok "every shipped task logged exit 0 ($expected)"
else
  not_ok "every shipped task logged exit 0 (got $got, want $expected)"
fi
if grep -F '(exit ' "$log" | grep -v -F '(exit 0)' >/dev/null; then
  not_ok "shipped tasks produced a non-zero exit line"
else
  ok "shipped tasks produced no non-zero exit line"
fi
expect_absent "$root/steel.log" "shipped run did not write the repo log"
expect_absent "$root/steel-heartbeat.log" "heartbeat default created no repo file"
expect_absent "$tmp/steel-heartbeat.log" "heartbeat default created no cwd file"
expect_silent "$steel_stderr" "shipped run writes nothing on stderr"

# --- heartbeat file and rotate stay opt-in and local ---

begin heartbeat
(
  cd -- "$dir" || exit 1
  bash "$root/Tasks/heartbeat.sh" >"$dir/hb.out" 2>"$dir/hb.err"
)
steel_status=$?
expect_status "$steel_status" 0 "heartbeat default exits 0"
expect_fixed "$dir/hb.out" "heartbeat ok" "heartbeat default prints a line"
expect_silent "$dir/hb.err" "heartbeat default is quiet on stderr"
expect_absent "$dir/steel-heartbeat.log" "heartbeat default creates no file in cwd"
extra=$(find "$dir" -type f ! -name 'hb.out' ! -name 'hb.err')
if [ -n "$extra" ]; then
  not_ok "heartbeat default left an extra file"
else
  ok "heartbeat default left no extra file"
fi

run_steel env STEEL_HEARTBEAT_ROTATE=1 bash "$root/Tasks/heartbeat.sh"
expect_status "$steel_status" 1 "rotate without a file exits 1"
expect_fixed "$steel_stderr" "STEEL_HEARTBEAT_FILE is empty" "rotate-without-file explains itself"

run_steel env STEEL_HEARTBEAT_FILE="$dir/x.log" STEEL_HEARTBEAT_MAX_BYTES=nope bash "$root/Tasks/heartbeat.sh"
expect_status "$steel_status" 1 "bad max bytes exits 1"
expect_absent "$dir/x.log" "bad max bytes creates no file"

printf '%s\n' 'safe' > "$dir/safe.txt"
printf '%s\n' 'data' > "$dir/elsewhere"
ln -s "$dir/elsewhere" "$dir/link.log"
run_steel env STEEL_HEARTBEAT_FILE="$dir/link.log" bash "$root/Tasks/heartbeat.sh"
expect_status "$steel_status" 1 "symlink heartbeat path exits 1"
expect_fixed "$dir/elsewhere" "data" "symlink target is unchanged"
expect_fixed "$dir/safe.txt" "safe" "sibling file is unchanged"

beat=$dir/beat.log
run_steel env STEEL_HEARTBEAT_FILE="$beat" STEEL_HEARTBEAT_ROTATE=0 bash "$root/Tasks/heartbeat.sh"
expect_status "$steel_status" 0 "append without rotate exits 0"
expect_file "$beat" "append creates the named file"
run_steel env STEEL_HEARTBEAT_FILE="$beat" STEEL_HEARTBEAT_ROTATE=0 bash "$root/Tasks/heartbeat.sh"
expect_status "$steel_status" 0 "second append exits 0"
lines=$(wc -l < "$beat" | tr -d '[:space:]')
if [ "$lines" -eq 2 ]; then
  ok "rotate off keeps both lines in one file"
else
  not_ok "rotate off keeps both lines in one file (lines=$lines)"
fi
expect_absent "$beat.1" "rotate off creates no backup"

# Force a rotate on the next run, then prove a third run replaces only the .1 backup.
run_steel env STEEL_HEARTBEAT_FILE="$beat" STEEL_HEARTBEAT_ROTATE=1 STEEL_HEARTBEAT_MAX_BYTES=10 bash "$root/Tasks/heartbeat.sh"
expect_status "$steel_status" 0 "rotate exits 0"
expect_file "$beat.1" "rotate creates the .1 backup"
expect_file "$beat" "rotate starts a new file"
printf '%s\n' 'MARKER' > "$beat.1"
run_steel env STEEL_HEARTBEAT_FILE="$beat" STEEL_HEARTBEAT_ROTATE=1 STEEL_HEARTBEAT_MAX_BYTES=10 bash "$root/Tasks/heartbeat.sh"
expect_status "$steel_status" 0 "second rotate exits 0"
if grep -q -F -e 'MARKER' -- "$beat.1"; then
  not_ok "second rotate replaces the previous .1 backup"
else
  ok "second rotate replaces the previous .1 backup"
fi
expect_fixed "$dir/safe.txt" "safe" "rotate leaves an unrelated file alone"
expect_fixed "$dir/elsewhere" "data" "rotate leaves the symlink target alone"

# --- installer smoke (same idea as CI) ---

begin install
(
  cd -- "$root" || exit 1
  git ls-files -z -- . ':!.github' | tar czf "$dir/pkg.tar.gz" --null -T -
)
run_steel env PANDA_TARBALL="$dir/pkg.tar.gz" INSTALL_DIR="$dir/inst" NO_RUN=1 bash "$root/install.sh"
expect_status "$steel_status" 0 "install.sh unpacks a local tarball"
expect_file "$dir/inst/steel.sh" "tarball contains steel.sh"
expect_file "$dir/inst/Tasks/disk-health.sh" "tarball contains disk-health.sh"
expect_file "$dir/inst/Documents/Index.md" "tarball listing includes docs when git tracks them"
(
  cd -- "$dir/inst" || exit 1
  bash steel.sh >"$dir/inst-stdout" 2>"$dir/inst-stderr"
)
steel_status=$?
expect_status "$steel_status" 0 "installed tree runs steel.sh"
expect_file "$dir/inst/steel.log" "installed run writes steel.log beside the script"
expect_fixed "$dir/inst/steel.log" "All tasks completed." "installed run completes"
expect_fixed "$dir/inst/steel.log" "Example task executed successfully." "installed example task ran"
expect_silent "$dir/inst-stderr" "installed run writes nothing on stderr"

dump_failures
if [ "$failures" -ne 0 ]; then
  printf '\n%s check(s) failed\n' "$failures" >&2
  exit 1
fi
printf 'All smoke checks passed.\n'
