#!/bin/sh

set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
batman_script="$repo_dir/scripts/batman"
install_script="$repo_dir/scripts/install.sh"
check_script="$repo_dir/scripts/check-skills.sh"

test_root=$(mktemp -d "${TMPDIR:-/tmp}/batman-tests.XXXXXX")
trap 'rm -rf "$test_root"' EXIT HUP INT TERM

source_dir="$test_root/source"
codex_dir="$test_root/codex"
copilot_dir="$test_root/copilot"
bin_dir="$test_root/bin"

cp -R "$repo_dir/skills" "$source_dir"
skill_count=$(find "$source_dir" -mindepth 2 -maxdepth 2 -type f -name SKILL.md | wc -l | tr -d ' ')

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

assert_contains() {
    actual=$1
    expected=$2

    case $actual in
        *"$expected"*) ;;
        *)
            printf 'Expected output to contain: %s\nActual output:\n%s\n' "$expected" "$actual" >&2
            fail 'assert_contains'
            ;;
    esac
}

assert_file_contains() {
    file=$1
    expected=$2

    if ! grep -F "$expected" "$file" >/dev/null 2>&1; then
        printf 'Expected %s to contain: %s\n' "$file" "$expected" >&2
        fail 'assert_file_contains'
    fi
}

run_env() {
    env \
        BATMAN_SOURCE_DIR="$source_dir" \
        BATMAN_CODEX_SKILLS_DIR="$codex_dir" \
        BATMAN_COPILOT_SKILLS_DIR="$copilot_dir" \
        "$@"
}

printf '%s\n' 'Checking canonical skill policies...'
"$check_script" >/dev/null

printf '%s\n' 'Checking experimental source integrity...'
cp "$source_dir/experimental/prototype/SKILL.md" "$test_root/prototype-SKILL.md"
printf '%s\n' 'source drift' >> "$source_dir/experimental/prototype/SKILL.md"
if "$check_script" "$source_dir" >/dev/null 2>&1; then
    fail 'experimental source drift should fail validation'
fi
if output=$(run_env "$batman_script" experimental add prototype 2>&1); then
    fail 'experimental add should reject source drift'
fi
assert_contains "$output" 'differs from its pinned raw source'
[ ! -e "$codex_dir/prototype" ] || fail 'rejected experimental add should not install the skill'
cp "$test_root/prototype-SKILL.md" "$source_dir/experimental/prototype/SKILL.md"
"$check_script" "$source_dir" >/dev/null

printf '%s\n' 'Testing fresh and repeat synchronization...'
output=$(run_env "$batman_script" sync --target codex 2>&1)
assert_contains "$output" "$skill_count installed"
assert_contains "$output" '0 conflicts'
[ ! -e "$codex_dir/prototype" ] || fail 'sync should not install experimental skills'

output=$(run_env "$batman_script" sync --target codex 2>&1)
assert_contains "$output" "$skill_count unchanged"
assert_contains "$output" '0 conflicts'

printf '%s\n' 'Testing status and invocation management...'
output=$(run_env "$batman_script" status --target codex 2>&1)
assert_contains "$output" 'unslop             codex            manual       clean        current'

run_env "$batman_script" enable unslop --target codex >/dev/null
assert_file_contains "$codex_dir/unslop/agents/openai.yaml" 'allow_implicit_invocation: true'
output=$(run_env "$batman_script" status --target codex 2>&1)
assert_contains "$output" 'unslop             codex            automatic    clean        current'

run_env "$batman_script" disable unslop --target codex >/dev/null
assert_file_contains "$codex_dir/unslop/agents/openai.yaml" 'allow_implicit_invocation: false'

printf '%s\n' 'Testing explicit experimental skill management...'
output=$(run_env "$batman_script" experimental list 2>&1)
assert_contains "$output" 'prototype          codex            manual       missing      current'

output=$(run_env "$batman_script" experimental add prototype 2>&1)
assert_contains "$output" 'codex installed'
cmp "$source_dir/experimental/prototype/SKILL.md" "$codex_dir/prototype/SKILL.md" >/dev/null || fail 'experimental SKILL.md projection'
assert_file_contains "$codex_dir/prototype/agents/openai.yaml" 'display_name: "Prototype"'
assert_file_contains "$codex_dir/prototype/agents/openai.yaml" 'allow_implicit_invocation: false'
if grep -F 'allow_implicit_invocation' "$source_dir/experimental/prototype/agents/openai.yaml" >/dev/null 2>&1; then
    fail 'experimental add should not modify vendored metadata'
fi

