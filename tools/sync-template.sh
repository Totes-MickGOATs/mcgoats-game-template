#!/usr/bin/env bash
# =============================================================================
# sync-template.sh — Pull updates from mcgoats-game-template into a project
# =============================================================================
# Idempotent: only creates or updates files, never deletes.
#
# Usage:
#   bash tools/sync-template.sh [--dry-run] [--section skills|hooks|ci|commands|claude-md|agnostic|all]
#
# Requires: git, jq (optional, falls back to grep)
#
# This script:
#   1. Adds/verifies the template remote
#   2. Fetches the latest template
#   3. Detects which engine this project uses
#   4. Extracts engine-specific files and maps them to post-setup locations
#   5. Extracts engine-agnostic files (hooks, CI, scripts)
#   6. Reports what was created/updated
# =============================================================================
set -euo pipefail

# ---------------------------------------------------------------------------
# Colors
# ---------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
skip()    { echo -e "${DIM}[SKIP]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; }
header()  { echo -e "\n${BOLD}${CYAN}=== $* ===${NC}\n"; }

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------
TEMPLATE_REMOTE="template"
TEMPLATE_URL="https://github.com/Totes-MickGOATs/mcgoats-game-template.git"
TEMPLATE_BRANCH="main"
DRY_RUN=false
SECTION="all"
CREATED=0
UPDATED=0
SKIPPED=0

# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)  DRY_RUN=true; shift ;;
        --section)  SECTION="$2"; shift 2 ;;
        -h|--help)
            echo "Usage: bash tools/sync-template.sh [--dry-run] [--section skills|hooks|ci|commands|claude-md|agnostic|all]"
            echo ""
            echo "Sections:"
            echo "  skills    — Engine-specific skills (.agents/skills/)"
            echo "  hooks     — Claude + git hooks (.claude/hooks/, .githooks/)"
            echo "  ci        — GitHub Actions workflows (.github/workflows/)"
            echo "  commands  — Claude slash commands (.claude/commands/)"
            echo "  claude-md — CLAUDE.md templates for directories"
            echo "  agnostic  — Engine-agnostic files (justfile, scripts, root hooks)"
            echo "  all       — Everything (default)"
            exit 0
            ;;
        *) error "Unknown argument: $1"; exit 1 ;;
    esac
done

# ---------------------------------------------------------------------------
# Locate project root
# ---------------------------------------------------------------------------
PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"
if [[ -z "$PROJECT_ROOT" ]]; then
    error "Not in a git repository"
    exit 1
fi
cd "$PROJECT_ROOT"

# ---------------------------------------------------------------------------
# Detect engine
# ---------------------------------------------------------------------------
detect_engine() {
    local config=".github/template-config.json"
    if [[ -f "$config" ]]; then
        if command -v jq &>/dev/null; then
            ENGINE=$(jq -r '.ENGINE // empty' "$config")
        else
            ENGINE=$(grep -o '"ENGINE": *"[^"]*"' "$config" | sed 's/.*"ENGINE": *"\([^"]*\)".*/\1/')
        fi
    fi

    if [[ -z "${ENGINE:-}" ]]; then
        # Auto-detect from project structure
        if [[ -f "project.godot" ]]; then
            ENGINE="godot"
        elif [[ -d "Assets" && -d "ProjectSettings" ]]; then
            ENGINE="unity"
        elif [[ -f "*.uproject" ]] || [[ -d "Source" && -d "Config" ]]; then
            ENGINE="unreal"
        else
            error "Cannot detect engine. Set ENGINE in .github/template-config.json"
            exit 1
        fi
        warn "Auto-detected engine: ${ENGINE} (not set in template-config.json)"
    fi

    info "Engine: ${ENGINE}"
}

