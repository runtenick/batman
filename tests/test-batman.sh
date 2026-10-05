#!/bin/sh

set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
batman_script="$repo_dir/scripts/batman"
sync_script="$repo_dir/scripts/sync-skills.sh"
install_script="$repo_dir/scripts/install.sh"
check_script="$repo_dir/scripts/check-skills.sh"

test_root=$(mktemp -d "${TMPDIR:-/tmp}/batman-tests.XXXXXX")
trap 'rm -rf "$test_root"' EXIT HUP INT TERM

source_dir="$test_root/source"
codex_dir="$test_root/codex"
copilot_dir="$test_root/copilot"
bin_dir="$test_root/bin"
config_dir="$test_root/config"

# Keep implicit experimental targets independent of the maintainer's setup.
mkdir -p "$config_dir/batman"
printf '%s\n' codex > "$config_dir/batman/default-profile"

cp -R "$repo_dir/skills" "$source_dir"
skill_count=$(find "$source_dir" -mindepth 2 -maxdepth 3 -type f -name SKILL.md ! -path "$source_dir/experimental/*" ! -path "$source_dir/*/source/*" | wc -l | tr -d ' ')

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
        XDG_CONFIG_HOME="$config_dir" \
        BATMAN_SOURCE_DIR="$source_dir" \
        BATMAN_CODEX_SKILLS_DIR="$codex_dir" \
        BATMAN_COPILOT_SKILLS_DIR="$copilot_dir" \
        "$@"
}

printf '%s\n' 'Checking canonical skill policies...'
"$check_script" >/dev/null

printf '%s\n' 'Testing group browsing and selected synchronization...'
printf '  # ignored\tmissing\t-\n' >> "$source_dir/groups.tsv"
output=$(run_env "$batman_script" groups)
assert_contains "$output" 'dev-workflow       grill-me'
assert_contains "$output" 'ux                 ui-prototype'
assert_contains "$output" 'communication      bro'
assert_contains "$output" 'communication      unslop'
assert_contains "$output" 'ungrouped          writing-for-agents'

group_codex_dir="$test_root/group-codex"
group_copilot_dir="$test_root/group-copilot"
run_group_env() {
    run_env env BATMAN_CODEX_SKILLS_DIR="$group_codex_dir" \
        BATMAN_COPILOT_SKILLS_DIR="$group_copilot_dir" "$@"
}
output=$(run_group_env "$batman_script" sync --group dev-workflow --target all)
assert_contains "$output" '18 installed'
for group_destination in "$group_codex_dir" "$group_copilot_dir"; do
    for group_skill in grill-me grill-with-docs grilling domain-modeling to-spec to-tickets implement tdd code-review; do
        [ -f "$group_destination/$group_skill/SKILL.md" ] || fail "missing workflow skill: $group_skill"
    done
    for excluded_skill in grill-ux ui-prototype bro unslop writing-for-agents prototype; do
        [ ! -e "$group_destination/$excluded_skill" ] || fail "group sync installed $excluded_skill"
    done
done
assert_file_contains "$group_codex_dir/implement/agents/openai.yaml" 'allow_implicit_invocation: false'
assert_file_contains "$group_copilot_dir/implement/SKILL.md" 'disable-model-invocation: true'
printf '%s\n' 'group local edit' >> "$group_codex_dir/implement/SKILL.md"
run_group_env "$batman_script" sync --group dev-workflow --target codex >/dev/null
assert_file_contains "$group_codex_dir/implement/SKILL.md" 'group local edit'

printf '%s\n' 'Testing migration from flat source paths...'
for migrated_skill in implement tdd; do
    printf '%s\ncodex\n' "$source_dir/$migrated_skill" > "$group_codex_dir/$migrated_skill/.batman-source"
