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
