#!/bin/bash
# migrate-to-obsidian.sh — Migrate v1.x memory files to Obsidian vault
#
# Converts existing ~/.claude/projects/ memory files into Obsidian vault
# format with YAML frontmatter, tags, and wikilinks.
#
# Usage:
#   ./migrate-to-obsidian.sh              # reads vault path from memory-config.json
#   ./migrate-to-obsidian.sh /path/to/vault  # explicit vault path

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
CONFIG_FILE="$CLAUDE_DIR/memory-config.json"
PROJECTS_DIR="$CLAUDE_DIR/projects"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
TODAY=$(date +"%Y-%m-%d")

# Counters
PROJECTS_MIGRATED=0
DECISIONS_MIGRATED=0
ANALYSES_MIGRATED=0
SESSIONS_CREATED=0
PROGRESS_CREATED=0
SUBAGENTS_MIGRATED=0
LINKS_CREATED=0
TAGS_APPLIED=0

# ─── Resolve vault path ──────────────────────────────────────────────

if [ -n "$1" ]; then
    VAULT_PATH="${1/#\~/$HOME}"
    BASE_PATH="Claude"
elif [ -f "$CONFIG_FILE" ]; then
    VAULT_PATH=$(jq -r '.obsidian.vaultPath // empty' "$CONFIG_FILE" 2>/dev/null)
    VAULT_PATH="${VAULT_PATH/#\~/$HOME}"
    BASE_PATH=$(jq -r '.obsidian.basePath // "Claude"' "$CONFIG_FILE" 2>/dev/null)
else
    echo "ERROR: No vault path provided and no memory-config.json found."
    echo "Usage: ./migrate-to-obsidian.sh [vault-path]"
    echo "Or run ./install.sh first to configure the Obsidian backend."
    exit 1
fi

if [ -z "$VAULT_PATH" ]; then
    echo "ERROR: Could not determine vault path."
    exit 1
fi

if [ -n "$BASE_PATH" ]; then
    CLAUDE_ROOT="$VAULT_PATH/$BASE_PATH"
else
    CLAUDE_ROOT="$VAULT_PATH"
fi

echo "=== Memory Mode Migration to Obsidian ==="
echo ""
echo "Source:      $PROJECTS_DIR/"
echo "Destination: $CLAUDE_ROOT/"
echo ""

if [ ! -d "$PROJECTS_DIR" ]; then
    echo "No existing memory files found at $PROJECTS_DIR"
    echo "Nothing to migrate."
    exit 0
fi

# Ensure vault structure exists
mkdir -p "$CLAUDE_ROOT"/{.claude-state,Projects,Decisions,Analysis,Sessions,Progress,Sub-Agents}
mkdir -p "$CLAUDE_ROOT"/Resources/{PDFs,Images,Documents,Snippets,References,"Meeting Notes"}
mkdir -p "$CLAUDE_ROOT"/People

# ─── Helper Functions ─────────────────────────────────────────────────

# Convert a project key to a human-readable name
# e.g., "memory-mode-portable" → "memory-mode-portable"
# e.g., "-Users-blue-workspace-my-app" → "my-app" (strip path-based keys)
clean_project_name() {
    local key="$1"
    # If it starts with dash (path-based key from Claude Code), extract last segment
    if [[ "$key" == -* ]]; then
        key=$(echo "$key" | rev | cut -d'-' -f1-3 | rev)
        # Further cleanup: if it looks like workspace-something, take the something
        key=$(echo "$key" | sed 's/^workspace-//')
    fi
    echo "$key"
}