done
output=$(run_group_env "$batman_script" status --group dev-workflow --target codex)
assert_contains "$output" 'tdd                codex            manual       clean        current'
run_group_env "$batman_script" update tdd --target codex >/dev/null
run_group_env "$batman_script" enable tdd --target codex >/dev/null
run_group_env "$batman_script" enable code-review --target codex >/dev/null
mv "$group_codex_dir/code-review" "$test_root/previous-code-review"
ln -s "$source_dir/code-review" "$group_codex_dir/code-review"
output=$(run_group_env "$batman_script" sync --group dev-workflow --target codex)
assert_contains "$output" 'codex migrated'
assert_file_contains "$group_codex_dir/implement/SKILL.md" 'group local edit'
assert_file_contains "$group_codex_dir/implement/.batman-source" "$source_dir/dev-workflow/implement"
assert_file_contains "$group_codex_dir/tdd/agents/openai.yaml" 'allow_implicit_invocation: true'
assert_file_contains "$group_codex_dir/code-review/agents/openai.yaml" 'allow_implicit_invocation: true'
[ ! -L "$group_codex_dir/code-review" ] || fail 'legacy flat symlink was not migrated'

output=$(run_group_env "$batman_script" status --group=ux --target codex)
assert_contains "$output" 'grill-ux'
assert_contains "$output" 'ui-prototype'
case $output in *implement*|*unslop*) fail 'group status included unrelated skills' ;; esac

output=$(run_group_env "$batman_script" sync --target copilot --group dev-workflow --group=ux --group ux)
assert_contains "$output" '2 installed, 0 updated, 9 unchanged'
[ ! -e "$group_copilot_dir/unslop" ] || fail 'combined groups installed a communication skill'
run_group_env "$sync_script" --group ux --target codex >/dev/null
[ -f "$group_codex_dir/ui-prototype/SKILL.md" ] || fail 'direct installer did not select UX'
group_portable_dir="$test_root/group-portable"
run_group_env env BATMAN_PORTABLE_SKILLS_DIR="$group_portable_dir" \
    "$batman_script" sync --group ux --target portable >/dev/null
assert_file_contains "$group_portable_dir/ui-prototype/SKILL.md" 'disable-model-invocation: true'
[ ! -e "$group_portable_dir/implement" ] || fail 'portable group sync installed a workflow skill'

for group_command in "$batman_script" "$sync_script"; do
    if [ "$group_command" = "$batman_script" ]; then
        set -- sync
    else
        set --
    fi
    if output=$(run_group_env "$group_command" "$@" --group missing --target codex 2>&1); then
        fail 'unknown group should fail'
    fi
    assert_contains "$output" 'unknown group: missing'
    if run_group_env "$group_command" "$@" --group >/dev/null 2>&1; then
        fail 'group without a value should fail'
    fi
done
if run_group_env "$batman_script" enable implement --group dev-workflow --target codex >/dev/null 2>&1; then
    fail 'enable should reject group selection'
fi

printf '%s\n' 'Testing group membership and dependency validation...'
cp "$source_dir/groups.tsv" "$test_root/groups.tsv"
printf 'grill-me\tux\t-\n' >> "$source_dir/groups.tsv"
if output=$("$check_script" "$source_dir" 2>&1); then
    fail 'duplicate membership should fail validation'
fi
assert_contains "$output" 'duplicate group membership: grill-me'
cp "$test_root/groups.tsv" "$source_dir/groups.tsv"
awk -F '\t' 'BEGIN { OFS = "\t" } $1 == "grilling" { $2 = "ux" } { print }' \
    "$test_root/groups.tsv" > "$source_dir/groups.tsv"
if output=$(run_group_env "$batman_script" sync --group dev-workflow --target codex 2>&1); then
    fail 'cross-group dependency should fail synchronization'
fi
assert_contains "$output" 'dependency grilling must belong to group dev-workflow'
cp "$test_root/groups.tsv" "$source_dir/groups.tsv"
sed '/^tdd[[:space:]]/d' "$test_root/groups.tsv" > "$source_dir/groups.tsv"
if output=$("$check_script" "$source_dir" 2>&1); then
    fail 'ungrouped dependency should fail validation'
fi
assert_contains "$output" 'dependency tdd must belong to group dev-workflow'
cp "$test_root/groups.tsv" "$source_dir/groups.tsv"
printf 'missing\tux\t-\n' >> "$source_dir/groups.tsv"
if output=$("$check_script" "$source_dir" 2>&1); then
    fail 'unknown member should fail validation'
