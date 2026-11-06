# Changelog

## 0.3.0 - 2026-11-06
- Log each task's exit code. Steel exits 1 when any task exits non-zero, and 0 when every task that ran succeeded
- Optional stop-on-error (`STEEL_STOP_ON_ERROR` or `--stop-on-error`). The default is still to run every matching task
- Exit 2 for a bad invocation, a bad `STEEL_STOP_ON_ERROR` value, a missing or unreadable task directory, or a log that cannot be written
- An empty task directory exits 0 and logs that zero tasks ran
- Default `TASK_DIR` and `LOG_FILE` sit next to `steel.sh`, so an absolute path works from any working directory
- Example tasks: `example-task.sh`, a read-only `disk-health.sh`, and `heartbeat.sh` (append and rotate stay off unless you opt in)
- Document the Watchdog Panda on-failure command. Steel does not require Watchdog
- README and `Documents/Index.md` match the script. Scheduling and a Federation mesh stay on the roadmap
- CI covers a failed task's exit status and stop-on-error

## 0.2.0 - 2026-11-04
- One-command installer (`install.sh`) and automatic GitHub Releases on version tags
- Fixed: `steel.sh` now finds the `Tasks/` folder (override with `TASK_DIR`)
- README leads with Install / Use

## 0.1.0 - Initial Release
- Added repo structure
- Added steel.sh executor
- Added example task
- Added documentation index
- Added Steel Panda crest
