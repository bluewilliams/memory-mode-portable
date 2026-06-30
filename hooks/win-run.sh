#!/bin/bash
# win-run.sh — Windows launcher for memory hooks.
#
# Why this exists: on Windows, Claude Code invokes hook `command`s via cmd/PowerShell,
# which cannot execute a bare `.sh`; and the hooks depend on `jq`, which is not on the
# default Windows PATH. settings.json therefore calls Git bash explicitly and points it
# at this wrapper, which:
#   1. puts the bundled jq (~/.claude/bin) on PATH, and
#   2. execs the named hook so Claude Code's hook JSON on stdin passes straight through.
#
# settings.json command form (Windows):
#   "C:\\Program Files\\Git\\usr\\bin\\bash.exe" "C:\\Users\\<you>\\.claude\\hooks\\win-run.sh" memory-tracker.sh
#
# usage: win-run.sh <hook-script-name>
HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PATH="$HOOK_DIR/../bin:$PATH"
exec "$HOOK_DIR/$1"
