# Steel Panda

Steel Panda 0.3.0 is a local task runner. It executes the `*.sh` files in a directory, appends their output and exit codes to a log, and returns a process status a caller can trust.

The short path (install, run, exit codes, Watchdog command) is [`README.md`](../README.md). This page is the contract: architecture, tasks, configuration, how to add a script, and how another program calls Steel.

Steel stays on the machine where you start it. The runner opens no network connections. Linux, macOS, and Termux. Bash 3.2 or newer, plus `tee` and the usual shell utilities (`mkdir`, `date`, `tr`).

A GitHub Release is created when a `vX.Y.Z` tag is pushed. `curl | bash` installs that Release. A checkout of this repository runs the script documented here.

## Architecture

```
steel.sh                 runner
Tasks/*.sh               demo tasks (or whatever TASK_DIR points at)
steel.log                default log, next to steel.sh, append-only
install.sh               unpacks a Release tarball; does not run tasks
Documents/Index.md       this page
Assets/                  crest used by the README
.github/workflows/       shellcheck, install smoke test, release-on-tag
```

One invocation:

1. Parse arguments. `--help` and `--version` exit before any log is created.
2. Resolve `LOG_FILE` and open it for append. Failure here exits 2 and the message is on stderr.
3. Append a start record: version, time, log path, whether stop-on-error is on.
4. Resolve `TASK_DIR`. A missing or unreadable directory exits 2, and that line is in the log.
5. List regular `*.sh` files in that directory, one level, lexical order.
6. For each file, append `Running task`, run `bash -- <file>` with stdout and stderr merged, then append `Finished: <path> (exit N)`.
7. Exit 0 when every task that ran exited 0. Exit 1 when any task exited non-zero.

Runner lines and task output are written to stdout and to the log (via `tee -a`). A terminal and a captured pipe see the same run. Errors that happen before the log is open go to stderr only.

Steel is one process. It is not a daemon. It does not watch other processes, schedule itself, or talk to Spirit Panda.

The caller's working directory is unchanged. Relative paths inside a task are relative to wherever the caller started `steel.sh`, which is often not `Tasks/`.

## Task system

A task is a regular file whose name ends in `.sh`. Steel runs it with `bash`, so the file does not need the executable bit and the shebang is not what selects the interpreter. Write bash that is safe on Bash 3.2 if the task should run on macOS's stock bash.

Steel skips:

- names that do not end in `.sh`
- files in subdirectories
- directories whose names happen to end in `.sh`
- the `steel.sh` file itself, when `TASK_DIR` is the directory that contains the runner

Hidden files (names starting with `.`) are not part of the `*.sh` glob.

### What a task receives

- The caller's environment, plus:
  - `STEEL_VERSION` — `0.3.0`
  - `STEEL_SCRIPT_DIR` — directory containing `steel.sh`
  - `STEEL_TASK_DIR` — absolute task directory
  - `STEEL_LOG_FILE` — absolute log path
  - `STEEL_STOP_ON_ERROR=1` when halt mode is active for this run
- The caller's working directory
- The caller's stdin. Steel does not read stdin. A recovery task that reads stdin will see whatever the caller attached, including an immediate end of file when stdin is closed. Tasks that must not hang should not wait for input.

Steel does not pass the task a list of arguments. Put paths and options in the environment or in the script.

### Exit codes inside a task

The task's exit code is stored in the log and counted. Steel's own process status stays on the three-value contract:

| Steel exits | When |
| --- | --- |
| 0 | Every task that ran exited 0, including "there were zero `*.sh` files". |
| 1 | At least one task exited non-zero, or stop-on-error halted the run. |
| 2 | Steel could not run: bad arguments, invalid `STEEL_STOP_ON_ERROR`, missing or unreadable `TASK_DIR`, log directory or log file not writable. |

A task that exits 3, 127, or any other non-zero value still makes Steel exit 1. The log line keeps the task's code:

```
[Steel Panda] Finished: /path/to/tasks/backup.sh (exit 3)
[Steel Panda] Finished with failures. 2 ran, 1 failed.
```

With stop-on-error, later files are not executed. They are logged as `Not run (stop on error): <path>`, and the summary looks like:

```
[Steel Panda] Stop on error: halting. 1 ran, 1 failed, 2 not run.
```

An empty directory:

```
[Steel Panda] No *.sh tasks in /path/to/tasks.
[Steel Panda] All tasks completed. 0 ran, 0 failed.
```

That exits 0. A recovery folder with a typo in `TASK_DIR` is different: the directory does not exist, and Steel exits 2.

### Order and overlap

Lexical order of the current locale. Prefix `01-`, `02-` when a later script assumes an earlier one finished.

Two Steel processes appending to the same `LOG_FILE` can interleave. Run one at a time when the log has to stay readable. Steel does not take a lock (`flock` is not portable to macOS).

### Shipped demos

These three files are the default `Tasks/` directory. They are demonstrations, not a maintenance suite.

| File | Behavior |
| --- | --- |
| `example-task.sh` | Prints `Example task executed successfully.` and a UTC timestamp. Exits 0. |
| `disk-health.sh` | Prints host, kernel, load or uptime, a few `/proc/meminfo` fields when that file exists, and `df -h` for `$HOME` (or `/` if that `df` fails). Read-only. Exits 1 when `df` is missing or both paths fail. |
| `heartbeat.sh` | Prints `heartbeat ok <timestamp>` and exits 0. See the opt-in file below. |

`heartbeat.sh` writes a file only when `STEEL_HEARTBEAT_FILE` is set. `STEEL_HEARTBEAT_ROTATE=1` (also `true`, `yes`, `on`) renames that file to `<file>.1` once its size reaches `STEEL_HEARTBEAT_MAX_BYTES` (default 4096) and then appends a new line. The previous `.1` file is replaced. Any other path is left alone. Symlinks at either path are refused, and rotate without a file path exits 1. This is a pattern sample for a log you own, not a system log rotator.

### Safety expectations for tasks you add

Steel will run whatever `*.sh` files you put in `TASK_DIR`. The runner does not sandbox them.

- Point `TASK_DIR` at a directory that contains only the tasks for that run. The repository root is a poor choice: `install.sh` matches `*.sh` and downloads a Release.
- Prefer absolute paths in recovery scripts.
- A task that never exits keeps Steel, and any waiting caller, running.
- Tasks inherit the full environment. A script that prints `env` will print secrets the caller had set. The shipped demos do not print the environment.

## Configuration

| Name | Default | Values |
| --- | --- | --- |
| `TASK_DIR` | `<directory of steel.sh>/Tasks` | Any directory. Relative paths resolve from the caller's working directory at start, then Steel stores the absolute path. |
| `LOG_FILE` | `<directory of steel.sh>/steel.log` | File path, appended. A relative path resolves from the caller's working directory. If the parent directory is missing, Steel tries to create it. If `LOG_FILE` is itself a directory, Steel exits 2. |
| `STEEL_STOP_ON_ERROR` | unset, which means off | On: `1`, `true`, `yes`, `on` (any letter case). Off: empty, `0`, `false`, `no`, `off`. Anything else exits 2 before tasks run. |
| `--stop-on-error` | off | Forces halt mode on for this invocation. |
| `--help`, `-h` |  | Print the contract and exit 0. No log file is created. |
| `--version` |  | Print `steel-panda 0.3.0` and exit 0. No log file is created. |

Unknown arguments exit 2 and print the usage text on stderr. They do not create a log.

Halt mode is the combination of the flag and the variable. Either one turns it on. `STEEL_STOP_ON_ERROR=0` does not override `--stop-on-error`.

Empty `TASK_DIR` or `LOG_FILE` (the variable is set but blank) is treated as unset, so the default applies.

### Log shape

```
[Steel Panda] Starting task executor 0.3.0 at 2026-11-06T16:42:00Z
[Steel Panda] Log file: /home/user/steel-panda/steel.log
[Steel Panda] Stop on error: off
[Steel Panda] Task directory: /home/user/steel-panda/Tasks
[Steel Panda] Running task: /home/user/steel-panda/Tasks/example-task.sh
Example task executed successfully.
2026-11-06T16:42:00Z
[Steel Panda] Finished: /home/user/steel-panda/Tasks/example-task.sh (exit 0)
[Steel Panda] All tasks completed. 1 ran, 0 failed.
```

A default run logs all three demos and ends with `All tasks completed. 3 ran, 0 failed.` The count is the number of tasks that actually ran. Each new invocation appends. Steel does not truncate the log.

## Extending Steel Panda

Add a file under the task directory you run. This is the whole extension mechanism: there is no module loader, plugin manifest, or package format.