fi
assert_contains "$output" 'unknown stable skill in group manifest: missing'
cp "$test_root/groups.tsv" "$source_dir/groups.tsv"
printf 'malformed\tux\n' >> "$source_dir/groups.tsv"
if output=$("$check_script" "$source_dir" 2>&1); then
    fail 'malformed group entry should fail validation'
fi
assert_contains "$output" 'malformed group manifest entry'
cp "$test_root/groups.tsv" "$source_dir/groups.tsv"

printf '%s\n' 'Testing physical layout validation...'
cp -R "$source_dir/dev-workflow/grill-me" "$source_dir/grill-me"
if output=$("$check_script" "$source_dir" 2>&1); then
    fail 'duplicate skill directories should fail validation'
fi
assert_contains "$output" 'duplicate stable skill: grill-me'
mv "$source_dir/grill-me" "$test_root/duplicate-grill-me"
mv "$source_dir/ux/ui-prototype" "$source_dir/ui-prototype"
if output=$("$check_script" "$source_dir" 2>&1); then
    fail 'membership must reflect directories'
fi
assert_contains "$output" 'unknown stable skill in group manifest: ui-prototype'
mv "$source_dir/ui-prototype" "$source_dir/ux/ui-prototype"

printf '%s\n' 'Testing source collections without a group manifest...'
mv "$source_dir/groups.tsv" "$test_root/groups-withheld.tsv"
"$check_script" "$source_dir" >/dev/null
output=$(run_env "$batman_script" groups)
assert_contains "$output" 'dev-workflow       grill-me'
run_group_env env BATMAN_PORTABLE_SKILLS_DIR="$group_portable_dir" \
    "$sync_script" --target portable >/dev/null
[ -f "$group_portable_dir/writing-for-agents/SKILL.md" ] || fail 'manifest-free sync should install ungrouped skills'
[ -f "$group_portable_dir/unslop/SKILL.md" ] || fail 'manifest-free sync should install communication skills'
mv "$test_root/groups-withheld.tsv" "$source_dir/groups.tsv"

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

run_env "$batman_script" sync --target copilot >/dev/null
[ ! -e "$copilot_dir/prototype" ] || fail 'sync should not install experimental skills for Copilot'

output=$(run_env "$batman_script" sync --target codex 2>&1)
assert_contains "$output" "$skill_count unchanged"
assert_contains "$output" '0 conflicts'

printf '%s\n' 'Testing upstream reference isolation...'
[ ! -e "$codex_dir/implement/source" ] || fail 'Codex sync should omit upstream references'
[ ! -e "$copilot_dir/implement/source" ] || fail 'Copilot sync should omit upstream references'
printf '%s\n' 'reference-only edit' >> "$source_dir/dev-workflow/implement/source/SKILL.md"
output=$(run_env "$batman_script" status --target codex 2>&1)
assert_contains "$output" 'implement          codex            manual       clean        current'
output=$(run_env "$batman_script" sync --target codex 2>&1)
assert_contains "$output" "$skill_count unchanged"
run_env "$batman_script" update implement --target codex >/dev/null
run_env "$batman_script" update implement --target copilot >/dev/null
[ ! -e "$codex_dir/implement/source" ] || fail 'Codex update should omit upstream references'
[ ! -e "$copilot_dir/implement/source" ] || fail 'Copilot update should omit upstream references'
portable_dir="$test_root/portable"
run_env env BATMAN_PORTABLE_SKILLS_DIR="$portable_dir" "$batman_script" sync --target portable >/dev/null
[ ! -e "$portable_dir/implement/source" ] || fail 'portable sync should omit upstream references'
run_env env BATMAN_PORTABLE_SKILLS_DIR="$portable_dir" "$batman_script" update implement --target portable >/dev/null
[ ! -e "$portable_dir/implement/source" ] || fail 'portable update should omit upstream references'

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

output=$(run_env "$batman_script" experimental list --target all 2>&1)
assert_contains "$output" 'prototype          codex            manual       clean        current'
assert_contains "$output" 'prototype          copilot          manual       missing      current'

