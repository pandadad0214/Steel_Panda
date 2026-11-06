#!/usr/bin/env bash
# Read-only host and disk snapshot for Steel Panda demos.
# Prints to stdout (Steel appends that to the log).
# Does not delete files, change permissions, or open a network connection.
# Linux, macOS, and Termux. Missing optional commands are reported and skipped.
# df is required: the task exits 1 when no disk report can be printed.
set -u

timestamp() {
  date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date
}

echo "=== disk-health $(timestamp) ==="

host=$(hostname 2>/dev/null || uname -n 2>/dev/null || printf 'unknown')
echo "host: $host"

uname_line=$(uname -srm 2>/dev/null || uname 2>/dev/null || printf 'unknown')
echo "uname: $uname_line"

if command -v id >/dev/null 2>&1; then
  user_name=$(id -un 2>/dev/null || printf 'unknown')
  echo "user: $user_name"
fi

if [ -r /proc/loadavg ]; then
  if read -r loadavg < /proc/loadavg; then
    echo "loadavg: $loadavg"
  fi
elif command -v uptime >/dev/null 2>&1; then
  echo "uptime: $(uptime)"
else
  echo "load: not available"
fi

echo "--- memory ---"
if [ -r /proc/meminfo ]; then
  while read -r key value unit; do
    case "$key" in
      MemTotal:|MemAvailable:|MemFree:)
        echo "$key ${value:-} ${unit:-}"
        ;;
    esac
  done < /proc/meminfo
else
  echo "memory: /proc/meminfo not available"
fi

echo "--- disk ---"
target="/"
if [ -n "${HOME:-}" ]; then
  target="$HOME"
fi

if ! command -v df >/dev/null 2>&1; then
  echo "df: not available" >&2
  exit 1
fi

if ! df -h "$target"; then
  if [ "$target" != "/" ]; then
    echo "df could not read $target; trying /" >&2
    df -h / || exit 1
  else
    echo "df failed for /" >&2
    exit 1
  fi
fi
