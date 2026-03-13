#!/usr/bin/env bash
# =============================================================================
# setup-engine.sh — Interactive engine setup for mcgoats-game-template
# =============================================================================
# Configures the project template for a specific game engine.
#
# Usage: bash tools/setup-engine.sh <godot|unity|unreal>
#
# This script:
#   a) Copies engine-specific configs, hooks, CI workflows
#   b) For Godot: copies lint configs, CLAUDE.md templates, skills
#   c) Appends engine-specific .gitignore entries
#   d) Updates .github/template-config.json ENGINE field
#   e) Updates .claude/settings.json worktree.symlinkDirectories
#   f) Creates engine-specific directory scaffolding
#   g) Uncomments the engine's .gitignore section
#   h) Removes the engine/ directory entirely
#   i) Commits the result
# =============================================================================
set -euo pipefail

# ---------------------------------------------------------------------------
# Colors & output helpers
# ---------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; }
header()  { echo -e "\n${BOLD}${CYAN}=== $* ===${NC}\n"; }

# ---------------------------------------------------------------------------
# Usage
# ---------------------------------------------------------------------------
usage() {
    echo -e "${BOLD}Usage:${NC} bash tools/setup-engine.sh <engine>"
    echo ""
    echo "  Supported engines:"
    echo "    godot   — Godot 4 (GDScript) with CI, linting, testing, skills"
    echo "    unity   — Unity (C#) with basic CI stubs and MCP integration"
    echo "    unreal  — Unreal Engine (C++) with placeholder CI"
    echo ""
    echo "  Example:"
    echo "    bash tools/setup-engine.sh godot"
    exit 1
}

