#!/usr/bin/env bash
# Demo task shipped with Steel Panda.
# Prints one success line and a UTC timestamp, then exits 0.
# Does not change files or open a network connection.
echo "Example task executed successfully."
date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date
