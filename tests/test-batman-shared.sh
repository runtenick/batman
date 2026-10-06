#!/bin/sh
set -eu
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")/../scripts" && pwd)
repo_dir=${script_dir%/*}
test_root=$(mktemp -d "${TMPDIR:-/tmp}/batman-shared-tests.XXXXXX")
trap 'rm -rf "$test_root"' EXIT HUP INT TERM
fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
contains() { case $output in *"$1"*) ;; *) fail "missing output: $1" ;; esac; }

# Fixtures use the old Codex/portable rendering formats and recorded baselines.
legacy_install() (
    legacy_root=$1
    legacy_name=$2
    legacy_kind=$3
    legacy_mode=$4
    . "$script_dir/lib/batman-management.sh"
    legacy_source=$(stable_skill_source "$legacy_name" 2>/dev/null || printf '%s\n' "$source_dir/experimental/$legacy_name")
    render_update_projection "$legacy_source" "$legacy_root/$legacy_name" "$legacy_kind" "$legacy_mode"
    state_set "$legacy_root/.batman/state.tsv" invocation "$legacy_name" "$legacy_mode"
    state_set "$legacy_root/.batman/state.tsv" source-hash "$legacy_name" "$(managed_hash "$legacy_source")"
    state_set "$legacy_root/.batman/state.tsv" installed-hash "$legacy_name" "$(managed_hash "$legacy_root/$legacy_name")"
)
run_case() {
    env BATMAN_SKILLS_DIR="$case_root/shared" \
        BATMAN_CODEX_SKILLS_DIR="$case_root/shared" \
        BATMAN_PORTABLE_SKILLS_DIR="$case_root/shared" \
        BATMAN_COPILOT_SKILLS_DIR="$case_root/copilot" \
        BATMAN_ARCHIVE_DIR="$case_root/archive" \
        XDG_CONFIG_HOME="$case_root/config" "$repo_dir/scripts/batman" "$@"
}
assert_policy() {
    grep -F "disable-model-invocation: $2" "$1/SKILL.md" >/dev/null || fail 'missing shared frontmatter policy'
    grep -F "allow_implicit_invocation: $3" "$1/agents/openai.yaml" >/dev/null || fail 'missing shared Codex policy'
}

printf '%s\n' 'Testing portable-only migration with local edits and experimental copies...'
case_root="$test_root/portable-only"
legacy_install "$case_root/copilot" unslop portable automatic
printf '%s\n' 'preserved local edit' >> "$case_root/copilot/unslop/SKILL.md"
legacy_install "$case_root/copilot" prototype portable manual
output=$(run_case sync --group communication 2>&1)
contains 'local changes preserved'
contains 'previous copy archived'
[ ! -e "$case_root/copilot/unslop" ] || fail 'legacy skill still shadows shared copy'
grep -F 'preserved local edit' "$case_root/shared/unslop/SKILL.md" >/dev/null || fail 'local edit lost'
assert_policy "$case_root/shared/unslop" false true
[ -f "$case_root/copilot/prototype/SKILL.md" ] || fail 'group selection migrated an experiment'
[ "$(find "$case_root/archive" -path '*/skill/SKILL.md' | wc -l | tr -d ' ')" -eq 1 ] || fail 'original copy not archived'
# Explicit experimental add must also migrate legacy copies before installing.
output=$(run_case experimental add prototype)
[ ! -e "$case_root/copilot/prototype" ] || fail 'experimental add left duplicate'
assert_policy "$case_root/shared/prototype" true false

printf '%s\n' 'Testing clean portable migration and repeated sync...'
case_root="$test_root/portable-clean"
legacy_install "$case_root/copilot" unslop portable automatic
output=$(run_case sync --group communication)
contains '0 conflicts'
assert_policy "$case_root/shared/unslop" false true
output=$(run_case status --group communication)
contains 'automatic    clean        current'
archive_count=$(find "$case_root/archive" -path '*/skill/SKILL.md' | wc -l | tr -d ' ')
output=$(run_case sync --group communication)
contains '2 unchanged'
[ "$(find "$case_root/archive" -path '*/skill/SKILL.md' | wc -l | tr -d ' ')" = "$archive_count" ] || fail 'repeat sync archived again'

printf '%s\n' 'Testing identical Codex and Copilot copies collapse into one...'
case_root="$test_root/identical"
legacy_install "$case_root/shared" unslop codex manual
legacy_install "$case_root/copilot" unslop portable manual
output=$(run_case sync --group communication)
contains '0 conflicts'
[ ! -e "$case_root/copilot/unslop" ] || fail 'duplicate copy survived'
assert_policy "$case_root/shared/unslop" true false
[ "$(find "$case_root/archive" -path '*/skill/SKILL.md' | wc -l | tr -d ' ')" -eq 2 ] || fail 'both previous copies must be archived'

printf '%s\n' 'Testing invocation conflicts and differing local content...'
case_root="$test_root/preference-conflict"
legacy_install "$case_root/shared" unslop codex automatic
legacy_install "$case_root/copilot" unslop portable manual
if output=$(run_case sync --group communication 2>&1); then fail 'different invocation choices silently merged'; fi
contains 'differs in content or invocation preference'
[ -f "$case_root/copilot/unslop/SKILL.md" ] || fail 'conflicting legacy copy removed'
assert_policy "$case_root/shared/unslop" false true
grep -F 'disable-model-invocation: true' "$case_root/copilot/unslop/SKILL.md" >/dev/null || fail 'legacy preference lost'
case_root="$test_root/content-conflict"
legacy_install "$case_root/shared" unslop codex manual
legacy_install "$case_root/copilot" unslop portable manual
printf '%s\n' 'legacy local edit' >> "$case_root/copilot/unslop/SKILL.md"
if output=$(run_case sync --group communication 2>&1); then fail 'different content silently merged'; fi
contains 'Both copies preserved'
grep -F 'legacy local edit' "$case_root/copilot/unslop/SKILL.md" >/dev/null || fail 'conflicting content lost'

printf '%s\n' 'Testing unmanaged skills and missing baselines remain protected...'
case_root="$test_root/unmanaged"
mkdir -p "$case_root/shared/unslop"
printf '%s\n' 'unmanaged content' > "$case_root/shared/unslop/SKILL.md"
legacy_install "$case_root/copilot" unslop portable manual
if output=$(run_case sync --group communication 2>&1); then fail 'unmanaged collision accepted'; fi
contains 'already exists'
[ "$(cat "$case_root/shared/unslop/SKILL.md")" = 'unmanaged content' ] || fail 'unmanaged content overwritten'
[ -d "$case_root/copilot/unslop" ] || fail 'legacy content removed on unmanaged conflict'
case_root="$test_root/no-baseline"
legacy_install "$case_root/shared" unslop codex manual
rm "$case_root/shared/.batman/state.tsv"
printf '%s\n' 'untracked local edit' >> "$case_root/shared/unslop/SKILL.md"
output=$(run_case sync --group communication 2>&1)
contains 'local changes preserved'
grep -F 'untracked local edit' "$case_root/shared/unslop/SKILL.md" >/dev/null || fail 'untracked edit overwritten'

printf '%s\n' 'Testing a custom destination does not migrate home installations...'
case_root="$test_root/custom"
legacy_install "$case_root/home/.copilot/skills" unslop portable automatic
output=$(env HOME="$case_root/home" BATMAN_SKILLS_DIR="$case_root/custom-skills" \
    BATMAN_CODEX_SKILLS_DIR= BATMAN_PORTABLE_SKILLS_DIR= BATMAN_COPILOT_SKILLS_DIR= \
    "$repo_dir/scripts/batman" sync --group communication)
[ -d "$case_root/home/.copilot/skills/unslop" ] || fail 'custom sync removed a home skill'
[ ! -d "$case_root/home/.agents/skills" ] || fail 'custom sync wrote to home'

printf '%s\n' 'Testing legacy managed symlinks and removed skill copies...'
case_root="$test_root/symlink"
mkdir -p "$case_root/copilot"
ln -s "$repo_dir/skills/dev-workflow/tdd" "$case_root/copilot/tdd"
output=$(run_case sync --group dev-workflow)
contains '0 conflicts'
[ ! -L "$case_root/shared/tdd" ] || fail 'legacy link was not converted'
[ ! -e "$case_root/copilot/tdd" ] || fail 'legacy link still shadows shared copy'
assert_policy "$case_root/shared/tdd" false true
case_root="$test_root/removed"
mkdir -p "$case_root/shared/retired-skill"
printf '%s\n' '---' 'name: retired-skill' 'description: Retired skill.' '---' 'Preserve these instructions.' > "$case_root/shared/retired-skill/SKILL.md"
printf '%s\ncodex\n' "$repo_dir/skills/old-group/retired-skill" > "$case_root/shared/retired-skill/.batman-source"
output=$(run_case sync --group communication)
[ ! -f "$case_root/shared/retired-skill/agents/openai.yaml" ] || fail 'group sync changed a retired skill'
output=$(run_case sync)
grep -F 'Preserve these instructions.' "$case_root/shared/retired-skill/SKILL.md" >/dev/null || fail 'retired skill content lost'
assert_policy "$case_root/shared/retired-skill" true false

printf '%s\n' 'Testing failed archival leaves original content in place...'
case_root="$test_root/archive-failure"
legacy_install "$case_root/copilot" unslop portable automatic
printf '%s\n' 'keep this file' > "$case_root/archive"
if output=$(run_case sync --group communication 2>&1); then fail 'failed archival silently succeeded'; fi
contains 'migration conflicts'
[ -f "$case_root/copilot/unslop/SKILL.md" ] || fail 'original removed after archive failure'
[ ! -e "$case_root/shared/unslop" ] || fail 'source sync continued after migration failure'

printf '%s\n' 'Shared installation migration tests passed.'