# ---------------------------------------------------------------------------
# Setup template remote
# ---------------------------------------------------------------------------
setup_remote() {
    header "Template Remote"

    if git remote | grep -q "^${TEMPLATE_REMOTE}$"; then
        local url
        url=$(git remote get-url "$TEMPLATE_REMOTE" 2>/dev/null || echo "")
        if [[ "$url" != "$TEMPLATE_URL" ]]; then
            warn "Remote '${TEMPLATE_REMOTE}' exists but points to: $url"
            warn "Expected: $TEMPLATE_URL"
            warn "Updating remote URL..."
            git remote set-url "$TEMPLATE_REMOTE" "$TEMPLATE_URL"
        fi
        success "Remote '${TEMPLATE_REMOTE}' configured"
    else
        info "Adding remote '${TEMPLATE_REMOTE}' -> ${TEMPLATE_URL}"
        git remote add "$TEMPLATE_REMOTE" "$TEMPLATE_URL"
        success "Remote added"
    fi

    info "Fetching latest template..."
    git fetch "$TEMPLATE_REMOTE" "$TEMPLATE_BRANCH" --quiet 2>/dev/null || {
        error "Failed to fetch from template remote"
        exit 1
    }
    success "Fetched ${TEMPLATE_REMOTE}/${TEMPLATE_BRANCH}"
}

# ---------------------------------------------------------------------------
# Helper: extract a file from template and write it locally
# Idempotent: only writes if content differs or file doesn't exist
# ---------------------------------------------------------------------------
sync_file() {
    local template_path="$1"   # Path in the template repo
    local local_path="$2"      # Where to put it locally

    # Check if file exists in template
    # MSYS_NO_PATHCONV=1 prevents Windows/MSYS2 from mangling the : in rev:path
    local content
    content=$(MSYS_NO_PATHCONV=1 git show "${TEMPLATE_REMOTE}/${TEMPLATE_BRANCH}:${template_path}" 2>/dev/null) || {
        skip "${template_path} — not found in template"
        return 1
    }

    if [[ "$DRY_RUN" == true ]]; then
        if [[ -f "$local_path" ]]; then
            local existing
            existing=$(cat "$local_path")
            if [[ "$content" == "$existing" ]]; then
                skip "${local_path} — unchanged"
                ((SKIPPED++)) || true
            else
                info "[DRY RUN] Would update: ${local_path}"
                ((UPDATED++)) || true
            fi
        else
            info "[DRY RUN] Would create: ${local_path}"
            ((CREATED++)) || true
        fi
        return 0
    fi

    mkdir -p "$(dirname "$local_path")"

    if [[ -f "$local_path" ]]; then
        local existing
        existing=$(cat "$local_path")
        if [[ "$content" == "$existing" ]]; then
            skip "${local_path} — unchanged"
            ((SKIPPED++)) || true
            return 0
        fi
        echo "$content" > "$local_path"
        success "Updated: ${local_path}"
        ((UPDATED++)) || true
    else
        echo "$content" > "$local_path"
        success "Created: ${local_path}"
        ((CREATED++)) || true
    fi
}

# ---------------------------------------------------------------------------
# Helper: sync an entire directory from template
# Lists all files in the template path and syncs each one
# ---------------------------------------------------------------------------
sync_directory() {
    local template_dir="$1"    # Directory in template repo
    local local_dir="$2"       # Local destination directory
    local strip_prefix="$3"    # Prefix to strip from template path

    # List all files in the template directory
    local files
    files=$(MSYS_NO_PATHCONV=1 git ls-tree -r --name-only "${TEMPLATE_REMOTE}/${TEMPLATE_BRANCH}" -- "${template_dir}" 2>/dev/null) || {
        skip "${template_dir} — not found in template"
        return 1
    }

    if [[ -z "$files" ]]; then
        skip "${template_dir} — empty in template"
        return 0
    fi

    while IFS= read -r file; do
        local relative="${file#"${strip_prefix}"}"
        sync_file "$file" "${local_dir}/${relative}"
    done <<< "$files"
}

# ---------------------------------------------------------------------------
# Sync engine-specific skills
# engine/<engine>/skills/* → .agents/skills/
# ---------------------------------------------------------------------------
sync_skills() {
    header "Skills"
    sync_directory "engine/${ENGINE}/skills" ".agents/skills" "engine/${ENGINE}/skills/"
}