# Infer tags from file content
infer_tags() {
    local file="$1"
    local tags=""
    local content
    content=$(cat "$file" 2>/dev/null) || true

    # Domain detection
    echo "$content" | grep -qi "security\|vulnerability\|auth\|XSS\|CSRF\|injection" && tags="$tags security"
    echo "$content" | grep -qi "performance\|optimize\|bottleneck\|latency\|cache" && tags="$tags performance"
    echo "$content" | grep -qi "architecture\|design\|system\|scalab" && tags="$tags architecture"
    echo "$content" | grep -qi "frontend\|component\|UI\|CSS\|React\|Vue" && tags="$tags frontend"
    echo "$content" | grep -qi "backend\|API\|endpoint\|database\|server" && tags="$tags backend"
    echo "$content" | grep -qi "test\|coverage\|QA\|spec\|jest\|playwright" && tags="$tags testing"
    echo "$content" | grep -qi "deploy\|CI/CD\|Docker\|infrastructure" && tags="$tags devops"
    echo "$content" | grep -qi "database\|migration\|SQL\|ORM\|schema" && tags="$tags database"

    echo "$tags" | xargs  # trim whitespace
}

# Format tags as YAML array items
format_tags() {
    local tags="$1"
    for tag in $tags; do
        echo "  - $tag"
        TAGS_APPLIED=$((TAGS_APPLIED + 1))
    done
}

# Extract the first H1 heading from a markdown file
get_title() {
    grep -m1 "^# " "$1" 2>/dev/null | sed 's/^# //' || echo "Untitled"
}

# ─── Migrate Projects ────────────────────────────────────────────────

echo "Scanning projects..."
echo ""

for project_dir in "$PROJECTS_DIR"/*/; do
    [ -d "$project_dir" ] || continue

    project_key=$(basename "$project_dir")
    project_name=$(clean_project_name "$project_key")

    # Skip worktree directories
    if [[ "$project_key" == *"--claude-worktrees"* ]]; then
        echo "  Skipping worktree: $project_key"
        continue
    fi

    echo "── Migrating: $project_name (key: $project_key)"

    # Create state directory
    mkdir -p "$CLAUDE_ROOT/.claude-state/$project_key"

    # ── project.md → Projects/{name}.md ──
    if [ -f "$project_dir/project.md" ]; then
        project_file="$CLAUDE_ROOT/Projects/$project_name.md"
        if [ ! -f "$project_file" ]; then
            title=$(get_title "$project_dir/project.md")
            # Read existing content (skip the first H1 line)
            body=$(sed '1{/^# /d;}' "$project_dir/project.md")

            # Try to extract fields from existing content
            project_path=$(grep -m1 "^\*\*Path\*\*:" "$project_dir/project.md" 2>/dev/null | sed 's/.*: *//' || true)
            project_repo=$(grep -m1 "^\*\*Repo\*\*:" "$project_dir/project.md" 2>/dev/null | sed 's/.*: *//' || true)

            cat > "$project_file" << EOF
---
type: project
path: $project_path
repo: $project_repo
status: active
stack: []
tags:
  - project
aliases:
  - $project_name
---

# $project_name
$body

