#!/bin/bash

# Steel Panda - Task Executor
# Executes all scripts inside the tasks/ directory

LOG_FILE="${LOG_FILE:-steel.log}"
TASK_DIR="${TASK_DIR:-Tasks}"   # folder of *.sh tasks (override with TASK_DIR=...)

echo "[Steel Panda] Starting task executor..." | tee -a "$LOG_FILE"

for task in "$TASK_DIR"/*.sh; do
    if [ -f "$task" ]; then
        echo "[Steel Panda] Running task: $task" | tee -a "$LOG_FILE"
        bash "$task" >> "$LOG_FILE" 2>&1
        echo "[Steel Panda] Finished: $task" | tee -a "$LOG_FILE"
    fi
done

echo "[Steel Panda] All tasks completed." | tee -a "$LOG_FILE"