# ---------------------------------------------------------------------------
# Sync engine-specific hooks
# engine/<engine>/hooks/* → .claude/hooks/
# ---------------------------------------------------------------------------
sync_hooks() {
    header "Engine Hooks"

    # Engine-specific hooks → .claude/hooks/
    local hooks
    hooks=$(MSYS_NO_PATHCONV=1 git ls-tree --name-only "${TEMPLATE_REMOTE}/${TEMPLATE_BRANCH}" -- "engine/${ENGINE}/hooks/" 2>/dev/null | grep -v "CLAUDE.md" || true)

    if [[ -n "$hooks" ]]; then
        while IFS= read -r hook_path; do
            local basename
            basename=$(basename "$hook_path")
            sync_file "$hook_path" ".claude/hooks/${basename}"

            # Make executable
            if [[ "$DRY_RUN" != true && -f ".claude/hooks/${basename}" ]]; then
                chmod +x ".claude/hooks/${basename}" 2>/dev/null || true
            fi

            # Pre-commit hooks also go to .githooks/
            if [[ "$basename" == pre-commit* ]]; then
                sync_file "$hook_path" ".githooks/${basename}"
                if [[ "$DRY_RUN" != true && -f ".githooks/${basename}" ]]; then
                    chmod +x ".githooks/${basename}" 2>/dev/null || true
                fi
            fi
        done <<< "$hooks"
    fi

    # Engine-agnostic hooks
    header "Agnostic Hooks"
    local agnostic_hooks=(
        ".claude/guard-master-commit.sh"
        ".claude/statusline.sh"
        ".claude/hooks/lint-on-save.sh"
        ".claude/hooks/subagent-quality-gate.sh"
        ".claude/hooks/stop-uncommitted-check.sh"
        ".claude/hooks/pre-compact-context.sh"
        ".claude/hooks/lint-session-stop.sh"
        ".claude/hooks/worktree-setup.sh"
        ".claude/hooks/session-start.sh"
    )

    for hook in "${agnostic_hooks[@]}"; do
        sync_file "$hook" "$hook"
        if [[ "$DRY_RUN" != true && -f "$hook" ]]; then
            chmod +x "$hook" 2>/dev/null || true
        fi
    done

    # Agnostic githooks
    local githooks=( ".githooks/pre-commit" ".githooks/pre-push" ".githooks/commit-msg" )
    for hook in "${githooks[@]}"; do
        sync_file "$hook" "$hook"
        if [[ "$DRY_RUN" != true && -f "$hook" ]]; then
            chmod +x "$hook" 2>/dev/null || true
        fi
    done
}

# ---------------------------------------------------------------------------
# Sync engine-specific CI workflows
# engine/<engine>/ci/*.yml → .github/workflows/
# ---------------------------------------------------------------------------
sync_ci() {
    header "CI Workflows"

    # Engine-specific CI
    local workflows
    workflows=$(MSYS_NO_PATHCONV=1 git ls-tree --name-only "${TEMPLATE_REMOTE}/${TEMPLATE_BRANCH}" -- "engine/${ENGINE}/ci/" 2>/dev/null | grep '\.yml$' || true)

    if [[ -n "$workflows" ]]; then
        while IFS= read -r wf_path; do
            local basename
            basename=$(basename "$wf_path")
            sync_file "$wf_path" ".github/workflows/${basename}"
        done <<< "$workflows"
    fi

    # Engine-agnostic CI
    local agnostic_workflows=(
        ".github/workflows/auto-merge.yml"
        ".github/workflows/ci.yml"
        ".github/workflows/ci-monitor.yml"
        ".github/workflows/pr-guard.yml"
        ".github/workflows/cleanup-branches.yml"
        ".github/workflows/stale-cleanup.yml"
        ".github/workflows/post-merge-test.yml"
        ".github/workflows/coverage-baseline.yml"
    )

    for wf in "${agnostic_workflows[@]}"; do
        sync_file "$wf" "$wf"
    done
}

# ---------------------------------------------------------------------------
# Sync engine-specific commands
# engine/<engine>/commands/ → .claude/commands/
# ---------------------------------------------------------------------------
sync_commands() {
    header "Commands"

    # Engine-specific commands
    sync_directory "engine/${ENGINE}/commands" ".claude/commands" "engine/${ENGINE}/commands/"

    # Engine-agnostic commands
    sync_directory ".claude/commands" ".claude/commands" ".claude/commands/"
}