output=$(run_env "$batman_script" experimental add prototype 2>&1)
assert_contains "$output" 'codex unchanged'
output=$(run_env "$batman_script" experimental list 2>&1)
assert_contains "$output" 'prototype          codex            manual       clean        current'

cp "$codex_dir/prototype/agents/openai.yaml" "$test_root/prototype-openai.yaml"
printf '%s\n' '  custom_policy: true' >> "$codex_dir/prototype/agents/openai.yaml"
output=$(run_env "$batman_script" experimental list 2>&1)
assert_contains "$output" 'prototype          codex            manual       modified     current'
cp "$test_root/prototype-openai.yaml" "$codex_dir/prototype/agents/openai.yaml"

if output=$(run_env "$batman_script" enable prototype --target codex 2>&1); then
    fail 'stable invocation commands should reject experimental skills'
fi
assert_contains "$output" 'unknown skill: prototype'

if output=$(run_env "$batman_script" experimental add prototype --target copilot 2>&1); then
    fail 'experimental skills should reject non-Codex targets'
fi
assert_contains "$output" 'experimental skills currently support only the codex target'

run_env "$batman_script" sync --target codex >/dev/null
assert_file_contains "$codex_dir/prototype/agents/openai.yaml" 'allow_implicit_invocation: false'

printf '%s\n' 'local experiment edit' >> "$codex_dir/prototype/UI.md"
output=$(printf 'n\n' | run_env "$batman_script" experimental remove prototype 2>&1)
assert_contains "$output" 'codex preserved'
[ -d "$codex_dir/prototype" ] || fail 'declined experimental removal should preserve the skill'

output=$(printf 'y\n' | run_env "$batman_script" experimental remove prototype 2>&1)
assert_contains "$output" 'codex removed'
[ ! -e "$codex_dir/prototype" ] || fail 'experimental remove should delete the managed copy'
if grep -F 'prototype' "$codex_dir/.batman/state.tsv" >/dev/null 2>&1; then
    fail 'experimental remove should clear skill state'
fi

printf '%s\n' 'Testing local changes and conflict detection...'
printf '%s\n' 'local edit' >> "$codex_dir/unslop/SKILL.md"
output=$(run_env "$batman_script" sync --target codex 2>&1)
assert_contains "$output" 'local changes preserved'
assert_file_contains "$codex_dir/unslop/SKILL.md" 'local edit'

printf '%s\n' 'source update' >> "$source_dir/unslop/SKILL.md"
if output=$(run_env "$batman_script" sync --target codex 2>&1); then
    fail 'sync should report a local/source conflict'
fi
assert_contains "$output" 'has local changes and a source update'

printf '%s\n' 'Testing explicit update confirmation...'
run_env "$batman_script" enable unslop --target codex >/dev/null
output=$(printf 'n\n' | run_env "$batman_script" update unslop --target codex 2>&1)
assert_contains "$output" 'preserved'
assert_file_contains "$codex_dir/unslop/SKILL.md" 'local edit'

output=$(printf 'y\n' | run_env "$batman_script" update unslop --target codex 2>&1)
assert_contains "$output" 'updated'
if grep -F 'local edit' "$codex_dir/unslop/SKILL.md" >/dev/null 2>&1; then
    fail 'confirmed update should replace local changes'
fi
assert_file_contains "$codex_dir/unslop/agents/openai.yaml" 'allow_implicit_invocation: true'
output=$(run_env "$batman_script" status --target codex 2>&1)
assert_contains "$output" 'unslop             codex            automatic    clean        current'

printf '%s\n' 'Testing portable invocation projections...'
run_env "$batman_script" sync --target copilot >/dev/null
run_env "$batman_script" enable to-spec --target copilot >/dev/null
assert_file_contains "$copilot_dir/to-spec/SKILL.md" 'disable-model-invocation: false'
run_env "$batman_script" disable to-spec --target copilot >/dev/null
assert_file_contains "$copilot_dir/to-spec/SKILL.md" 'disable-model-invocation: true'

printf '%s\n' 'Testing command installation and symlink invocation...'
run_env env BATMAN_BIN_DIR="$bin_dir" "$install_script" --target codex --install-command >/dev/null
[ "$(readlink "$bin_dir/batman")" = "$repo_dir/scripts/batman" ] || fail 'command symlink target'
output=$(env \
    BATMAN_SOURCE_DIR="$source_dir" \
    BATMAN_CODEX_SKILLS_DIR="$codex_dir" \
    "$bin_dir/batman" status --target codex 2>&1)
assert_contains "$output" 'Skill              Target           Invocation'

printf '%s\n' 'All Batman regression tests passed.'
