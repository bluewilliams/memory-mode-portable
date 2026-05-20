#!/bin/bash
# Infinite Memory Mode - User-Level Installer
# Installs memory mode configuration to ~/.claude/ (user level)
# v2.0: Supports default and Obsidian vault backends

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

echo "=== Infinite Memory Mode Installer v2.0 ==="
echo ""
echo "This will install memory mode at the user level (~/.claude/)"
echo "All projects will automatically have access to memory mode."
echo ""

# Create required directories
echo "Creating directories..."
mkdir -p "$CLAUDE_DIR/user"
mkdir -p "$CLAUDE_DIR/projects"

# ─── Backend Selection ───────────────────────────────────────────────

echo ""
echo "Choose storage backend:"
echo "  1) Default   — Files stored at ~/.claude/projects/ (current behavior)"
echo "  2) Obsidian  — Files stored in an Obsidian vault (knowledge base + memory)"
echo ""
read -p "Your choice [1/2]: " -n 1 BACKEND_CHOICE
echo ""

BACKEND="default"
VAULT_PATH=""
BASE_PATH=""

if [ "$BACKEND_CHOICE" = "2" ]; then
    BACKEND="obsidian"
    echo ""
    echo "Searching for existing Obsidian vaults..."

    # Find existing vaults
    FOUND_VAULTS=()
    while IFS= read -r -d '' vault; do
        # Get the parent directory (the vault root)
        vault_root=$(dirname "$vault")
        FOUND_VAULTS+=("$vault_root")
    done < <(find "$HOME/Documents" "$HOME/Obsidian" "$HOME/vaults" "$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents" -maxdepth 3 -name ".obsidian" -type d -print0 2>/dev/null || true)

    if [ ${#FOUND_VAULTS[@]} -gt 0 ]; then
        echo ""
        echo "Found existing Obsidian vaults:"
        for i in "${!FOUND_VAULTS[@]}"; do
            vault="${FOUND_VAULTS[$i]}"
            # Check for useful plugins
            plugins=""
            if [ -f "$vault/.obsidian/core-plugins.json" ]; then
                if jq -e '."daily-notes" == true' "$vault/.obsidian/core-plugins.json" >/dev/null 2>&1; then
                    plugins="$plugins daily-notes"
                fi
                if jq -e '.templates == true' "$vault/.obsidian/core-plugins.json" >/dev/null 2>&1; then
                    plugins="$plugins templates"
                fi
                if jq -e '.sync == true' "$vault/.obsidian/core-plugins.json" >/dev/null 2>&1; then
                    plugins="$plugins sync"
                fi
            fi
            if [ -n "$plugins" ]; then
                echo "  $((i+1))) $vault  (has:$plugins)"
            else
                echo "  $((i+1))) $vault"
            fi
        done
        echo "  $((${#FOUND_VAULTS[@]}+1))) Enter a custom path"
        echo "  $((${#FOUND_VAULTS[@]}+2))) Create a new dedicated vault"
        echo ""
        read -p "Your choice [1]: " VAULT_CHOICE

        if [ -z "$VAULT_CHOICE" ] || [ "$VAULT_CHOICE" -le "${#FOUND_VAULTS[@]}" ] 2>/dev/null; then
            # User selected an existing vault
            VAULT_IDX=${VAULT_CHOICE:-1}
            VAULT_PATH="${FOUND_VAULTS[$((VAULT_IDX-1))]}"
        elif [ "$VAULT_CHOICE" = "$((${#FOUND_VAULTS[@]}+1))" ]; then
            # Custom path
            read -p "Enter vault path: " VAULT_PATH
            VAULT_PATH="${VAULT_PATH/#\~/$HOME}"
        else
            # Create new vault
            read -p "New vault path [~/Obsidian/ClaudeMind]: " VAULT_PATH
            VAULT_PATH="${VAULT_PATH:-$HOME/Obsidian/ClaudeMind}"
            VAULT_PATH="${VAULT_PATH/#\~/$HOME}"
        fi
    else
        echo "  No existing vaults found."
        echo ""
        read -p "Vault path [~/Obsidian/ClaudeMind]: " VAULT_PATH
        VAULT_PATH="${VAULT_PATH:-$HOME/Obsidian/ClaudeMind}"
        VAULT_PATH="${VAULT_PATH/#\~/$HOME}"
    fi

    # Validate vault path
    if [ -d "$VAULT_PATH/.obsidian" ]; then
        echo ""
        echo "Found existing vault at: $VAULT_PATH"
        read -p "Claude memory subfolder name [Claude]: " BASE_PATH
        BASE_PATH="${BASE_PATH:-Claude}"
    else
        echo ""
        if [ -d "$VAULT_PATH" ]; then
            echo "Directory exists but is not an Obsidian vault (no .obsidian/ folder)."
            echo "Open this folder in Obsidian first to initialize it as a vault, then re-run."
            read -p "Continue anyway? This will create folders but you must open in Obsidian. (y/N) " -n 1
            echo ""
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                echo "Aborted. Please open $VAULT_PATH in Obsidian first."
                exit 1
            fi
        else
            echo "Creating new vault directory at: $VAULT_PATH"
            mkdir -p "$VAULT_PATH"
        fi
        BASE_PATH=""
        read -p "Claude memory subfolder name (empty for vault root) [Claude]: " BASE_PATH
        BASE_PATH="${BASE_PATH:-Claude}"
    fi

    # Determine Claude root
    if [ -n "$BASE_PATH" ]; then
        CLAUDE_ROOT="$VAULT_PATH/$BASE_PATH"
    else
        CLAUDE_ROOT="$VAULT_PATH"
    fi

    echo ""
    echo "Setting up Obsidian vault structure..."

    # Create folder structure
    mkdir -p "$CLAUDE_ROOT"/{.claude-state,Projects,Decisions,Analysis,Sessions,Progress,Sub-Agents,Brag,Meetings}
    mkdir -p "$CLAUDE_ROOT"/Resources/{PDFs,Images,Documents,Snippets,References,"Meeting Notes"}
    mkdir -p "$CLAUDE_ROOT"/People
    mkdir -p "$CLAUDE_ROOT"/_Templates

    # Copy templates
    echo "  Installing templates..."
    for template in "$SCRIPT_DIR"/obsidian-templates/*.md; do
        if [ -f "$template" ]; then
            filename=$(basename "$template")
            # _Dashboard.md, _Resource Index.md, Workspace.md, Person.md, _Preferences.md
            # go to their proper locations; actual templates go to _Templates/
            case "$filename" in
                _Dashboard.md)
                    cp "$template" "$CLAUDE_ROOT/_Dashboard.md"
                    echo "    _Dashboard.md → Claude root"
                    # Create shortcut at vault root for easy access
                    if [ ! -f "$VAULT_PATH/!Dashboard.md" ]; then
                        cat > "$VAULT_PATH/!Dashboard.md" << 'DASHEOF'
---
aliases:
  - Home
  - Dashboard
---

![[Claude/_Dashboard]]
DASHEOF
                        echo "    !Dashboard.md → vault root (shortcut)"
                    fi
                    ;;
                "_Resource Index.md")
                    cp "$template" "$CLAUDE_ROOT/Resources/_Resource Index.md"
                    echo "    _Resource Index.md → Resources/"
                    ;;
                "_Brag Dashboard.md")
                    cp "$template" "$CLAUDE_ROOT/Brag/_Brag Dashboard.md"
                    echo "    _Brag Dashboard.md → Brag/"
                    ;;
                "_Meeting Index.md")
                    cp "$template" "$CLAUDE_ROOT/Meetings/_Meeting Index.md"
                    echo "    _Meeting Index.md → Meetings/"
                    ;;
                Workspace.md)
                    if [ ! -f "$CLAUDE_ROOT/Workspace.md" ]; then
                        cp "$template" "$CLAUDE_ROOT/Workspace.md"
                        echo "    Workspace.md → vault root"
                    else
                        echo "    Workspace.md already exists, skipping"
                    fi
                    ;;
                Person.md)
                    if [ ! -f "$CLAUDE_ROOT/People/Your Name.md" ]; then
                        cp "$template" "$CLAUDE_ROOT/People/Your Name.md"
                        echo "    Person.md → People/Your Name.md"
                    else
                        echo "    Person note already exists, skipping"
                    fi
                    ;;
                _Preferences.md)
                    if [ ! -f "$CLAUDE_ROOT/People/_Preferences.md" ]; then
                        cp "$template" "$CLAUDE_ROOT/People/_Preferences.md"
                        echo "    _Preferences.md → People/"
                    else
                        echo "    Preferences already exists, skipping"
                    fi
                    ;;
                *)
                    # Regular templates go to _Templates/
                    cp "$template" "$CLAUDE_ROOT/_Templates/$filename"
                    echo "    $filename → _Templates/"
                    ;;
            esac
        fi
    done

    # Collapse vault path back to ~ for config storage
    VAULT_PATH_CONFIG="${VAULT_PATH/#$HOME/~}"

    echo "  Vault structure created at: $CLAUDE_ROOT"
    echo ""

    # Check for Obsidian Sync
    if [ -f "$VAULT_PATH/.obsidian/core-plugins.json" ]; then
        if jq -e '.sync == true' "$VAULT_PATH/.obsidian/core-plugins.json" >/dev/null 2>&1; then
            echo "  NOTE: Obsidian Sync detected. Claude's writes will sync automatically."
            echo "  This is fine — just be aware of brief sync delays for large writes."
            echo ""
        fi
    fi

    # Auto-install Dataview plugin
    if [ ! -d "$VAULT_PATH/.obsidian/plugins/dataview" ]; then
        echo "  Installing Dataview plugin..."
        mkdir -p "$VAULT_PATH/.obsidian/plugins/dataview"
        if curl -sL "https://github.com/blacksmithgu/obsidian-dataview/releases/latest/download/manifest.json" -o "$VAULT_PATH/.obsidian/plugins/dataview/manifest.json" 2>/dev/null && \
           curl -sL "https://github.com/blacksmithgu/obsidian-dataview/releases/latest/download/main.js" -o "$VAULT_PATH/.obsidian/plugins/dataview/main.js" 2>/dev/null && \
           curl -sL "https://github.com/blacksmithgu/obsidian-dataview/releases/latest/download/styles.css" -o "$VAULT_PATH/.obsidian/plugins/dataview/styles.css" 2>/dev/null; then
            # Enable Dataview with JS queries
            cat > "$VAULT_PATH/.obsidian/plugins/dataview/data.json" << 'DVEOF'
{"enableDataviewJs":true,"enableInlineDataviewJs":true,"inlineQueriesDisabled":false}
DVEOF
            # Register in community-plugins.json
            if [ -f "$VAULT_PATH/.obsidian/community-plugins.json" ]; then
                # Add dataview if not already present
                if ! grep -q '"dataview"' "$VAULT_PATH/.obsidian/community-plugins.json" 2>/dev/null; then
                    jq '. + ["dataview"]' "$VAULT_PATH/.obsidian/community-plugins.json" > "$VAULT_PATH/.obsidian/community-plugins.json.tmp" 2>/dev/null && \
                    mv "$VAULT_PATH/.obsidian/community-plugins.json.tmp" "$VAULT_PATH/.obsidian/community-plugins.json"
                fi
            else
                echo '["dataview"]' > "$VAULT_PATH/.obsidian/community-plugins.json"
            fi
            echo "    Dataview plugin installed and enabled"
        else
            echo "    Could not download Dataview (no internet?). Install manually:"
            echo "    Obsidian → Settings → Community Plugins → Browse → Dataview"
        fi
    else
        echo "  Dataview plugin already installed"
    fi

    # Check for Obsidian Sync
    if [ -f "$VAULT_PATH/.obsidian/core-plugins.json" ]; then
        if jq -e '.sync == true' "$VAULT_PATH/.obsidian/core-plugins.json" >/dev/null 2>&1; then
            echo ""
            echo "  NOTE: Obsidian Sync detected. Claude's writes will sync automatically."
        fi
    fi
    echo ""
fi

# ─── Write memory-config.json ────────────────────────────────────────

echo "Writing memory-config.json..."
if [ "$BACKEND" = "obsidian" ]; then
    cat > "$CLAUDE_DIR/memory-config.json" << EOF
{
  "version": "2.0.0",
  "backend": "obsidian",
  "obsidian": {
    "vaultPath": "$VAULT_PATH_CONFIG",
    "basePath": "$BASE_PATH",
    "features": {
      "dataview": true,
      "templates": true
    }
  },
  "default": {
    "basePath": "~/.claude/projects"
  }
}
EOF
else
    cat > "$CLAUDE_DIR/memory-config.json" << EOF
{
  "version": "2.0.0",
  "backend": "default",
  "obsidian": {
    "vaultPath": "",
    "basePath": "Claude",
    "features": {
      "dataview": true,
      "templates": true
    }
  },
  "default": {
    "basePath": "~/.claude/projects"
  }
}
EOF
fi

# ─── Core Instruction Files ──────────────────────────────────────────

# Copy core instruction files (always overwrite — these are the system instructions)
echo "Installing core instruction files..."
cp "$SCRIPT_DIR/MEMORY.md" "$CLAUDE_DIR/MEMORY.md"
cp "$SCRIPT_DIR/USER.md" "$CLAUDE_DIR/USER.md"
echo "  MEMORY.md and USER.md updated."
echo "  NOTE: These files are managed by the installer. Local edits will be overwritten on update."

# Set up workspace.md if it doesn't exist
if [ ! -f "$CLAUDE_DIR/workspace.md" ]; then
    echo "Creating workspace.md from template..."
    cp "$SCRIPT_DIR/workspace.md.example" "$CLAUDE_DIR/workspace.md"
else
    echo "workspace.md already exists, skipping."
fi

# Set up CLAUDE.md
if [ ! -f "$CLAUDE_DIR/CLAUDE.md" ]; then
    echo "Creating CLAUDE.md from template..."
    cp "$SCRIPT_DIR/CLAUDE.md.example" "$CLAUDE_DIR/CLAUDE.md"
    echo "NOTE: Review ~/.claude/CLAUDE.md and customize as needed."
else
    # Check if CLAUDE.md references both MEMORY.md and USER.md
    MISSING_REFS=""
    if ! grep -q "@MEMORY.md" "$CLAUDE_DIR/CLAUDE.md" 2>/dev/null; then
        MISSING_REFS="@MEMORY.md"
    fi
    if ! grep -q "@USER.md" "$CLAUDE_DIR/CLAUDE.md" 2>/dev/null; then
        MISSING_REFS="$MISSING_REFS @USER.md"
    fi

    if [ -n "$MISSING_REFS" ]; then
        echo ""
        echo "WARNING: ~/.claude/CLAUDE.md is missing references:$MISSING_REFS"
        echo "These are needed for memory mode to work."
        echo ""
        read -p "Would you like to append them now? (y/N) " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "" >> "$CLAUDE_DIR/CLAUDE.md"
            for ref in $MISSING_REFS; do
                echo "$ref" >> "$CLAUDE_DIR/CLAUDE.md"
                echo "  Added $ref"
            done
        fi
    else
        echo "CLAUDE.md already references @MEMORY.md and @USER.md, skipping."
    fi
fi

# Create default user profile if it doesn't exist
if [ ! -f "$CLAUDE_DIR/user/profile.md" ]; then
    echo "Creating default user profile..."
    cat > "$CLAUDE_DIR/user/profile.md" << EOF
# User Profile

**Created**: $TIMESTAMP
**Last Updated**: $TIMESTAMP

## Identity
- **Name**:
- **Role**:
- **Experience Level**:

## Background


## Working Style

EOF
fi

if [ ! -f "$CLAUDE_DIR/user/preferences.md" ]; then
    echo "Creating default preferences..."
    cat > "$CLAUDE_DIR/user/preferences.md" << EOF
# User Preferences

**Last Updated**: $TIMESTAMP

## Communication
- **Detail Level**: balanced
- **Explanation Style**: explain-then-code
- **Feedback Style**: direct

## Code Preferences
- **Comments**: moderate
- **Naming**: descriptive
- **Error Handling**: fail-fast

## Workflow
- **Planning**: light-plan
- **Review**: show-diffs
- **Testing**: automated

## Tool Preferences
- **Default Persona**:
- **Thinking Depth**: standard
- **Compression**: auto
EOF
fi

# ─── Auto-Save Hooks ─────────────────────────────────────────────────

echo ""
echo "Installing auto-save hooks..."
HOOKS_DIR="$CLAUDE_DIR/hooks"
STATE_DIR="$CLAUDE_DIR/.memory-hooks"
mkdir -p "$HOOKS_DIR"
mkdir -p "$STATE_DIR"

cp "$SCRIPT_DIR/hooks/memory-common.sh" "$HOOKS_DIR/memory-common.sh"
cp "$SCRIPT_DIR/hooks/memory-tracker.sh" "$HOOKS_DIR/memory-tracker.sh"
cp "$SCRIPT_DIR/hooks/memory-nudge.sh" "$HOOKS_DIR/memory-nudge.sh"
cp "$SCRIPT_DIR/hooks/memory-precompact.sh" "$HOOKS_DIR/memory-precompact.sh"
chmod +x "$HOOKS_DIR"/*.sh

# Initialize state file
echo '{"edits":0,"commits":0,"files_changed":[],"last_commit":"","last_nudge":0}' > "$STATE_DIR/activity.json"

SETTINGS_FILE="$CLAUDE_DIR/settings.json"
if [ ! -f "$SETTINGS_FILE" ]; then
    cat > "$SETTINGS_FILE" << 'HOOKEOF'
{
  "autoMemoryEnabled": false,
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
HOOKEOF
    echo "  Auto-save hooks installed and configured"
else
    # Check if hooks already configured
    if jq -e '.hooks' "$SETTINGS_FILE" > /dev/null 2>&1; then
        echo "  Hook scripts updated (settings.json already has hooks configured)"
    else
        echo "  Hook scripts installed to ~/.claude/hooks/"
        echo ""
        echo "  NOTE: Your settings.json exists but has no hooks section."
        echo "  Run ./hooks/install-hooks.sh for merge instructions, or add manually:"
        echo "  See hooks/install-hooks.sh for the JSON to add."
    fi
fi

# ─── Disable Anthropic auto-memory ───────────────────────────────────
# Anthropic ships auto-memory ON by default (autoMemoryEnabled). This system
# IS the memory layer; running both side-by-side double-loads context and
# makes /memory ambiguous. We want it off. But this is the user's settings
# file - if they have already set the key themselves (true OR false), we
# respect that choice and do not touch it. python3 primary, jq fallback.
if command -v python3 &> /dev/null; then
    python3 - "$SETTINGS_FILE" <<'PYEOF' || echo "  WARN: auto-memory config step failed; install continues."
import json, os, sys, shutil, tempfile
path = sys.argv[1]
try:
    with open(path) as f:
        data = json.load(f)
except Exception as e:
    print(f"  WARN: cannot parse {path} ({e}); skipping autoMemoryEnabled config.")
    sys.exit(0)
if not isinstance(data, dict):
    print(f"  WARN: {path} root is not a JSON object; skipping autoMemoryEnabled config.")
    sys.exit(0)
if 'autoMemoryEnabled' in data:
    print(f"  Anthropic auto-memory: keeping your existing autoMemoryEnabled={str(data['autoMemoryEnabled']).lower()}")
    sys.exit(0)
shutil.copy2(path, path + '.bak')
data['autoMemoryEnabled'] = False
target_dir = os.path.dirname(path) or '.'
fd, tmp = tempfile.mkstemp(dir=target_dir, prefix='.settings-', suffix='.tmp')
try:
    with os.fdopen(fd, 'w') as f:
        json.dump(data, f, indent=2)
        f.write('\n')
    os.replace(tmp, path)
except Exception:
    if os.path.exists(tmp):
        os.remove(tmp)
    raise
print("  Anthropic auto-memory disabled (autoMemoryEnabled: false). Re-enable in ~/.claude/settings.json if desired.")
PYEOF
elif command -v jq &> /dev/null; then
    if jq -e 'has("autoMemoryEnabled")' "$SETTINGS_FILE" > /dev/null 2>&1; then
        EXISTING_AME=$(jq -r '.autoMemoryEnabled' "$SETTINGS_FILE")
        echo "  Anthropic auto-memory: keeping your existing autoMemoryEnabled=$EXISTING_AME"
    else
        cp "$SETTINGS_FILE" "$SETTINGS_FILE.bak"
        if jq '. + {autoMemoryEnabled: false}' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp" 2>/dev/null; then
            mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
            echo "  Anthropic auto-memory disabled (autoMemoryEnabled: false). Re-enable in ~/.claude/settings.json if desired."
        else
            rm -f "$SETTINGS_FILE.tmp"
            echo "  WARN: jq merge failed for autoMemoryEnabled; install continues."
        fi
    fi
else
    echo "  WARN: neither python3 nor jq found; cannot auto-disable Anthropic auto-memory."
    echo "        Manual fix: add \"autoMemoryEnabled\": false to ~/.claude/settings.json"
fi

# ─── Summary ─────────────────────────────────────────────────────────

echo ""
echo "=== Installation Complete ==="
echo ""
echo "Installed to: $CLAUDE_DIR/"
echo "Backend: $BACKEND"
if [ "$BACKEND" = "obsidian" ]; then
    echo "Vault: $VAULT_PATH"
    if [ -n "$BASE_PATH" ]; then
        echo "Claude root: $VAULT_PATH/$BASE_PATH/"
    fi
fi
echo ""
echo "Structure:"
echo "  ~/.claude/CLAUDE.md          - Entry point (references @MEMORY.md, @USER.md)"
echo "  ~/.claude/MEMORY.md          - Memory mode instructions (managed by installer)"
echo "  ~/.claude/USER.md            - User preference system (managed by installer)"
echo "  ~/.claude/memory-config.json - Backend configuration"
echo "  ~/.claude/workspace.md       - Cross-project map (yours to edit)"
echo "  ~/.claude/user/              - Your global profile (yours to edit)"
if [ "$BACKEND" = "obsidian" ]; then
    echo ""
    echo "Obsidian vault:"
    echo "  $CLAUDE_ROOT/_Dashboard.md   - Main dashboard (Dataview-powered)"
    echo "  $CLAUDE_ROOT/_Templates/     - Note templates"
    echo "  $CLAUDE_ROOT/Projects/       - Project notes"
    echo "  $CLAUDE_ROOT/Decisions/      - Decision records"
    echo "  $CLAUDE_ROOT/Sessions/       - Session logs"
    echo "  $CLAUDE_ROOT/Resources/      - Shared files & references"
    echo "  $CLAUDE_ROOT/People/         - People & preferences"
    echo "  $CLAUDE_ROOT/Lessons/        - Cross-project engineering lessons (on-demand)"
fi
echo ""
echo "Next steps:"
if [ "$BACKEND" = "obsidian" ]; then
    echo "  1. Open your vault in Obsidian and edit People/Your Name.md with your info"
    echo "  2. That's it. Memory is always on. Just start working."
    echo ""
    echo "  Optional: Enable Templates core plugin (Settings → Core Plugins → Templates)"
    echo "            Set template folder to: ${BASE_PATH:+$BASE_PATH/}_Templates"
else
    echo "  1. Edit ~/.claude/user/profile.md with your info"
    echo "  2. Open any project and start working. Memory is always on."
fi
echo ""
echo "To switch backends later, edit ~/.claude/memory-config.json"
echo "To migrate existing memories to Obsidian: ./migrate-to-obsidian.sh"
echo "To update later, pull the latest and re-run this script."
