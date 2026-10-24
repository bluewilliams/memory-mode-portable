#!/bin/bash
# memory-common.sh — Shared utilities for memory hooks
# Determines active backend and resolves paths.
#
# Source this from other hook scripts:
#   source "$(dirname "$0")/memory-common.sh" 2>/dev/null || true
#
# NOTE: Do NOT use `set -e` — failures must not kill the calling hook.

CONFIG_FILE="$HOME/.claude/memory-config.json"

# Get the active backend ("default" or "obsidian")
get_backend() {
    if [ -f "$CONFIG_FILE" ] && echo '{}' | jq empty >/dev/null 2>&1; then
        local backend
        backend=$(jq -r '.backend // "default"' "$CONFIG_FILE" 2>/dev/null) || true
        if [ -n "$backend" ] && [ "$backend" != "null" ]; then
            echo "$backend"
        else
            echo "default"
        fi
    else
        echo "default"
    fi
}

# Get the Obsidian vault root path (expanded)
get_vault_path() {
    if [ -f "$CONFIG_FILE" ]; then
        local raw
        raw=$(jq -r '.obsidian.vaultPath // empty' "$CONFIG_FILE" 2>/dev/null) || true
        if [ -n "$raw" ]; then
            # Expand ~ to $HOME
            echo "${raw/#\~/$HOME}"
        fi
    fi
}

# Get the base path within the vault (e.g., "Claude")
get_base_path() {
    if [ -f "$CONFIG_FILE" ]; then
        local raw
        raw=$(jq -r '.obsidian.basePath // empty' "$CONFIG_FILE" 2>/dev/null) || true
        echo "$raw"
    fi
}

# Get the full Claude root path (vault + base path)
get_claude_root() {
    local backend
    backend=$(get_backend)
    if [ "$backend" = "obsidian" ]; then
        local vault base
        vault=$(get_vault_path)
        base=$(get_base_path)
        if [ -n "$vault" ]; then
            if [ -n "$base" ]; then
                echo "$vault/$base"
            else
                echo "$vault"
            fi
        fi
    else
        echo "$HOME/.claude/projects"
    fi
}

# Get the state directory for hooks (activity.json lives here)
get_state_dir() {
    local backend
    backend=$(get_backend)
    if [ "$backend" = "obsidian" ]; then
        local claude_root
        claude_root=$(get_claude_root)
        if [ -n "$claude_root" ]; then
            echo "$claude_root/.claude-state"
        else
            echo "$HOME/.claude/.memory-hooks"
        fi
    else
        echo "$HOME/.claude/.memory-hooks"
    fi
}

# ---------------------------------------------------------------------------
# v2.2: per-session state, the local clock, and the work day
# ---------------------------------------------------------------------------

INIT_ACTIVITY_JSON='{"edits":0,"commits":0,"files_changed":[],"last_commit":"","last_nudge":0,"cycles":0}'

# The session id from a hook's stdin JSON (empty when absent). Claude Code sends session_id to every hook.
session_id_from_json() {
    local input="$1" sid
    sid=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null) || true
    # Keep it filename-safe: letters, digits, dash and underscore only.
    printf '%s' "$sid" | tr -cd 'A-Za-z0-9_-' | cut -c1-80
}

# The activity file for a session. Concurrent sessions each count their own edits and commits;
# without a session id (older Claude Code, manual runs) every caller shares activity.json as before.
activity_file_for() {
    local state_dir="$1" sid="$2"
    if [ -n "$sid" ]; then
        mkdir -p "$state_dir/sessions" 2>/dev/null || true
        echo "$state_dir/sessions/activity-$sid.json"
    else
        echo "$state_dir/activity.json"
    fi
}

# Work-day boundary hour. Work before this hour belongs to the previous day, so a session that runs
# past midnight keeps writing to the same dated session note.
WORKDAY_BOUNDARY_HOUR=4

# The work day (YYYY-MM-DD) for an epoch. Uses local time.
workday_for_epoch() {
    local epoch="$1" shifted
    shifted=$((epoch - WORKDAY_BOUNDARY_HOUR * 3600))
    if date -r "$shifted" +%Y-%m-%d >/dev/null 2>&1; then
        date -r "$shifted" +%Y-%m-%d
    else
        date -d "@$shifted" +%Y-%m-%d
    fi
}

# Format an epoch with a date(1) format string, on BSD (macOS) and GNU (Linux, Git Bash) date.
format_epoch() {
    local epoch="$1" fmt="$2"
    if date -r "$epoch" "+$fmt" >/dev/null 2>&1; then
        date -r "$epoch" "+$fmt"
    else
        date -d "@$epoch" "+$fmt"
    fi
}

# The local-noon epoch for a YYYY-MM-DD date (noon keeps day math clear of DST shifts). Empty when invalid.
epoch_for_date() {
    local d="$1"
    printf '%s' "$d" | grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' || return 1
    date -j -f "%Y-%m-%d %H:%M:%S" "$d 12:00:00" +%s 2>/dev/null || date -d "$d 12:00:00" +%s 2>/dev/null
}

# The part of the day for a local hour (0-23).
daypart_for_hour() {
    local h=$((10#$1))
    if [ "$h" -lt "$WORKDAY_BOUNDARY_HOUR" ]; then echo "late night"
    elif [ "$h" -lt 12 ]; then echo "morning"
    elif [ "$h" -lt 17 ]; then echo "afternoon"
    elif [ "$h" -lt 21 ]; then echo "evening"
    else echo "late evening"
    fi
}

# A short human gap: "45m", "3h 10m", "2d 4h".
human_gap() {
    local s="$1"
    if [ "$s" -lt 3600 ]; then echo "$((s / 60))m"
    elif [ "$s" -lt 86400 ]; then echo "$((s / 3600))h $(((s % 3600) / 60))m"
    else echo "$((s / 86400))d $(((s % 86400) / 3600))h"
    fi
}