```bash
cat > "$HOME/steel-panda/Tasks/40-who.sh" <<'EOF'
#!/usr/bin/env bash
# Print the user and the task directory Steel handed us. Exits 0.
echo "user=$(id -un)"
echo "tasks=$STEEL_TASK_DIR"
EOF
bash "$HOME/steel-panda/steel.sh"
```

Check the new log section for `Finished: .../40-who.sh (exit 0)` and for `All tasks completed.`

A task that should fail visibly:

```bash
#!/usr/bin/env bash
echo "backup destination missing" >&2
exit 1
```

Steel records `(exit 1)`, keeps running the remaining tasks, and exits 1. Set `STEEL_STOP_ON_ERROR=1` or pass `--stop-on-error` when a later script must not run after that failure.

Run one script by itself while you are writing it: `bash Tasks/40-who.sh`. Steel is the loop, the log, and the exit code. The script should also make sense alone.

Keep new demos in this repository free of network calls and free of deletes outside a path the script documents and leaves off by default. That is the bar the shipped tasks follow.

## Integration

### Calling Steel from anything

Steel is a foreground command. Cron, a shell alias, a button in another script, or a process supervisor can run it. The useful inputs are the environment variables above. The useful outputs are the process exit code, stdout (a copy of what was appended this run), and the log file (the full history).

```bash
TASK_DIR=/var/lib/myapp/tasks LOG_FILE=/var/lib/myapp/steel.log bash /opt/steel-panda/steel.sh
status=$?
```

### Watchdog Panda

[Watchdog Panda](https://github.com/pandadad0214/Watchdog_Panda) is a separate repository. Steel does not check whether it is installed.

Watchdog's finish pass runs a configured shell command when a watched process dies. That command can be Steel:

```bash
TASK_DIR=/path/to/recovery-tasks bash /path/to/steel-panda/steel.sh
```

Practical form once the paths are real:

```bash
STEEL_STOP_ON_ERROR=1 \
  TASK_DIR="$HOME/recovery-tasks" \
  LOG_FILE="$HOME/recovery-tasks/steel.log" \
  bash "$HOME/steel-panda/steel.sh"
```

- Create `~/recovery-tasks` and put only the scripts that should run on failure there.
- The demos in Steel's own `Tasks/` directory do not restart a service. Use them as samples, then write a recovery script that does the work you want.
- Steel exits non-zero when a task fails, so a caller that checks status can tell the hook failed.
- Steel is non-interactive: no prompts, no TTY required.
- Pass anything the scripts need in the environment on that command. Steel does not invent a failure payload, and it does not parse Watchdog's log.
- Confirm the first log summary. `0 ran, 0 failed` with exit 0 means the directory was empty.

A template to copy into the recovery directory and edit (not shipped in `Tasks/`, because Steel would run it on every ordinary invocation):

```bash
#!/usr/bin/env bash
# Restart one process you own. Replace the name and the command.
# Uses the caller's environment. Does nothing when the process is already there.
set -u
name=${WATCHED_PROCESS:-my-app}
if command -v pgrep >/dev/null 2>&1 && pgrep -f "$name" >/dev/null 2>&1; then
  echo "$name is already running"
  exit 0
fi
echo "recovery: start $name yourself by editing this script"
exit 1
```

The template refuses to guess a start command. A copy that exits 1 keeps the failure visible until you put the real command in. The name `WATCHED_PROCESS` is only a suggestion for how you can pass a name on the Watchdog command line; Steel does not require it.

Today's published Watchdog loop restarts a process with its own start command. Which setting holds the on-failure command is documented with Watchdog, because that setting lives there. Steel's side of the pairing is the command above.

### What integration is not in this version

- Steel does not subscribe to Watchdog, Spirit Panda, or any other agent.
- Steel does not send heartbeats outward. `Tasks/heartbeat.sh` prints a line, and optionally appends to a local file.
- Steel does not receive a structured event. The environment and the working directory are the inputs.

## Roadmap

Recorded here so the docs stay aligned with the script:

- Scheduling inside Steel
- Process watching inside Steel
- A Federation mesh that calls Spirit Panda or other agents with a real payload
- Remote execution
- A config file that lists several task directories

Until a feature is in `steel.sh`, it is not part of the runner. Cron or Watchdog remains the way to decide *when* Steel runs.