## Activity
\`\`\`dataview
TABLE WITHOUT ID
  file.link AS "Note",
  type AS "Type",
  date AS "Date"
FROM ""
WHERE contains(string(project), "$project_name")
SORT date DESC
LIMIT 15
\`\`\`
EOF
            echo "    ✓ Projects/$project_name.md"
            PROJECTS_MIGRATED=$((PROJECTS_MIGRATED + 1))
            LINKS_CREATED=$((LINKS_CREATED + 1))
            TAGS_APPLIED=$((TAGS_APPLIED + 1))
        else
            echo "    · Projects/$project_name.md already exists, skipping"
        fi
    fi

    # ── decisions/ → Decisions/ ──
    if [ -d "$project_dir/decisions" ]; then
        for decision_file in "$project_dir"/decisions/*.md; do
            [ -f "$decision_file" ] || continue
            filename=$(basename "$decision_file")

            # Parse date and description from filename: YYYY-MM-DD_NNN_description.md
            file_date=$(echo "$filename" | grep -oE '^[0-9]{4}-[0-9]{2}-[0-9]{2}' || echo "$TODAY")
            description=$(echo "$filename" | sed 's/^[0-9_]*//; s/\.md$//; s/-/ /g; s/_/ /g' | xargs)
            [ -z "$description" ] && description=$(get_title "$decision_file")

            # Create readable title
            dest_name="$file_date $description.md"
            dest_path="$CLAUDE_ROOT/Decisions/$dest_name"

            if [ ! -f "$dest_path" ]; then
                title=$(get_title "$decision_file")
                [ "$title" = "Untitled" ] && title="$description"
                body=$(sed '1{/^# /d;}' "$decision_file")
                extra_tags=$(infer_tags "$decision_file")

                cat > "$dest_path" << EOF
---
type: decision
project: "[[Claude/Projects/$project_name]]"
date: $file_date
status: decided
category: implementation
tags:
  - decision
$(format_tags "$extra_tags")
aliases: []
---

# $title
$body

## Related
- [[Claude/Projects/$project_name]]
EOF
                echo "    ✓ Decisions/$dest_name"
                DECISIONS_MIGRATED=$((DECISIONS_MIGRATED + 1))
                LINKS_CREATED=$((LINKS_CREATED + 2))
            fi
        done
    fi

    # ── analysis/ → Analysis/ ──
    if [ -d "$project_dir/analysis" ]; then
        for analysis_file in "$project_dir"/analysis/*.md; do
            [ -f "$analysis_file" ] || continue
            filename=$(basename "$analysis_file" .md)

            # Convert path_to_file to readable name
            readable=$(echo "$filename" | sed 's/_/ /g; s/  */ /g' | xargs)
            file_date=$(stat -f "%Sm" -t "%Y-%m-%d" "$analysis_file" 2>/dev/null || echo "$TODAY")

            dest_name="$readable.md"
            dest_path="$CLAUDE_ROOT/Analysis/$dest_name"

            if [ ! -f "$dest_path" ]; then
                title=$(get_title "$analysis_file")
                [ "$title" = "Untitled" ] && title="Analysis: $readable"
                body=$(sed '1{/^# /d;}' "$analysis_file")
                extra_tags=$(infer_tags "$analysis_file")

                # Try to extract original path
                orig_path=$(grep -m1 "^\*\*Path\*\*:" "$analysis_file" 2>/dev/null | sed 's/.*: *//' || true)

                cat > "$dest_path" << EOF
---
type: analysis
project: "[[Claude/Projects/$project_name]]"
date: $file_date
path: $orig_path
component: $readable
tags:
  - analysis
$(format_tags "$extra_tags")
---

# $title
$body

## Related
- [[Claude/Projects/$project_name]]
EOF
                echo "    ✓ Analysis/$dest_name"
                ANALYSES_MIGRATED=$((ANALYSES_MIGRATED + 1))
                LINKS_CREATED=$((LINKS_CREATED + 2))
            fi
        done
    fi

    # ── context/current-task.md → Sessions/ ──
    if [ -f "$project_dir/context/current-task.md" ]; then
        session_date=$(stat -f "%Sm" -t "%Y-%m-%d" "$project_dir/context/current-task.md" 2>/dev/null || echo "$TODAY")
        dest_path="$CLAUDE_ROOT/Sessions/$session_date $project_name.md"

        if [ ! -f "$dest_path" ]; then
            task_content=$(cat "$project_dir/context/current-task.md" 2>/dev/null || true)
            blocker_content=""
            if [ -f "$project_dir/context/blockers.md" ]; then
                blocker_content=$(cat "$project_dir/context/blockers.md" 2>/dev/null || true)
            fi

            # Try to get branch from session.json
            branch=""
            if [ -f "$project_dir/_session.json" ]; then
                branch=$(jq -r '.branch // ""' "$project_dir/_session.json" 2>/dev/null) || true
            fi

            cat > "$dest_path" << EOF
---
type: session
project: "[[Claude/Projects/$project_name]]"
date: $session_date
branch: $branch
status: completed
tags:
  - session
---

# Session: $project_name ($session_date)

## Current Task
$task_content

## Blockers
${blocker_content:-None.}

## Key Context for Recovery
Migrated from v1.x memory files on $TODAY.

## Related
- [[Claude/Projects/$project_name]]
EOF
            echo "    ✓ Sessions/$session_date $project_name.md"
            SESSIONS_CREATED=$((SESSIONS_CREATED + 1))
            LINKS_CREATED=$((LINKS_CREATED + 2))
            TAGS_APPLIED=$((TAGS_APPLIED + 1))
        fi
    fi

    # ── progress/ → Progress/{name}.md ──
    if [ -f "$project_dir/progress/active.md" ] || [ -f "$project_dir/progress/completed.md" ]; then
        dest_path="$CLAUDE_ROOT/Progress/$project_name.md"

        if [ ! -f "$dest_path" ]; then
            active_content=""
            completed_content=""
            if [ -f "$project_dir/progress/active.md" ]; then
                active_content=$(cat "$project_dir/progress/active.md" 2>/dev/null || true)
            fi
            if [ -f "$project_dir/progress/completed.md" ]; then
                completed_content=$(cat "$project_dir/progress/completed.md" 2>/dev/null || true)
            fi

            cat > "$dest_path" << EOF
---
type: progress
project: "[[Claude/Projects/$project_name]]"
updated: $TODAY
tags:
  - progress
---

# $project_name --- Progress

## Active Work
${active_content:-No active items.}

## Completed
${completed_content:-No completed items recorded.}

## Related
- [[Claude/Projects/$project_name]]
EOF
            echo "    ✓ Progress/$project_name.md"
            PROGRESS_CREATED=$((PROGRESS_CREATED + 1))
            LINKS_CREATED=$((LINKS_CREATED + 2))
            TAGS_APPLIED=$((TAGS_APPLIED + 1))
        fi
    fi

    # ── subagent/ → Sub-Agents/ ──
    if [ -d "$project_dir/subagent" ]; then
        for sa_file in "$project_dir"/subagent/*.md; do
            [ -f "$sa_file" ] || continue
            filename=$(basename "$sa_file" .md)

            # Parse: YYYY-MM-DD_HHMMSS_taskname_XXXX
            sa_date=$(echo "$filename" | grep -oE '^[0-9]{4}-[0-9]{2}-[0-9]{2}' || echo "$TODAY")
            sa_time=$(echo "$filename" | grep -oE '[0-9]{6}' | head -1 || echo "000000")
            sa_task=$(echo "$filename" | sed 's/^[0-9_]*//; s/_[a-f0-9]*$//; s/_/ /g' | xargs)
            [ -z "$sa_task" ] && sa_task="Sub-agent task"

            dest_name="$sa_date ${sa_time} $sa_task.md"
            dest_path="$CLAUDE_ROOT/Sub-Agents/$dest_name"

            if [ ! -f "$dest_path" ]; then
                title=$(get_title "$sa_file")
                [ "$title" = "Untitled" ] && title="$sa_task"
                body=$(sed '1{/^# /d;}' "$sa_file")

                # Try to extract agent type
                agent_type=$(grep -m1 "^\*\*Agent\*\*:" "$sa_file" 2>/dev/null | sed 's/.*: *//' || echo "unknown")

                cat > "$dest_path" << EOF
---
type: subagent
project: "[[Claude/Projects/$project_name]]"
date: ${sa_date}T${sa_time:0:2}:${sa_time:2:2}:${sa_time:4:2}Z
agent: $agent_type
task: $sa_task
tags:
  - subagent
---

# $title
$body

## Related
- [[Claude/Projects/$project_name]]
EOF
                echo "    ✓ Sub-Agents/$dest_name"
                SUBAGENTS_MIGRATED=$((SUBAGENTS_MIGRATED + 1))
                LINKS_CREATED=$((LINKS_CREATED + 2))
                TAGS_APPLIED=$((TAGS_APPLIED + 1))
            fi
        done
    fi

    # ── _session.json → .claude-state/{key}/session.json ──
    if [ -f "$project_dir/_session.json" ]; then
        cp "$project_dir/_session.json" "$CLAUDE_ROOT/.claude-state/$project_key/session.json"
        echo "    ✓ .claude-state/$project_key/session.json"
    fi

    # ── Generate recent.md (hot cache) ──
    recent_file="$CLAUDE_ROOT/.claude-state/$project_key/recent.md"
    cat > "$recent_file" << EOF
# Hot Cache: $project_name
Updated: $TIMESTAMP
Status: ACTIVE
Branch:

## Right Now
- **Doing**: Migrated from v1.x on $TODAY
- **Blocked by**: Nothing
- **Next**: Review migrated notes in Obsidian

## Recent Notes
| Note | Type | Updated | Why It Matters |
|------|------|---------|----------------|
EOF

    # Add entries for migrated files
    if [ -f "$CLAUDE_ROOT/Projects/$project_name.md" ]; then
        echo "| Projects/$project_name.md | project | $TODAY | Project overview |" >> "$recent_file"
    fi
    if ls "$CLAUDE_ROOT/Sessions/"*"$project_name"* >/dev/null 2>&1; then
        echo "| Sessions/$TODAY $project_name.md | session | $TODAY | Latest session |" >> "$recent_file"
    fi
    if [ -f "$CLAUDE_ROOT/Progress/$project_name.md" ]; then
        echo "| Progress/$project_name.md | progress | $TODAY | Work tracking |" >> "$recent_file"
    fi

    cat >> "$recent_file" << EOF

## Quick Links
- Project → Projects/$project_name.md
- Progress → Progress/$project_name.md

## Relationship Context
(Migrated from v1.x — relationship context will build over future sessions)
EOF
    echo "    ✓ .claude-state/$project_key/recent.md"
    echo ""
done

# ─── Migrate User Profile ────────────────────────────────────────────

echo "── Migrating user profile..."

if [ -f "$CLAUDE_DIR/user/profile.md" ]; then
    # Try to extract name for the filename
    user_name=$(grep -m1 "^\- \*\*Name\*\*:" "$CLAUDE_DIR/user/profile.md" 2>/dev/null | sed 's/.*: *//' || true)
    if [ -z "$user_name" ] || [ "$user_name" = "" ]; then
        user_name="Your Name"
    fi

    dest_path="$CLAUDE_ROOT/People/$user_name.md"
    if [ ! -f "$dest_path" ] || [ "$user_name" = "Your Name" ]; then
        # Only overwrite "Your Name.md", not a real person note
        role=$(grep -m1 "^\- \*\*Role\*\*:" "$CLAUDE_DIR/user/profile.md" 2>/dev/null | sed 's/.*: *//' || true)
        company=$(grep -m1 "^\- \*\*Company\*\*:" "$CLAUDE_DIR/user/profile.md" 2>/dev/null | sed 's/.*: *//' || true)
        team=$(grep -m1 "^\- \*\*Team\*\*:" "$CLAUDE_DIR/user/profile.md" 2>/dev/null | sed 's/.*: *//' || true)
        body=$(sed '1{/^# /d;}' "$CLAUDE_DIR/user/profile.md")

        cat > "$dest_path" << EOF
---
type: person
role: $role
company: $company
team: $team
tags:
  - person
---

# $user_name
$body
EOF
        echo "  ✓ People/$user_name.md"
        # Remove the placeholder if we created a real one
        if [ "$user_name" != "Your Name" ] && [ -f "$CLAUDE_ROOT/People/Your Name.md" ]; then
            rm "$CLAUDE_ROOT/People/Your Name.md"
            echo "  ✓ Removed placeholder People/Your Name.md"
        fi
    fi
fi

if [ -f "$CLAUDE_DIR/user/preferences.md" ]; then
    dest_path="$CLAUDE_ROOT/People/_Preferences.md"
    prefs_body=$(cat "$CLAUDE_DIR/user/preferences.md")

    # Merge observations if they exist
    obs_content=""
    if [ -f "$CLAUDE_DIR/user/observations.md" ]; then
        obs_content=$(cat "$CLAUDE_DIR/user/observations.md")
    fi
    feedback_content=""
    if [ -f "$CLAUDE_DIR/user/feedback.md" ]; then
        feedback_content=$(cat "$CLAUDE_DIR/user/feedback.md")
    fi

    cat > "$dest_path" << EOF
---
type: preferences
updated: $TODAY
tags:
  - preferences
  - meta
---

$prefs_body
${obs_content:+

## Observations (migrated)
$obs_content}
${feedback_content:+

## Feedback (migrated)
$feedback_content}
EOF
    echo "  ✓ People/_Preferences.md"
fi

# ─── Migrate Workspace ───────────────────────────────────────────────

if [ -f "$CLAUDE_DIR/workspace.md" ]; then
    dest_path="$CLAUDE_ROOT/Workspace.md"
    if [ ! -f "$dest_path" ]; then
        body=$(cat "$CLAUDE_DIR/workspace.md")
        cat > "$dest_path" << EOF
---
type: workspace
updated: $TODAY
tags:
  - meta
  - workspace
---

$body
EOF
        echo "  ✓ Workspace.md"
    fi
fi

# ─── Install Dashboard & Templates ───────────────────────────────────

echo ""
echo "── Installing dashboard and templates..."

# Dashboard
if [ -f "$SCRIPT_DIR/obsidian-templates/_Dashboard.md" ]; then
    cp "$SCRIPT_DIR/obsidian-templates/_Dashboard.md" "$CLAUDE_ROOT/_Dashboard.md"
    echo "  ✓ _Dashboard.md"
fi

# Resource Index
if [ -f "$SCRIPT_DIR/obsidian-templates/_Resource Index.md" ]; then
    cp "$SCRIPT_DIR/obsidian-templates/_Resource Index.md" "$CLAUDE_ROOT/Resources/_Resource Index.md"
    echo "  ✓ Resources/_Resource Index.md"
fi

# Templates
mkdir -p "$CLAUDE_ROOT/_Templates"
for template in "$SCRIPT_DIR"/obsidian-templates/{Decision,Analysis,"Session Log",Project,Progress,Resource,"Sub-Agent Output"}.md; do
    if [ -f "$template" ]; then
        filename=$(basename "$template")
        cp "$template" "$CLAUDE_ROOT/_Templates/$filename"
        echo "  ✓ _Templates/$filename"
    fi
done

# ─── Update Config ───────────────────────────────────────────────────

echo ""
echo "── Updating memory-config.json..."

# Make sure backend is set to obsidian
if [ -f "$CONFIG_FILE" ]; then
    jq '.backend = "obsidian"' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
    echo "  ✓ Backend set to: obsidian"
else
    VAULT_PATH_CONFIG="${VAULT_PATH/#$HOME/~}"
    cat > "$CONFIG_FILE" << EOF
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
    echo "  ✓ Created memory-config.json (backend: obsidian)"
fi

# ─── Report ──────────────────────────────────────────────────────────

echo ""
echo "=== Migration Complete ==="
echo ""
echo "Migrated from: $PROJECTS_DIR/"
echo "Migrated to:   $CLAUDE_ROOT/"
echo ""
echo "Projects:      $PROJECTS_MIGRATED migrated"
echo "Decisions:     $DECISIONS_MIGRATED converted"
echo "Analyses:      $ANALYSES_MIGRATED converted"
echo "Sessions:      $SESSIONS_CREATED created"
echo "Progress:      $PROGRESS_CREATED created"
echo "Sub-agents:    $SUBAGENTS_MIGRATED converted"
echo ""
echo "Vault stats:"
echo "  Wikilinks created: $LINKS_CREATED"
echo "  Tags applied:      $TAGS_APPLIED"
echo ""
echo "Original files preserved at $PROJECTS_DIR/"
echo "Backend updated to: obsidian"
echo ""
echo "Next: Open your vault in Obsidian to verify the migrated notes."
echo "      Install Dataview plugin for dashboard queries."
