<p align="center">
  <img src="Assets/Samurai Panda.jpg" width="220" alt="Steel Panda crest" />
</p>

<p align="center">

  <img src="https://img.shields.io/badge/Role-Operational%20Steward-grey" />
  <img src="https://img.shields.io/badge/Local--First-green" />
  <img src="https://img.shields.io/badge/License-MIT-yellow.svg" />

</p>

---

# Steel Panda

Steel Panda runs every shell script in a folder, logs each exit code and exits non-zero if any task failed, all on your own machine. It is a single Bash file for Linux, macOS and Termux (Bash 3.2+) that opens no network connections.

[![Latest Release](https://img.shields.io/github/v/release/pandadad0214/Steel_Panda?label=latest%20release)](https://github.com/pandadad0214/Steel_Panda/releases/latest)
[![CI](https://github.com/pandadad0214/Steel_Panda/actions/workflows/ci.yml/badge.svg)](https://github.com/pandadad0214/Steel_Panda/actions/workflows/ci.yml)

## How to use this

```bash
curl -fsSL https://github.com/pandadad0214/Steel_Panda/releases/latest/download/install.sh | bash
cd ~/steel-panda && bash steel.sh
```

1. **Install** the latest Release with the command above (into `~/steel-panda`; set `STEEL_PANDA_HOME` or `INSTALL_DIR` to change it).
2. **Add tasks:** save `*.sh` files in `Tasks/` (or point `TASK_DIR` at your own folder). Prefix names with `01-`, `02-` when order matters.
3. **Run** `bash steel.sh` and read `steel.log`. Exit 0 means every task passed; 1 means a task failed; 2 means Steel could not start.

## For AI agents

| Field | Value |
| --- | --- |
| Purpose | Run every `*.sh` in a task folder in lexical order, log each exit code, return an aggregate exit code. |
| Use when | You need a dependency-free, local runner for a folder of maintenance or recovery scripts, e.g. as Watchdog Panda's failure hook. |
| Do not use when | You need scheduling, timeouts, parallel runs, remote execution or a DAG (Steel has none of these). |
| Install | `curl -fsSL https://github.com/pandadad0214/Steel_Panda/releases/latest/download/install.sh \| bash` |
| Entry point | `bash steel.sh [--stop-on-error]`; env `TASK_DIR`, `LOG_FILE`, `STEEL_STOP_ON_ERROR` |
| Outputs | `steel.log` lines `Finished: <path> (exit N)` plus a `ran/failed` summary; stdout mirrors progress |
| Exit codes | 0 all passed, 1 a task failed, 2 could not start |
| Side effects | Runs your scripts with `bash`; the runner itself opens no network and does not prompt. |

## Install options

### One-command install (latest tagged Release)

```bash
curl -fsSL https://github.com/pandadad0214/Steel_Panda/releases/latest/download/install.sh | bash
```

That installs the newest [GitHub Release](https://github.com/pandadad0214/Steel_Panda/releases/latest) into `~/steel-panda` (`STEEL_PANDA_HOME` or `INSTALL_DIR` to choose another directory). A release is published when a `vX.Y.Z` tag is pushed; the latest is v0.3.0.

Prefer a manual download? Take `steel-panda.tar.gz` from the latest Release and check it against `SHA256SUMS.txt`.

Then run the tasks that shipped in that package:

```bash
cd ~/steel-panda && bash steel.sh
```

### Run this repository

To run the current main branch instead of the latest Release:

```bash
git clone https://github.com/pandadad0214/Steel_Panda.git
cd Steel_Panda
bash steel.sh
```

Output is appended to `steel.log` next to `steel.sh`. Runner progress and task output also go to stdout, so a pipe or a log redirect from the caller still sees the run. Usage errors go to stderr. Steel does not prompt.

```bash
# Another folder of tasks, and an explicit log path
TASK_DIR=/path/to/tasks LOG_FILE=/path/to/steel.log bash /path/to/steel.sh

# Halt after the first non-zero task (the default is to keep going)
STEEL_STOP_ON_ERROR=1 bash steel.sh
bash steel.sh --stop-on-error
```

Add a task by saving a `*.sh` file in the task directory and running `bash steel.sh` again. Steel runs `bash` on each file, so the executable bit is optional. Order is the shell's lexical order; prefix names with `01-`, `02-` when order matters. Subdirectories are left alone.

### Exit codes

| Exit | Meaning |
| --- | --- |
| 0 | Every task that ran exited 0. An empty task directory is this case (`0 ran, 0 failed` in the log). |
| 1 | One or more tasks exited non-zero. The task's own code is in the log: `Finished: <path> (exit N)`. |
| 2 | Steel could not start: bad arguments, a bad `STEEL_STOP_ON_ERROR` value, a missing or unreadable task directory, or a log file that could not be written. |

Steel waits until each task process exits. It has no timeout and it does not kill a stuck task. A caller that waits on `steel.sh` waits with it.

Full contract: [`Documents/Index.md`](Documents/Index.md).

---

## Example tasks

`Tasks/` ships three demos. They are safe to run on a laptop, a CI runner, or a phone. They do not delete your files and they do not open the network.

| Task | What it does |
| --- | --- |
| `example-task.sh` | Prints `Example task executed successfully.` and a UTC timestamp. |
| `disk-health.sh` | Read-only host, memory, and `df -h` snapshot (`$HOME`, or `/` if that fails). Exits 1 when `df` cannot print a report. |
| `heartbeat.sh` | Prints `heartbeat ok <timestamp>`. Creates no file unless you opt in. |

Heartbeat file and rotate are off by default:

```bash
# Append one line to a file you name
STEEL_HEARTBEAT_FILE="$HOME/steel-heartbeat.log" bash Tasks/heartbeat.sh

# Also rename that file to a single .1 backup once it reaches the size limit
STEEL_HEARTBEAT_ROTATE=1 STEEL_HEARTBEAT_MAX_BYTES=4096 \
  STEEL_HEARTBEAT_FILE="$HOME/steel-heartbeat.log" bash Tasks/heartbeat.sh
```

Rotation can replace that `.1` backup. It refuses symlinks. The header of `Tasks/heartbeat.sh` is the full rule.

These demos are what `bash steel.sh` runs out of the box. A recovery folder should contain the scripts you actually want on failure, not these samples, unless a disk report is the recovery you want.

---

## Watchdog Panda

[Watchdog Panda](https://github.com/pandadad0214/Watchdog_Panda) and Steel are separate projects. Steel runs on its own. It does not install Watchdog, call Watchdog, or read Watchdog's config.

Watchdog's finish pass runs a shell command when a watched process dies. Point that command at Steel:

```bash
TASK_DIR=/path/to/recovery-tasks bash /path/to/steel-panda/steel.sh
```

Use a directory that contains only the recovery scripts. Give it an absolute `TASK_DIR` so the hook's working directory does not matter. Tasks inherit the environment and the caller's working directory, so use absolute paths inside recovery scripts (or `cd` yourself). Steel exports `STEEL_TASK_DIR`, `STEEL_LOG_FILE`, `STEEL_SCRIPT_DIR`, and `STEEL_VERSION` for scripts that want them.

```bash
# Same hook, with an explicit log and a halt after the first failure
STEEL_STOP_ON_ERROR=1 \
  TASK_DIR=/path/to/recovery-tasks \
  LOG_FILE=/path/to/recovery-tasks/steel.log \
  bash /path/to/steel-panda/steel.sh
```

Any variables you put on that command are visible to the tasks. Steel does not define a payload of its own. The process exit is the result: `0` recovered (every task exited 0), `1` a task failed, `2` Steel could not start. An empty recovery directory exits 0 and logs `0 ran, 0 failed`, so confirm the log when you first wire the hook.

The same command works from a terminal, cron, or any other program. Scheduling lives with the caller. Steel's job is to run the folder and return a status.

---

## Configuration

| Name | Default | Role |
| --- | --- | --- |
| `TASK_DIR` | `Tasks` next to `steel.sh` | Directory of `*.sh` tasks. One level, regular files, lexical order. |
| `LOG_FILE` | `steel.log` next to `steel.sh` | Append-only log. Created if the parent directory exists or can be created. |
| `STEEL_STOP_ON_ERROR` | unset | `1`, `true`, `yes`, or `on` halts after the first failed task. `0`, `false`, `no`, `off`, or unset runs every task. |
| `--stop-on-error` | off | Turns halt mode on for this run, including when the variable is `0` or unset. |

Relative `TASK_DIR` and `LOG_FILE` are resolved from the working directory you started in. The defaults are absolute paths next to the script, so this works from any directory:

```bash
bash /path/to/steel-panda/steel.sh
```

Two overlapping runs that share a log can interleave lines. One run at a time keeps the record readable.

`bash steel.sh --help` prints the same contract. `--version` prints `steel-panda 0.3.0`.

---

## What this version runs

`steel.sh` is the runner. `Tasks/` holds scripts. `install.sh` unpacks a Release into a directory and stops there; it does not execute tasks. `Documents/Index.md` is the longer contract. `Assets/` is the crest.

There is no scheduler inside Steel, no process watcher, and no client for Spirit Panda or any other Federation agent. Those stay on the roadmap until the script actually does them.

---

## Roadmap

- A scheduler inside Steel (cron-style or interval)
- Watching processes from Steel itself
- A deeper Federation mesh: structured calls to Spirit Panda or other agents
- Remote execution
- A config file for several task directories

Until those exist, cron or Watchdog's on-failure command is how a run gets started.

---

## For developers

```bash
git clone https://github.com/pandadad0214/Steel_Panda.git
cd Steel_Panda
bash tests/smoke.sh
bash steel.sh
shellcheck -S error steel.sh install.sh Tasks/*.sh tests/smoke.sh
```

Releases are tags. Update `CHANGELOG.md`, commit, and push a `vX.Y.Z` tag. [`.github/workflows/release.yml`](.github/workflows/release.yml) packs `steel-panda.tar.gz` (runner, `Tasks/`, docs, crest, readme, license, changelog), `install.sh`, and `SHA256SUMS.txt`, then publishes the GitHub Release. The 0.3.0 changelog entry records this tree; publishing the release is the tag.

---

## License

[MIT](LICENSE). Copyright (c) 2026 Pandadad.