# ---------------------------------------------------------------------------
# Validate arguments
# ---------------------------------------------------------------------------
if [[ $# -lt 1 ]]; then
    error "Missing required argument: engine name"
    echo ""
    usage
fi

ENGINE="$1"
VALID_ENGINES=("godot" "unity" "unreal")

if [[ ! " ${VALID_ENGINES[*]} " =~ " ${ENGINE} " ]]; then
    error "Invalid engine: '${ENGINE}'"
    echo "Valid engines: ${VALID_ENGINES[*]}"
    echo ""
    usage
fi

# ---------------------------------------------------------------------------
# Locate project root (this script lives in tools/)
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENGINE_DIR="${PROJECT_ROOT}/engine/${ENGINE}"

if [[ ! -d "$ENGINE_DIR" ]]; then
    error "Engine directory not found: engine/${ENGINE}/"
    error "Has this template already been initialized?"
    exit 1
fi

header "Setting up project for ${ENGINE^} engine"

# ---------------------------------------------------------------------------
# Helper: copy file if source exists, creating parent dirs as needed
# ---------------------------------------------------------------------------
copy_if_exists() {
    local src="$1"
    local dst="$2"
    if [[ -f "$src" ]]; then
        mkdir -p "$(dirname "$dst")"
        cp "$src" "$dst"
        success "Copied $(basename "$src") -> ${dst#"$PROJECT_ROOT"/}"
    else
        warn "Source not found, skipping: ${src#"$PROJECT_ROOT"/}"
    fi
}

# =============================================================================
# Step a) Copy engine-specific files
# =============================================================================
copy_engine_files() {
    # --- .mcp.json → root ---
    header "MCP Configuration"
    copy_if_exists "${ENGINE_DIR}/.mcp.json" "${PROJECT_ROOT}/.mcp.json"

    # --- justfile.engine → root ---
    header "Justfile Engine Recipes"
    copy_if_exists "${ENGINE_DIR}/justfile.engine" "${PROJECT_ROOT}/justfile.engine"

    # --- Hooks → .claude/hooks/ and .githooks/ ---
    header "Git & Claude Hooks"

    if [[ -d "${ENGINE_DIR}/hooks" ]]; then
        for hook_file in "${ENGINE_DIR}/hooks/"*-engine.sh; do
            [[ -f "$hook_file" ]] || continue
            local basename
            basename="$(basename "$hook_file")"

            # All engine hooks go to .claude/hooks/
            if [[ -d "${PROJECT_ROOT}/.claude/hooks" ]]; then
                cp "$hook_file" "${PROJECT_ROOT}/.claude/hooks/${basename}"
                chmod +x "${PROJECT_ROOT}/.claude/hooks/${basename}"
                success "Copied ${basename} -> .claude/hooks/"
            fi

            # pre-commit hooks also go to .githooks/
            if [[ -d "${PROJECT_ROOT}/.githooks" && "$basename" == pre-commit* ]]; then
                cp "$hook_file" "${PROJECT_ROOT}/.githooks/${basename}"
                chmod +x "${PROJECT_ROOT}/.githooks/${basename}"
                success "Copied ${basename} -> .githooks/"
            fi
        done
    else
        warn "No hooks/ directory in engine/${ENGINE}/ — skipping"
    fi

    # --- Commands → .claude/commands/ ---
    header "Claude Commands"
    if [[ -d "${ENGINE_DIR}/commands" ]]; then
        mkdir -p "${PROJECT_ROOT}/.claude/commands"
        # Copy each command subdirectory (e.g. editor/, dev/)
        for cmd_dir in "${ENGINE_DIR}/commands/"*/; do
            [[ -d "$cmd_dir" ]] || continue
            local dir_basename
            dir_basename="$(basename "$cmd_dir")"
            mkdir -p "${PROJECT_ROOT}/.claude/commands/${dir_basename}"
            for cmd_file in "${cmd_dir}"*.md; do
                [[ -f "$cmd_file" ]] || continue
                cp "$cmd_file" "${PROJECT_ROOT}/.claude/commands/${dir_basename}/"
                success "Copied $(basename "$cmd_file") -> .claude/commands/${dir_basename}/"
            done
        done
    else
        info "No commands/ directory in engine/${ENGINE}/ — skipping"
    fi

    # --- CI workflows → .github/workflows/ ---
    header "CI Workflows"
    if [[ -d "${ENGINE_DIR}/ci" ]]; then
        mkdir -p "${PROJECT_ROOT}/.github/workflows"
        for workflow in "${ENGINE_DIR}/ci/"*.yml; do
            [[ -f "$workflow" ]] || continue
            copy_if_exists "$workflow" "${PROJECT_ROOT}/.github/workflows/$(basename "$workflow")"
        done
    else
        warn "No ci/ directory in engine/${ENGINE}/ — skipping"
    fi
}

# =============================================================================
# Step b) Godot extras: lint configs, CLAUDE.md templates, skills
# =============================================================================
copy_godot_extras() {
    header "Godot-Specific Extras"

    # --- gdlintrc, gdformatrc → root ---
    copy_if_exists "${ENGINE_DIR}/gdlintrc" "${PROJECT_ROOT}/gdlintrc"
    copy_if_exists "${ENGINE_DIR}/gdformatrc" "${PROJECT_ROOT}/gdformatrc"

    # --- claude-md/ templates (e.g. scripts-CLAUDE.md → scripts/CLAUDE.md) ---
    if [[ -d "${ENGINE_DIR}/claude-md" ]]; then
        for template in "${ENGINE_DIR}/claude-md"/*; do
            [[ -f "$template" ]] || continue
            local basename_tpl
            basename_tpl="$(basename "$template")"
            # Extract target dir: "scripts-CLAUDE.md" → "scripts"
            local dir_name="${basename_tpl%-CLAUDE.md}"
            local target_dir="${PROJECT_ROOT}/${dir_name}"
            if [[ -d "$target_dir" ]]; then
                cp "$template" "${target_dir}/CLAUDE.md"
                success "Copied CLAUDE.md template to ${dir_name}/"
            else
                mkdir -p "$target_dir"
                cp "$template" "${target_dir}/CLAUDE.md"
                success "Created ${dir_name}/ with CLAUDE.md template"
            fi
        done
    fi

    # --- skills/ → .agents/skills/ ---
    if [[ -d "${ENGINE_DIR}/skills" ]]; then
        mkdir -p "${PROJECT_ROOT}/.agents/skills"
        # Only copy if there are actual entries
        if compgen -G "${ENGINE_DIR}/skills/*" > /dev/null 2>&1; then
            cp -r "${ENGINE_DIR}/skills/"* "${PROJECT_ROOT}/.agents/skills/"
            success "Copied engine skills to .agents/skills/"
        else
            info "No skills to copy (engine/godot/skills/ is empty)"
        fi
    fi

    # --- Engine-specific SETUP.md ---
    copy_if_exists "${ENGINE_DIR}/SETUP.md" "${PROJECT_ROOT}/ENGINE-SETUP.md"
}

# =============================================================================
# Step c) Append engine-specific .gitignore entries
# =============================================================================
append_gitignore_entries() {
    header "Gitignore Append"
    local append_file="${ENGINE_DIR}/.gitignore.append"
    if [[ -f "$append_file" ]]; then
        {
            echo ""
            echo "# --- ${ENGINE^} engine (added by setup-engine.sh) ---"
            cat "$append_file"
        } >> "${PROJECT_ROOT}/.gitignore"
        success "Appended ${ENGINE} entries to .gitignore"
    else
        info "No .gitignore.append found — skipping"
    fi
}

# =============================================================================
# Step d) Update template-config.json ENGINE field
# =============================================================================
update_template_config() {
    header "Template Config"
    local config="${PROJECT_ROOT}/.github/template-config.json"
    if [[ ! -f "$config" ]]; then
        warn "template-config.json not found — skipping"
        return
    fi

    if command -v jq &>/dev/null; then
        jq --arg engine "$ENGINE" '.ENGINE = $engine' "$config" > "${config}.tmp"
        mv "${config}.tmp" "$config"
        success "Set ENGINE=${ENGINE} in template-config.json"
    else
        # Fallback: sed-based replacement
        sed -i "s/\"ENGINE\": \"[^\"]*\"/\"ENGINE\": \"${ENGINE}\"/" "$config"
        success "Set ENGINE=${ENGINE} in template-config.json (sed fallback)"
    fi
}

# =============================================================================
# Step e) Update .claude/settings.json worktree.symlinkDirectories
# =============================================================================
update_settings_json() {
    header "Claude Settings"
    local settings="${PROJECT_ROOT}/.claude/settings.json"
    if [[ ! -f "$settings" ]]; then
        warn ".claude/settings.json not found — skipping"
        return
    fi

    local symlink_dirs
    case "$ENGINE" in
        godot)  symlink_dirs='[".venv", ".godot/imported"]' ;;
        unity)  symlink_dirs='[".venv", "Library"]' ;;
        unreal) symlink_dirs='[".venv", "Intermediate", "DerivedDataCache"]' ;;
    esac

    if command -v jq &>/dev/null; then
        jq --argjson dirs "$symlink_dirs" '.worktree.symlinkDirectories = $dirs' "$settings" > "${settings}.tmp"
        mv "${settings}.tmp" "$settings"
        success "Updated worktree.symlinkDirectories for ${ENGINE}"
    else
        # Fallback: sed-based replacement
        sed -i "s|\"symlinkDirectories\": \[.*\]|\"symlinkDirectories\": ${symlink_dirs}|" "$settings"
        success "Updated worktree.symlinkDirectories for ${ENGINE} (sed fallback)"
    fi
}

# =============================================================================
# Step f) Engine-specific directory scaffolding
# =============================================================================
create_engine_scaffolding() {
    header "Engine Scaffolding"
    case "$ENGINE" in
        godot)
            info "No extra scaffolding needed for Godot (open project in editor to generate .godot/)"
            ;;
        unity)
            mkdir -p "${PROJECT_ROOT}/Assets" "${PROJECT_ROOT}/ProjectSettings" "${PROJECT_ROOT}/Packages"
            success "Created Assets/, ProjectSettings/, Packages/"
            copy_if_exists "${ENGINE_DIR}/SETUP.md" "${PROJECT_ROOT}/ENGINE-SETUP.md"
            ;;
        unreal)
            mkdir -p "${PROJECT_ROOT}/Source" "${PROJECT_ROOT}/Config" "${PROJECT_ROOT}/Content"
            success "Created Source/, Config/, Content/"
            copy_if_exists "${ENGINE_DIR}/SETUP.md" "${PROJECT_ROOT}/ENGINE-SETUP.md"
            ;;
    esac
}

# =============================================================================
# Step g) Uncomment the engine's section in .gitignore
# =============================================================================
uncomment_gitignore_section() {
    header "Uncomment .gitignore Section"

    local section_label
    case "$ENGINE" in
        godot)  section_label="Godot" ;;
        unity)  section_label="Unity" ;;
        unreal) section_label="Unreal" ;;
    esac

    local gitignore="${PROJECT_ROOT}/.gitignore"
    local tmpfile
    tmpfile="$(mktemp)"
    local in_section=false

    while IFS= read -r line || [[ -n "$line" ]]; do
        # Detect the start of our target section
        if [[ "$line" == *"=== ${section_label} "* ]]; then
            in_section=true
            echo "$line" >> "$tmpfile"
            continue
        fi
        # Detect the start of a different section (stop uncommenting)
        if $in_section && [[ "$line" == "# ="* ]]; then
            in_section=false
        fi
        # Uncomment lines in our section: "# .godot/" → ".godot/"
        if $in_section && [[ "$line" =~ ^#\ (.+)$ ]]; then
            echo "${BASH_REMATCH[1]}" >> "$tmpfile"
        else
            echo "$line" >> "$tmpfile"
        fi
    done < "$gitignore"

    mv "$tmpfile" "$gitignore"
    success "Uncommented ${section_label} section in .gitignore"
}

# =============================================================================
# Step h) Remove the engine/ directory entirely
# =============================================================================
remove_engine_directory() {
    header "Cleanup"
    if [[ -d "${PROJECT_ROOT}/engine" ]]; then
        rm -rf "${PROJECT_ROOT}/engine"
        success "Removed engine/ directory"
    else
        warn "engine/ directory already removed"
    fi
}

# =============================================================================
# Step i) Git commit
# =============================================================================
git_commit() {
    header "Git Commit"
    cd "$PROJECT_ROOT"
    git add -A
    if git diff --cached --quiet; then
        warn "Nothing to commit (perhaps already initialized?)"
    else
        git commit -m "chore: initialize project for ${ENGINE}"
        success "Committed: chore: initialize project for ${ENGINE}"
    fi
}

# =============================================================================
# Summary
# =============================================================================
print_summary() {
    echo ""
    echo -e "${GREEN}${BOLD}================================================================${NC}"
    echo -e "${GREEN}${BOLD}  Engine setup complete: ${ENGINE^}${NC}"
    echo -e "${GREEN}${BOLD}================================================================${NC}"
    echo ""
    echo -e "${BOLD}What was done:${NC}"
    echo "  - Copied .mcp.json, justfile.engine, hooks, commands, and CI workflows"
    case "$ENGINE" in
        godot)
            echo "  - Copied gdlintrc, gdformatrc, CLAUDE.md templates, and skills"
            ;;
        unity)
            echo "  - Created Assets/, ProjectSettings/, Packages/"
            ;;
        unreal)
            echo "  - Created Source/, Config/, Content/"
            ;;
    esac
    echo "  - Appended engine-specific .gitignore entries"
    echo "  - Uncommented ${ENGINE^} section in .gitignore"
    echo "  - Set ENGINE=${ENGINE} in .github/template-config.json"
    echo "  - Updated worktree.symlinkDirectories in .claude/settings.json"
    echo "  - Removed engine/ directory"
    echo "  - Created git commit"
    echo ""
    echo -e "${BOLD}Next steps:${NC}"
    echo "  1. Read SETUP.md for full setup instructions"
    echo "  2. Configure GitHub branch protection and MERGE_TOKEN secret"
    echo "  3. Run:  uv sync"
    echo "  4. Run:  git config core.hooksPath .githooks"
    case "$ENGINE" in
        godot)
            echo "  5. Install gdtoolkit:  uv add --dev 'gdtoolkit>=4.5'"
            echo "  6. Open in Godot:      godot --editor"
            ;;
        unity)
            echo "  5. Open in Unity Hub and select this project directory"
            ;;
        unreal)
            echo "  5. Create a .uproject file and open in Unreal Editor"
            ;;
    esac
    echo "  - Start building:  just worktree-create first-feature"
    echo ""
    echo -e "${GREEN}Happy game dev!${NC}"
}

# =============================================================================
# Main execution — run all steps in order
# =============================================================================
copy_engine_files
[[ "$ENGINE" == "godot" ]] && copy_godot_extras
append_gitignore_entries
update_template_config
update_settings_json
create_engine_scaffolding
uncomment_gitignore_section
remove_engine_directory
git_commit
print_summary