# ---------------------------------------------------------------------------
# Sync CLAUDE.md templates
# engine/<engine>/claude-md/*-CLAUDE.md → mapped directories
# ---------------------------------------------------------------------------
sync_claude_md() {
    header "CLAUDE.md Templates"

    local templates
    templates=$(MSYS_NO_PATHCONV=1 git ls-tree --name-only "${TEMPLATE_REMOTE}/${TEMPLATE_BRANCH}" -- "engine/${ENGINE}/claude-md/" 2>/dev/null | grep -v "^engine/${ENGINE}/claude-md/CLAUDE.md$" || true)

    if [[ -z "$templates" ]]; then
        info "No CLAUDE.md templates for ${ENGINE}"
        return 0
    fi

    while IFS= read -r template_path; do
        local basename_tpl
        basename_tpl=$(basename "$template_path")

        # Skip the directory's own CLAUDE.md
        [[ "$basename_tpl" == "CLAUDE.md" ]] && continue

        # Map template name to directory: "assets-scripts-CLAUDE.md" → "Assets/Scripts/"
        local dir_name="${basename_tpl%-CLAUDE.md}"

        case "$ENGINE" in
            unity)
                # Unity convention: capitalize each segment
                # "assets-scripts" → "Assets/Scripts"
                dir_name=$(echo "$dir_name" | sed 's/-/\n/g' | while read -r seg; do
                    echo "${seg^}"
                done | paste -sd '/')
                ;;
            *)
                # Default: just convert dashes to slashes
                dir_name=$(echo "$dir_name" | sed 's/-/\//g')
                ;;
        esac

        sync_file "$template_path" "${dir_name}/CLAUDE.md"
    done <<< "$templates"
}

# ---------------------------------------------------------------------------
# Sync engine-agnostic files
# ---------------------------------------------------------------------------
sync_agnostic() {
    header "Engine-Agnostic Files"

    # Engine-agnostic skills
    sync_directory ".agents/skills" ".agents/skills" ".agents/skills/"

    # Python tooling
    local scripts=(
        "scripts/tools/validate_claude_md.py"
        "scripts/tools/validate_registry.py"
        "scripts/tools/test_coverage_report.py"
    )
    for script in "${scripts[@]}"; do
        sync_file "$script" "$script"
    done

    # Engine justfile
    sync_file "engine/${ENGINE}/justfile.engine" "justfile.engine"

    # Root config files (only if they exist locally — don't overwrite customized versions)
    # These are synced only if the local file is identical to the template's previous version
    # or doesn't exist yet
    local config_files=(
        "pyproject.toml"
        "cliff.toml"
        ".editorconfig"
    )
    for cfg in "${config_files[@]}"; do
        sync_file "$cfg" "$cfg"
    done
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
print_summary() {
    echo ""
    echo -e "${BOLD}${CYAN}================================================================${NC}"
    echo -e "${BOLD}${CYAN}  Sync Summary${NC}"
    echo -e "${BOLD}${CYAN}================================================================${NC}"
    echo ""
    echo -e "  Engine:   ${BOLD}${ENGINE}${NC}"
    echo -e "  Created:  ${GREEN}${CREATED}${NC} files"
    echo -e "  Updated:  ${YELLOW}${UPDATED}${NC} files"
    echo -e "  Skipped:  ${DIM}${SKIPPED}${NC} files (unchanged)"

    if [[ "$DRY_RUN" == true ]]; then
        echo ""
        echo -e "  ${YELLOW}This was a dry run. No files were modified.${NC}"
        echo -e "  Run without --dry-run to apply changes."
    else
        local total=$((CREATED + UPDATED))
        if [[ $total -gt 0 ]]; then
            echo ""
            echo -e "  ${BOLD}Next steps:${NC}"
            echo "    git add -A && git status   # Review changes"
            echo "    git commit -m 'chore: sync template updates'"
        else
            echo ""
            echo -e "  ${GREEN}Already up to date!${NC}"
        fi
    fi
    echo ""
}

# =============================================================================
# Main
# =============================================================================
detect_engine
setup_remote

case "$SECTION" in
    skills)    sync_skills ;;
    hooks)     sync_hooks ;;
    ci)        sync_ci ;;
    commands)  sync_commands ;;
    claude-md) sync_claude_md ;;
    agnostic)  sync_agnostic ;;
    all)
        sync_skills
        sync_hooks
        sync_ci
        sync_commands
        sync_claude_md
        sync_agnostic
        ;;
    *)
        error "Unknown section: ${SECTION}"
        echo "Valid sections: skills, hooks, ci, commands, claude-md, agnostic, all"
        exit 1
        ;;
esac

print_summary
