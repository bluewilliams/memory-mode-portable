#!/bin/bash
# install-hooks.sh - Installs memory mode hooks into Claude Code settings
# Adds hook configuration to ~/.claude/settings.json

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"
HOOKS_DIR="$CLAUDE_DIR/hooks"
STATE_DIR="$CLAUDE_DIR/.memory-hooks"

echo "=== Memory Mode Hooks Installer ==="
echo ""

# Create directories
mkdir -p "$HOOKS_DIR"
mkdir -p "$STATE_DIR"

# Copy hook scripts
echo "Installing hook scripts to ~/.claude/hooks/..."
cp "$SCRIPT_DIR/memory-common.sh" "$HOOKS_DIR/memory-common.sh"
cp "$SCRIPT_DIR/memory-tracker.sh" "$HOOKS_DIR/memory-tracker.sh"
cp "$SCRIPT_DIR/memory-nudge.sh" "$HOOKS_DIR/memory-nudge.sh"
cp "$SCRIPT_DIR/memory-precompact.sh" "$HOOKS_DIR/memory-precompact.sh"
chmod +x "$HOOKS_DIR/memory-common.sh"
chmod +x "$HOOKS_DIR/memory-tracker.sh"
chmod +x "$HOOKS_DIR/memory-nudge.sh"
chmod +x "$HOOKS_DIR/memory-precompact.sh"

# Check if settings.json exists
if [ ! -f "$SETTINGS_FILE" ]; then
    echo "Creating settings.json with hook configuration..."
    cat > "$SETTINGS_FILE" << 'EOF'
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write|MultiEdit|Bash",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/memory-tracker.sh"
          }
        ]
      }
    ],
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/memory-nudge.sh"
          }
        ]
      }
    ],
    "PreCompact": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/memory-precompact.sh"
          }
        ]
      }
    ]
  }
}
EOF
    echo "Created ~/.claude/settings.json with hooks."
else
    # Check if hooks are already configured
    if jq -e '.hooks' "$SETTINGS_FILE" > /dev/null 2>&1; then
        echo "WARNING: ~/.claude/settings.json already has hooks configured."
        echo "Please merge the following hook configuration manually:"
    else
        echo "NOTE: ~/.claude/settings.json exists but has no hooks."
        echo "Please add the following hook configuration:"
    fi
    echo ""
    cat << 'HOOKCONFIG'
Add this to your ~/.claude/settings.json:

"hooks": {
  "PostToolUse": [
    {
      "matcher": "Edit|Write|MultiEdit|Bash",
      "hooks": [
        {
          "type": "command",
          "command": "~/.claude/hooks/memory-tracker.sh"
        }
      ]
    }
  ],
  "UserPromptSubmit": [
    {
      "hooks": [
        {
          "type": "command",
          "command": "~/.claude/hooks/memory-nudge.sh"
        }
      ]
    }
  ],
  "PreCompact": [
    {
      "hooks": [
        {
          "type": "command",
          "command": "~/.claude/hooks/memory-precompact.sh"
        }
      ]
    }
  ]
}
HOOKCONFIG
fi

# Initialize state file
echo '{"edits":0,"commits":0,"files_changed":[],"last_commit":"","last_nudge":0}' > "$STATE_DIR/activity.json"

echo ""
echo "=== Hooks Installation Complete ==="
echo ""
echo "Hook scripts installed to: $HOOKS_DIR/"
echo "  memory-common.sh     - Shared backend utilities"
echo "  memory-tracker.sh    - Tracks edits and commits (PostToolUse)"
echo "  memory-nudge.sh      - Nudges memory save on user prompt (UserPromptSubmit)"
echo "  memory-precompact.sh - Forces save before compaction (PreCompact)"
echo ""
echo "How it works:"
echo "  1. Every file edit and git commit is silently tracked"
echo "  2. When you send your next message, Claude gets a nudge if:"
echo "     - Any commits happened since last save"
echo "     - 10+ file edits happened since last save"
echo "  3. Before context compaction, Claude gets a critical save reminder"
echo "  4. Nudges are rate-limited to once per 5 minutes"
