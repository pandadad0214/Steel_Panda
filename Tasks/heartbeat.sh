#!/usr/bin/env bash
# Heartbeat sample for Steel Panda.
#
# Default: print one line and exit 0. No file is created.
#
# Optional, off unless you set them:
#   STEEL_HEARTBEAT_FILE=/path/to/steel-heartbeat.log
#     Append the same line to that one file.
#   STEEL_HEARTBEAT_ROTATE=1
#     When the file is at least STEEL_HEARTBEAT_MAX_BYTES (default 4096),
#     rename it to the same path plus ".1" and start a new file.
#     The only paths this can change are that file and its ".1" backup.
#     An existing ".1" backup is replaced.
#   Setting STEEL_HEARTBEAT_ROTATE without STEEL_HEARTBEAT_FILE exits 1.
#
# Symlinks are refused. This task does not open a network connection.
set -u

timestamp() {
  date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date
}

# Returns 0 when the flag is on, 1 when it is off, and exits 1 when it is invalid.
flag_on() {
  raw=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')
  case "$raw" in
    1|true|yes|on) return 0 ;;
    ""|0|false|no|off) return 1 ;;
    *)
      printf 'STEEL_HEARTBEAT_ROTATE must be 1, true, yes, on, 0, false, no, or off (got: %s)\n' "$1" >&2
      exit 1
      ;;
  esac
}

line="heartbeat ok $(timestamp)"
printf '%s\n' "$line"

file=${STEEL_HEARTBEAT_FILE:-}
rotate_raw=${STEEL_HEARTBEAT_ROTATE:-}
max=${STEEL_HEARTBEAT_MAX_BYTES:-4096}

case "$max" in
  ""|*[!0-9]*)
    printf 'STEEL_HEARTBEAT_MAX_BYTES must be a non-negative integer (got: %s)\n' "$max" >&2
    exit 1
    ;;
esac

rotate_on=0
if flag_on "$rotate_raw"; then
  rotate_on=1
fi

if [ -z "$file" ]; then
  if [ "$rotate_on" -eq 1 ]; then
    printf 'STEEL_HEARTBEAT_ROTATE is set but STEEL_HEARTBEAT_FILE is empty.\n' >&2
    exit 1
  fi
  exit 0
fi

if [ -d "$file" ]; then
  printf 'STEEL_HEARTBEAT_FILE is a directory: %s\n' "$file" >&2
  exit 1
fi
if [ -L "$file" ] || [ -L "$file.1" ]; then
  printf 'Refusing to follow a symlink for the heartbeat file: %s\n' "$file" >&2
  exit 1
fi

parent=$(dirname -- "$file")
mkdir -p -- "$parent" || exit 1

if [ "$rotate_on" -eq 1 ] && [ -f "$file" ]; then
  size=$(wc -c < "$file" | tr -d '[:space:]')
  case "$size" in
    ""|*[!0-9]*)
      printf 'Could not read the size of %s\n' "$file" >&2
      exit 1
      ;;
  esac
  if [ "$size" -ge "$max" ]; then
    mv -f -- "$file" "$file.1"
    printf 'heartbeat rotated %s -> %s.1\n' "$file" "$file"
  fi
fi

printf '%s\n' "$line" >> "$file"
printf 'heartbeat wrote %s\n' "$file"
