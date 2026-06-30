#!/bin/bash
# install-windows.sh — Windows installer for Infinite Memory Mode (run under Git Bash).
#
# The main install.sh assumes a Unix-y Claude Code where hook `command`s run under sh and
# `jq` is on PATH. On Windows neither holds: Claude Code runs hook commands via cmd/PowerShell
# (so a bare `.sh` won't execute) and jq is usually absent. This installer handles both:
#   - bundles jq.exe into ~/.claude/bin
#   - installs the hooks + win-run.sh wrapper
#   - wires settings.json hook commands to call Git bash -> win-run.sh -> <hook> (jq on PATH,
#     stdin passed through), MERGING into any existing settings.json (preserves your config)
#   - sets autoMemoryEnabled:false only if you haven't set it yourself
#
# Obsidian backend note: if your vault lives on a host shared into the VM (e.g. a Parallels/UNC
# share like //Mac/Home/...), pass that path as the vault path — bash resolves it directly.
#
# Usage:
#   ./install-windows.sh                          # default backend (~/.claude/projects)
#   ./install-windows.sh --obsidian "<vaultPath>" # obsidian backend at <vaultPath>, basePath=Claude
#
# Requires: Git for Windows (bash), Node.js (ships with Claude Code), curl.
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CL="$HOME/.claude"
BACKEND="default"
VAULT=""
BASE="Claude"

while [ $# -gt 0 ]; do
  case "$1" in
    --obsidian) BACKEND="obsidian"; VAULT="$2"; shift 2 ;;
    --base) BASE="$2"; shift 2 ;;
    *) echo "unknown arg: $1"; exit 2 ;;
  esac
done

# Locate Git bash for the settings.json command. Prefer the running bash.
BASH_EXE="$(cygpath -w "$(command -v bash)" 2>/dev/null || echo 'C:\Program Files\Git\usr\bin\bash.exe')"

echo "=== Infinite Memory Mode — Windows installer ==="
echo "  backend: $BACKEND${VAULT:+  vault: $VAULT  (base: $BASE)}"
mkdir -p "$CL/bin" "$CL/hooks" "$CL/user" "$CL/.memory-hooks"

# 1) jq.exe (amd64 runs under x64 emulation on Windows-ARM64 too)
if [ ! -f "$CL/bin/jq.exe" ]; then
  echo "  downloading jq.exe..."
  curl -sL "https://github.com/jqlang/jq/releases/latest/download/jq-windows-amd64.exe" -o "$CL/bin/jq.exe"
fi
echo '{}' | "$CL/bin/jq.exe" empty && echo "  jq ok"

# 2) core instruction files (always refreshed — installer-managed)
cp "$SCRIPT_DIR/MEMORY.md" "$CL/MEMORY.md"
cp "$SCRIPT_DIR/USER.md"   "$CL/USER.md"
[ -f "$CL/CLAUDE.md" ]    || cp "$SCRIPT_DIR/CLAUDE.md.example" "$CL/CLAUDE.md"
[ -f "$CL/workspace.md" ] || cp "$SCRIPT_DIR/workspace.md.example" "$CL/workspace.md"

# 3) memory-config.json
if [ "$BACKEND" = "obsidian" ]; then
  cat > "$CL/memory-config.json" << EOF
{
  "version": "2.0.0",
  "backend": "obsidian",
  "obsidian": { "vaultPath": "$VAULT", "basePath": "$BASE", "features": { "dataview": true, "templates": true } },
  "default": { "basePath": "~/.claude/projects" }
}
EOF
else
  cat > "$CL/memory-config.json" << 'EOF'
{
  "version": "2.0.0",
  "backend": "default",
  "obsidian": { "vaultPath": "", "basePath": "Claude", "features": { "dataview": true, "templates": true } },
  "default": { "basePath": "~/.claude/projects" }
}
EOF
fi

# 4) hooks + win-run.sh wrapper
for h in memory-common.sh memory-tracker.sh memory-nudge.sh memory-precompact.sh win-run.sh; do
  cp "$SCRIPT_DIR/hooks/$h" "$CL/hooks/$h"
done
chmod +x "$CL/hooks/"*.sh
[ -f "$CL/.memory-hooks/activity.json" ] || echo '{"edits":0,"commits":0,"files_changed":[],"last_commit":"","last_nudge":0,"cycles":0}' > "$CL/.memory-hooks/activity.json"

# 5) merge hooks into settings.json (preserve existing), using Node (always present with Claude Code)
SETTINGS="$CL/settings.json"
[ -f "$SETTINGS" ] && cp "$SETTINGS" "$SETTINGS.memory-bak"
BASH_EXE="$BASH_EXE" WIN_RUN="$(cygpath -w "$CL/hooks/win-run.sh")" SETTINGS="$SETTINGS" node - << 'NODE'
const fs = require('fs');
const p = process.env.SETTINGS;
const s = fs.existsSync(p) ? JSON.parse(fs.readFileSync(p, 'utf8')) : {};
const esc = x => x.replace(/\\/g, '\\\\');
const cmd = h => `"${esc(process.env.BASH_EXE)}" "${esc(process.env.WIN_RUN)}" ${h}`;
s.hooks = s.hooks || {};
s.hooks.PostToolUse   = [{ matcher: 'Edit|Write|MultiEdit|Bash', hooks: [{ type: 'command', command: cmd('memory-tracker.sh') }] }];
s.hooks.UserPromptSubmit = [{ hooks: [{ type: 'command', command: cmd('memory-nudge.sh') }] }];
s.hooks.PreCompact    = [{ hooks: [{ type: 'command', command: cmd('memory-precompact.sh') }] }];
if (!('autoMemoryEnabled' in s)) s.autoMemoryEnabled = false;
fs.writeFileSync(p, JSON.stringify(s, null, 2) + '\n');
console.log('  settings.json merged (hooks + autoMemoryEnabled), existing keys preserved');
NODE

echo ""
echo "=== Windows install complete ==="
echo "  Restart Claude Code so it reloads settings.json."
echo "  Verify a hook:  echo '{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"x\"}}' | \"$BASH_EXE\" \"$CL/hooks/win-run.sh\" memory-tracker.sh"
