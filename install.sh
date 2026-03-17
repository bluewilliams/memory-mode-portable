#!/bin/bash
# Infinite Memory Mode - User-Level Installer
# Installs memory mode configuration to ~/.claude/ (user level)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"

echo "=== Infinite Memory Mode Installer ==="
echo ""
echo "This will install memory mode at the user level (~/.claude/)"
echo "All projects will automatically have access to memory mode."
echo ""

# Create required directories
echo "Creating directories..."
mkdir -p "$CLAUDE_DIR/user"
mkdir -p "$CLAUDE_DIR/projects"

# Copy core instruction files
echo "Installing core files..."
cp "$SCRIPT_DIR/MEMORY.md" "$CLAUDE_DIR/MEMORY.md"
cp "$SCRIPT_DIR/USER.md" "$CLAUDE_DIR/USER.md"

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
    # Check if CLAUDE.md already references MEMORY.md
    if grep -q "@MEMORY.md" "$CLAUDE_DIR/CLAUDE.md" 2>/dev/null; then
        echo "CLAUDE.md already references @MEMORY.md, skipping."
    else
        echo ""
        echo "WARNING: ~/.claude/CLAUDE.md exists but doesn't reference @MEMORY.md"
        echo "Add these lines to your ~/.claude/CLAUDE.md:"
        echo ""
        echo "  @MEMORY.md"
        echo "  @USER.md"
        echo ""
        read -p "Would you like to append them now? (y/N) " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "" >> "$CLAUDE_DIR/CLAUDE.md"
            echo "@MEMORY.md" >> "$CLAUDE_DIR/CLAUDE.md"
            echo "@USER.md" >> "$CLAUDE_DIR/CLAUDE.md"
            echo "Added @MEMORY.md and @USER.md references."
        fi
    fi
fi

# Create default user profile if it doesn't exist
if [ ! -f "$CLAUDE_DIR/user/profile.md" ]; then
    echo "Creating default user profile..."
    cat > "$CLAUDE_DIR/user/profile.md" << 'EOF'
# User Profile

**Created**: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
**Last Updated**: $(date -u +"%Y-%m-%dT%H:%M:%SZ")

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
    cat > "$CLAUDE_DIR/user/preferences.md" << 'EOF'
# User Preferences

**Last Updated**: $(date -u +"%Y-%m-%dT%H:%M:%SZ")

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

echo ""
echo "=== Installation Complete ==="
echo ""
echo "Installed to: $CLAUDE_DIR/"
echo ""
echo "Structure:"
echo "  ~/.claude/CLAUDE.md      - Entry point (references @MEMORY.md, @USER.md)"
echo "  ~/.claude/MEMORY.md      - Memory mode instructions"
echo "  ~/.claude/USER.md        - User preference system"
echo "  ~/.claude/workspace.md   - Cross-project map"
echo "  ~/.claude/user/          - Your global profile"
echo "  ~/.claude/projects/      - Per-project memory (created on first use)"
echo ""
echo "Next steps:"
echo "  1. Edit ~/.claude/user/profile.md with your info"
echo "  2. Open any project and run: /memory start"
echo "  3. After first use, memory auto-activates for that project"
echo ""
echo "To update later, pull the latest and re-run this script."