output=$(run_env "$batman_script" experimental add prototype --target all 2>&1)
assert_contains "$output" 'codex unchanged'
assert_contains "$output" 'copilot installed'
assert_file_contains "$copilot_dir/prototype/SKILL.md" 'disable-model-invocation: true'
cmp "$source_dir/experimental/prototype/LOGIC.md" "$copilot_dir/prototype/LOGIC.md" >/dev/null || fail 'experimental Copilot LOGIC.md projection'
cmp "$source_dir/experimental/prototype/UI.md" "$copilot_dir/prototype/UI.md" >/dev/null || fail 'experimental Copilot UI.md projection'
cmp "$source_dir/experimental/prototype/agents/openai.yaml" "$copilot_dir/prototype/agents/openai.yaml" >/dev/null || fail 'experimental Copilot metadata projection'
if grep -F 'disable-model-invocation' "$source_dir/experimental/prototype/SKILL.md" >/dev/null 2>&1; then
    fail 'experimental Copilot add should not modify the vendored SKILL.md'
fi

output=$(run_env "$batman_script" experimental list --target copilot 2>&1)
assert_contains "$output" 'prototype          copilot          manual       clean        current'

output=$(run_env "$batman_script" experimental add prototype --target copilot 2>&1)
assert_contains "$output" 'copilot unchanged'
invocation_count=$(grep -c '^disable-model-invocation:' "$copilot_dir/prototype/SKILL.md")
[ "$invocation_count" -eq 1 ] || fail 'repeated Copilot add should keep one invocation field'

run_env "$batman_script" sync --target copilot >/dev/null
assert_file_contains "$copilot_dir/prototype/SKILL.md" 'disable-model-invocation: true'

output=$(run_env "$batman_script" experimental remove prototype --target copilot 2>&1)
assert_contains "$output" 'copilot removed'
[ ! -e "$copilot_dir/prototype" ] || fail 'experimental remove should delete the managed Copilot copy'
if awk -F '\t' '$2 == "prototype" { found = 1 } END { exit !found }' "$copilot_dir/.batman/state.tsv"; then
    fail 'experimental remove should clear Copilot skill state'
fi

if output=$(run_env "$batman_script" experimental add prototype --target portable 2>&1); then
    fail 'experimental skills should reject the portable target'
fi
assert_contains "$output" 'experimental skills support codex, copilot, or all'

run_env "$batman_script" sync --target codex >/dev/null
assert_file_contains "$codex_dir/prototype/agents/openai.yaml" 'allow_implicit_invocation: false'

printf '%s\n' 'local experiment edit' >> "$codex_dir/prototype/UI.md"
output=$(printf 'n\n' | run_env "$batman_script" experimental remove prototype 2>&1)
assert_contains "$output" 'codex preserved'
[ -d "$codex_dir/prototype" ] || fail 'declined experimental removal should preserve the skill'

output=$(printf 'y\n' | run_env "$batman_script" experimental remove prototype 2>&1)
assert_contains "$output" 'codex removed'
[ ! -e "$codex_dir/prototype" ] || fail 'experimental remove should delete the managed copy'
if awk -F '\t' '$2 == "prototype" { found = 1 } END { exit !found }' "$codex_dir/.batman/state.tsv"; then
    fail 'experimental remove should clear skill state'
fi

printf '%s\n' 'Testing local changes and conflict detection...'
printf '%s\n' 'local edit' >> "$codex_dir/unslop/SKILL.md"
output=$(run_env "$batman_script" sync --target codex 2>&1)
assert_contains "$output" 'local changes preserved'
assert_file_contains "$codex_dir/unslop/SKILL.md" 'local edit'

printf '%s\n' 'source update' >> "$source_dir/communication/unslop/SKILL.md"
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
run_env env BATMAN_BIN_DIR="$bin_dir" "$install_script" >/dev/null
[ "$(readlink "$bin_dir/batman")" = "$repo_dir/scripts/batman" ] || fail 'command symlink target'
output=$(env \
    BATMAN_SOURCE_DIR="$source_dir" \
    BATMAN_CODEX_SKILLS_DIR="$codex_dir" \
    "$bin_dir/batman" status --target codex 2>&1)
assert_contains "$output" 'Skill              Target           Invocation'

sh "$script_dir/test-batman-entry.sh"
sh "$script_dir/test-batman-scan.sh"

printf '%s\n' 'All Batman regression tests passed.'
