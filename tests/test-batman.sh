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

# Retired profiles must not affect the shared installation.
mkdir -p "$config_dir/batman"
printf '%s\n' codex > "$config_dir/batman/default-profile"

cp -R "$repo_dir/skills" "$source_dir"
skill_count=$(find "$source_dir" -mindepth 2 -maxdepth 3 -type f -name SKILL.md ! -path "$source_dir/experimental/*" | wc -l | tr -d ' ')

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
        BATMAN_SKILLS_DIR="$codex_dir" \
        BATMAN_COPILOT_SKILLS_DIR="$copilot_dir" \
        "$@"
}

# Fixture upstream changes update provenance just as a real refresh would.
record_fixture_hash() {
    fixture_name=$1
    fixture_dir=$2
    fixture_hash=$(
        cd "$fixture_dir"
        find . -type f | LC_ALL=C sort | while IFS= read -r fixture_path; do
            if command -v sha256sum >/dev/null 2>&1; then
                file_hash=$(sha256sum "$fixture_path" | awk '{print $1}')
            else
                file_hash=$(shasum -a 256 "$fixture_path" | awk '{print $1}')
            fi
            printf '%s\t%s\n' "$fixture_path" "$file_hash"
        done | if command -v sha256sum >/dev/null 2>&1; then
            sha256sum | awk '{print $1}'
        else
            shasum -a 256 | awk '{print $1}'
        fi
    )
    awk -F '\t' -v OFS='\t' -v skill="$fixture_name" -v hash="$fixture_hash" '
        $1 == skill { $6 = hash }
        { print }
    ' "$source_dir/sources.tsv" > "$test_root/sources-updated.tsv"
    mv "$test_root/sources-updated.tsv" "$source_dir/sources.tsv"
}

printf '%s\n' 'Checking canonical skill policies...'
"$check_script" >/dev/null

printf '%s\n' 'Testing unchanged upstream invocation metadata...'
cp "$source_dir/dev-workflow/implement/agents/openai.yaml" "$test_root/implement-openai.yaml"
printf '%s\n' '  custom_policy: true' >> "$source_dir/dev-workflow/implement/agents/openai.yaml"
if "$check_script" "$source_dir" >/dev/null 2>&1; then
    fail 'modified canonical invocation metadata must fail validation'
fi
cp "$test_root/implement-openai.yaml" "$source_dir/dev-workflow/implement/agents/openai.yaml"

printf '%s\n' 'Testing stable provenance validation...'
cp "$source_dir/sources.tsv" "$test_root/sources-valid.tsv"
awk -F '\t' '$1 == "tdd"' "$test_root/sources-valid.tsv" >> "$source_dir/sources.tsv"
if output=$("$check_script" "$source_dir" 2>&1); then
    fail 'duplicate provenance should fail'
fi
assert_contains "$output" 'duplicate provenance: tdd'
cp "$test_root/sources-valid.tsv" "$source_dir/sources.tsv"
printf 'missing\thttps://example.com/skills\tskills/missing\tmain\tcommit\t%s\n' \
    '0000000000000000000000000000000000000000000000000000000000000000' >> "$source_dir/sources.tsv"
if output=$("$check_script" "$source_dir" 2>&1); then
    fail 'unknown provenance skill should fail'
fi
assert_contains "$output" 'provenance for unknown stable skill: missing'
cp "$test_root/sources-valid.tsv" "$source_dir/sources.tsv"
printf '%s\n' 'malformed' >> "$source_dir/sources.tsv"
if output=$("$check_script" "$source_dir" 2>&1); then
    fail 'malformed provenance should fail'
fi
assert_contains "$output" 'malformed provenance: malformed'
cp "$test_root/sources-valid.tsv" "$source_dir/sources.tsv"
printf '%s\n' 'Extra upstream file' > "$source_dir/dev-workflow/tdd/extra.txt"
if output=$("$check_script" "$source_dir" 2>&1); then
    fail 'extra borrowed skill files should fail'
fi
assert_contains "$output" 'tdd differs from its recorded upstream content'
mv "$source_dir/dev-workflow/tdd/extra.txt" "$test_root/extra.txt"

printf '%s\n' 'Testing external Codex metadata refreshes...'
metadata_scripts="$test_root/metadata-scripts"
cp -R "$repo_dir/scripts" "$metadata_scripts"
metadata_sources="$test_root/metadata-sources"
mkdir -p "$metadata_sources"
cp -R "$source_dir/communication/bro" "$metadata_sources/bro"
awk -F '\t' '$1 == "bro"' "$source_dir/sources.tsv" > "$metadata_sources/sources.tsv"
metadata_destination="$test_root/metadata-codex"
run_metadata_env() {
    run_env env BATMAN_SOURCE_DIR="$metadata_sources" \
        BATMAN_SKILLS_DIR="$metadata_destination" "$metadata_scripts/batman" "$@"
}
run_metadata_env sync >/dev/null
run_metadata_env enable bro >/dev/null
printf '%s\n' '# Updated UI metadata' >> "$metadata_scripts/codex-metadata/bro.yaml"
output=$(run_metadata_env status)
assert_contains "$output" 'automatic    clean        available'
run_metadata_env sync >/dev/null
assert_file_contains "$metadata_destination/bro/agents/openai.yaml" '# Updated UI metadata'
assert_file_contains "$metadata_destination/bro/agents/openai.yaml" 'allow_implicit_invocation: true'
printf '%s\n' '# Explicit metadata update' >> "$metadata_scripts/codex-metadata/bro.yaml"
run_metadata_env update bro >/dev/null
assert_file_contains "$metadata_destination/bro/agents/openai.yaml" '# Explicit metadata update'
assert_file_contains "$metadata_destination/bro/agents/openai.yaml" 'allow_implicit_invocation: true'

printf '%s\n' 'Testing group browsing and selected synchronization...'
printf '  # ignored\tmissing\t-\n' >> "$source_dir/groups.tsv"
output=$(run_env "$batman_script" groups)
assert_contains "$output" 'dev-workflow       grill-me'
assert_contains "$output" 'communication      bro'
assert_contains "$output" 'communication      unslop'
assert_contains "$output" 'ungrouped          writing-for-agents'

group_codex_dir="$test_root/group-codex"
group_copilot_dir="$test_root/group-copilot"
run_group_env() {
    run_env env BATMAN_SKILLS_DIR="$group_codex_dir" \
        BATMAN_COPILOT_SKILLS_DIR="$group_copilot_dir" "$@"
}
output=$(run_group_env "$batman_script" sync --group dev-workflow)
assert_contains "$output" '11 installed'
for group_destination in "$group_codex_dir"; do
    for group_skill in grill-me grill-with-docs grilling domain-modeling codebase-design setup-matt-pocock-skills to-spec to-tickets implement tdd code-review; do
        [ -f "$group_destination/$group_skill/SKILL.md" ] || fail "missing workflow skill: $group_skill"
    done
    for excluded_skill in bro unslop writing-for-agents prototype; do
        [ ! -e "$group_destination/$excluded_skill" ] || fail "group sync installed $excluded_skill"
    done
done
assert_file_contains "$group_codex_dir/implement/agents/openai.yaml" 'allow_implicit_invocation: false'
assert_file_contains "$group_codex_dir/implement/SKILL.md" 'disable-model-invocation: true'
assert_file_contains "$group_codex_dir/setup-matt-pocock-skills/agents/openai.yaml" 'allow_implicit_invocation: false'
assert_file_contains "$group_codex_dir/setup-matt-pocock-skills/SKILL.md" 'disable-model-invocation: true'
[ -f "$group_codex_dir/setup-matt-pocock-skills/issue-tracker-local.md" ] || fail 'setup template was not installed'

printf '%s\n' 'group local edit' >> "$group_codex_dir/implement/SKILL.md"
run_group_env "$batman_script" sync --group dev-workflow >/dev/null
assert_file_contains "$group_codex_dir/implement/SKILL.md" 'group local edit'

printf '%s\n' 'Testing source invocation defaults and local overrides...'
for automatic_skill in grilling domain-modeling tdd code-review; do
    assert_file_contains "$group_codex_dir/$automatic_skill/agents/openai.yaml" 'allow_implicit_invocation: true'
    assert_file_contains "$group_codex_dir/$automatic_skill/SKILL.md" 'disable-model-invocation: false'
done
run_group_env "$batman_script" disable tdd >/dev/null
run_group_env "$batman_script" sync --group dev-workflow >/dev/null
assert_file_contains "$group_codex_dir/tdd/agents/openai.yaml" 'allow_implicit_invocation: false'
run_group_env "$batman_script" enable tdd >/dev/null

# An independent collection checks sourced manual/automatic and unsourced manual
# defaults in each projection without changing the main fixture inventory.
default_source_dir="$test_root/default-sources"
mkdir -p "$default_source_dir"
cp -R "$source_dir/dev-workflow/implement" "$default_source_dir/implement"
cp -R "$source_dir/dev-workflow/tdd" "$default_source_dir/tdd"
awk -F '\t' '$1 == "implement" || $1 == "tdd"' "$source_dir/sources.tsv" > "$default_source_dir/sources.tsv"
mkdir -p "$default_source_dir/local-skill/source"
printf '%s\n' 'Authored supporting file' > "$default_source_dir/local-skill/source/notes.md"
printf '%s\n' '---' 'name: local-skill' 'description: A local skill.' \
    'disable-model-invocation: true' '---' 'Follow local instructions.' \
    > "$default_source_dir/local-skill/SKILL.md"
"$check_script" "$default_source_dir" >/dev/null
default_destination="$test_root/default-shared"
run_env env BATMAN_SOURCE_DIR="$default_source_dir" BATMAN_SKILLS_DIR="$default_destination" \
    "$batman_script" sync >/dev/null
[ -f "$default_destination/local-skill/source/notes.md" ] || fail 'supporting source directory must be installed'
assert_file_contains "$default_destination/tdd/agents/openai.yaml" 'allow_implicit_invocation: true'
assert_file_contains "$default_destination/implement/agents/openai.yaml" 'allow_implicit_invocation: false'
assert_file_contains "$default_destination/local-skill/agents/openai.yaml" 'allow_implicit_invocation: false'
assert_file_contains "$default_destination/tdd/SKILL.md" 'disable-model-invocation: false'
assert_file_contains "$default_destination/implement/SKILL.md" 'disable-model-invocation: true'
assert_file_contains "$default_destination/local-skill/SKILL.md" 'disable-model-invocation: true'
awk '!/^disable-model-invocation:/' "$default_source_dir/local-skill/SKILL.md" > "$test_root/local-skill.md"
cp "$test_root/local-skill.md" "$default_source_dir/local-skill/SKILL.md"
if "$check_script" "$default_source_dir" >/dev/null 2>&1; then
    fail 'a skill without a source must declare its invocation policy'
fi
printf '%s\n' '---' 'name: local-skill' 'disable-model-invocation: sometimes' '---' \
    > "$default_source_dir/local-skill/SKILL.md"
if "$check_script" "$default_source_dir" >/dev/null 2>&1; then
    fail 'malformed invocation policies must fail validation'
fi

printf '%s\n' 'Testing migration from flat source paths...'
for migrated_skill in implement tdd; do
    printf '%s\ncodex\n' "$source_dir/$migrated_skill" > "$group_codex_dir/$migrated_skill/.batman-source"
done
output=$(run_group_env "$batman_script" status --group dev-workflow)
assert_contains "$output" 'tdd                automatic    clean        current'
run_group_env "$batman_script" update tdd >/dev/null
run_group_env "$batman_script" enable tdd >/dev/null
run_group_env "$batman_script" enable code-review >/dev/null
mv "$group_codex_dir/code-review" "$test_root/previous-code-review"
ln -s "$source_dir/code-review" "$group_codex_dir/code-review"
output=$(run_group_env "$batman_script" sync --group dev-workflow)
assert_contains "$output" 'shared migrated'
assert_file_contains "$group_codex_dir/implement/SKILL.md" 'group local edit'
assert_file_contains "$group_codex_dir/implement/.batman-source" "$source_dir/dev-workflow/implement"
assert_file_contains "$group_codex_dir/tdd/agents/openai.yaml" 'allow_implicit_invocation: true'
assert_file_contains "$group_codex_dir/codebase-design/agents/openai.yaml" 'allow_implicit_invocation: true'
[ -f "$group_codex_dir/codebase-design/DESIGN-IT-TWICE.md" ] || fail 'design reference was not installed'
assert_file_contains "$group_codex_dir/code-review/agents/openai.yaml" 'allow_implicit_invocation: true'
[ ! -L "$group_codex_dir/code-review" ] || fail 'legacy flat symlink was not migrated'

output=$(run_group_env "$batman_script" status --group=communication)
assert_contains "$output" 'unslop'
assert_contains "$output" 'bro'
case $output in *implement*|*writing-for-agents*) fail 'group status included unrelated skills' ;; esac

output=$(run_group_env "$batman_script" sync --group dev-workflow --group=communication --group communication)
assert_contains "$output" '2 installed, 0 updated, 10 unchanged, 1 preserved'
[ ! -e "$group_codex_dir/writing-for-agents" ] || fail 'combined groups installed an ungrouped skill'
run_group_env "$sync_script" --group communication >/dev/null
[ -f "$group_codex_dir/bro/SKILL.md" ] || fail 'direct installer did not select communication'
group_portable_dir="$test_root/group-portable"
run_group_env env BATMAN_SKILLS_DIR="$group_portable_dir" \
    "$batman_script" sync --group communication >/dev/null
assert_file_contains "$group_portable_dir/bro/SKILL.md" 'disable-model-invocation: true'
[ ! -e "$group_portable_dir/implement" ] || fail 'portable group sync installed a workflow skill'

for group_command in "$batman_script" "$sync_script"; do
    if [ "$group_command" = "$batman_script" ]; then
        set -- sync
    else
        set --
    fi
    if output=$(run_group_env "$group_command" "$@" --group missing 2>&1); then
        fail 'unknown group should fail'
    fi
    assert_contains "$output" 'unknown group: missing'
    if run_group_env "$group_command" "$@" --group >/dev/null 2>&1; then
        fail 'group without a value should fail'
    fi
done
if run_group_env "$batman_script" enable implement --group dev-workflow >/dev/null 2>&1; then
    fail 'enable should reject group selection'
fi

printf '%s\n' 'Testing group membership and dependency validation...'
cp "$source_dir/groups.tsv" "$test_root/groups.tsv"
printf 'grill-me\tcommunication\t-\n' >> "$source_dir/groups.tsv"
if output=$("$check_script" "$source_dir" 2>&1); then
    fail 'duplicate membership should fail validation'
fi
assert_contains "$output" 'duplicate group membership: grill-me'
cp "$test_root/groups.tsv" "$source_dir/groups.tsv"
awk -F '\t' 'BEGIN { OFS = "\t" } $1 == "grilling" { $2 = "communication" } { print }' \
    "$test_root/groups.tsv" > "$source_dir/groups.tsv"
if output=$(run_group_env "$batman_script" sync --group dev-workflow 2>&1); then
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
printf 'missing\tcommunication\t-\n' >> "$source_dir/groups.tsv"
if output=$("$check_script" "$source_dir" 2>&1); then
    fail 'unknown member should fail validation'
fi
assert_contains "$output" 'unknown stable skill in group manifest: missing'
cp "$test_root/groups.tsv" "$source_dir/groups.tsv"
printf 'malformed\tcommunication\n' >> "$source_dir/groups.tsv"
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
mv "$source_dir/communication/bro" "$source_dir/bro"
if output=$("$check_script" "$source_dir" 2>&1); then
    fail 'membership must reflect directories'
fi
assert_contains "$output" 'unknown stable skill in group manifest: bro'
mv "$source_dir/bro" "$source_dir/communication/bro"

printf '%s\n' 'Testing source collections without a group manifest...'
mv "$source_dir/groups.tsv" "$test_root/groups-withheld.tsv"
"$check_script" "$source_dir" >/dev/null
output=$(run_env "$batman_script" groups)
assert_contains "$output" 'dev-workflow       grill-me'
run_group_env env BATMAN_SKILLS_DIR="$group_portable_dir" \
    "$sync_script" >/dev/null
[ -f "$group_portable_dir/writing-for-agents/SKILL.md" ] || fail 'manifest-free sync should install ungrouped skills'
[ -f "$group_portable_dir/unslop/SKILL.md" ] || fail 'manifest-free sync should install communication skills'
mv "$test_root/groups-withheld.tsv" "$source_dir/groups.tsv"

printf '%s\n' 'Testing experimental folders without integrity manifests...'
cp "$source_dir/experimental/prototype/SKILL.md" "$test_root/prototype-SKILL.md"
printf '%s\n' 'evaluation edit' >> "$source_dir/experimental/prototype/SKILL.md"
"$check_script" "$source_dir" >/dev/null
mkdir -p "$source_dir/experimental/local-experiment"
printf '%s\n' '---' 'name: local-experiment' 'description: A local experiment' '---' \
    'Try this skill.' > "$source_dir/experimental/local-experiment/SKILL.md"
"$check_script" "$source_dir" >/dev/null
output=$(run_env "$batman_script" experimental add local-experiment 2>&1)
assert_contains "$output" 'installed'
[ -f "$codex_dir/local-experiment/SKILL.md" ] || fail 'manifest-free experiment was not installed'
run_env "$batman_script" experimental remove local-experiment >/dev/null
mv "$source_dir/experimental/local-experiment" "$test_root/local-experiment"
cp "$test_root/prototype-SKILL.md" "$source_dir/experimental/prototype/SKILL.md"

printf '%s\n' 'Testing fresh and repeat synchronization...'
output=$(run_env "$batman_script" sync 2>&1)
assert_contains "$output" "$skill_count installed"
assert_contains "$output" '0 conflicts'
[ ! -e "$codex_dir/prototype" ] || fail 'sync should not install experimental skills'

run_env "$batman_script" sync >/dev/null
[ ! -e "$copilot_dir/prototype" ] || fail 'sync should not install experimental skills for Copilot'

output=$(run_env "$batman_script" sync 2>&1)
assert_contains "$output" "$skill_count unchanged"
assert_contains "$output" '0 conflicts'

printf '%s\n' 'Testing provenance isolation and Codex UI metadata...'
cp "$source_dir/sources.tsv" "$test_root/sources-original.tsv"
# A tracked ref change without new bytes must not trigger an installed update.
awk -F '\t' -v OFS='\t' '$1 == "implement" { $4 = "test-ref" } { print }' \
    "$test_root/sources-original.tsv" > "$source_dir/sources.tsv"
output=$(run_env "$batman_script" status 2>&1)
assert_contains "$output" 'implement          manual       clean        current'
output=$(run_env "$batman_script" sync 2>&1)
assert_contains "$output" "$skill_count unchanged"
cp "$test_root/sources-original.tsv" "$source_dir/sources.tsv"
for metadata_skill in bro unslop; do
    [ ! -e "$source_dir/communication/$metadata_skill/agents/openai.yaml" ] || fail 'Batman UI metadata is inside a borrowed skill'
    assert_file_contains "$codex_dir/$metadata_skill/agents/openai.yaml" 'display_name:'
done
run_env "$batman_script" update unslop >/dev/null
assert_file_contains "$codex_dir/unslop/agents/openai.yaml" 'display_name: "Unslop"'
portable_dir="$test_root/portable"
run_env env BATMAN_SKILLS_DIR="$portable_dir" "$batman_script" sync >/dev/null

printf '%s\n' 'Testing status and invocation management...'
output=$(run_env "$batman_script" status 2>&1)
assert_contains "$output" 'unslop             manual       clean        current'

run_env "$batman_script" enable unslop >/dev/null
assert_file_contains "$codex_dir/unslop/agents/openai.yaml" 'allow_implicit_invocation: true'
output=$(run_env "$batman_script" status 2>&1)
assert_contains "$output" 'unslop             automatic    clean        current'

run_env "$batman_script" disable unslop >/dev/null
assert_file_contains "$codex_dir/unslop/agents/openai.yaml" 'allow_implicit_invocation: false'

printf '%s\n' 'Testing explicit experimental skill management...'
output=$(run_env "$batman_script" experimental list 2>&1)
assert_contains "$output" 'prototype          automatic    missing      current'

output=$(run_env "$batman_script" experimental add prototype 2>&1)
assert_contains "$output" 'shared installed'
assert_file_contains "$codex_dir/prototype/SKILL.md" 'disable-model-invocation: false'
assert_file_contains "$codex_dir/prototype/agents/openai.yaml" 'display_name: "Prototype"'
assert_file_contains "$codex_dir/prototype/agents/openai.yaml" 'allow_implicit_invocation: true'
if grep -F 'allow_implicit_invocation' "$source_dir/experimental/prototype/agents/openai.yaml" >/dev/null 2>&1; then
    fail 'experimental add should not modify vendored metadata'
fi

output=$(run_env "$batman_script" experimental add prototype 2>&1)
assert_contains "$output" 'shared unchanged'
output=$(run_env "$batman_script" experimental list 2>&1)
assert_contains "$output" 'prototype          automatic    clean        current'

# Re-adding an experiment preserves an installed invocation override.
awk '{ sub(/allow_implicit_invocation: true/, "allow_implicit_invocation: false"); print }' \
    "$codex_dir/prototype/agents/openai.yaml" > "$test_root/prototype-manual.yaml"
cp "$test_root/prototype-manual.yaml" "$codex_dir/prototype/agents/openai.yaml"
run_env "$batman_script" experimental add prototype >/dev/null
assert_file_contains "$codex_dir/prototype/agents/openai.yaml" 'allow_implicit_invocation: false'
awk '{ sub(/allow_implicit_invocation: false/, "allow_implicit_invocation: true"); print }' \
    "$codex_dir/prototype/agents/openai.yaml" > "$test_root/prototype-automatic.yaml"
cp "$test_root/prototype-automatic.yaml" "$codex_dir/prototype/agents/openai.yaml"
cp "$codex_dir/prototype/agents/openai.yaml" "$test_root/prototype-openai.yaml"
printf '%s\n' '  custom_policy: true' >> "$codex_dir/prototype/agents/openai.yaml"
output=$(run_env "$batman_script" experimental list 2>&1)
assert_contains "$output" 'prototype          automatic    modified     current'
cp "$test_root/prototype-openai.yaml" "$codex_dir/prototype/agents/openai.yaml"

if output=$(run_env "$batman_script" enable prototype 2>&1); then
    fail 'stable invocation commands should reject experimental skills'
fi
assert_contains "$output" 'unknown skill: prototype'

output=$(run_env "$batman_script" experimental add prototype 2>&1)
assert_contains "$output" 'shared unchanged'
invocation_count=$(grep -c '^disable-model-invocation:' "$codex_dir/prototype/SKILL.md")
[ "$invocation_count" -eq 1 ] || fail 'repeated add should keep one invocation field'
run_env "$batman_script" sync >/dev/null
assert_file_contains "$codex_dir/prototype/agents/openai.yaml" 'allow_implicit_invocation: true'

printf '%s\n' 'local experiment edit' >> "$codex_dir/prototype/UI.md"
output=$(printf 'n\n' | run_env "$batman_script" experimental remove prototype 2>&1)
assert_contains "$output" 'shared preserved'
[ -d "$codex_dir/prototype" ] || fail 'declined experimental removal should preserve the skill'

output=$(printf 'y\n' | run_env "$batman_script" experimental remove prototype 2>&1)
assert_contains "$output" 'shared removed'
[ ! -e "$codex_dir/prototype" ] || fail 'experimental remove should delete the managed copy'
if awk -F '\t' '$2 == "prototype" { found = 1 } END { exit !found }' "$codex_dir/.batman/state.tsv"; then
    fail 'experimental remove should clear skill state'
fi

printf '%s\n' 'Testing local changes and conflict detection...'
printf '%s\n' 'local edit' >> "$codex_dir/unslop/SKILL.md"
output=$(run_env "$batman_script" sync 2>&1)
assert_contains "$output" 'local changes preserved'
assert_file_contains "$codex_dir/unslop/SKILL.md" 'local edit'

printf '%s\n' 'source update' >> "$source_dir/communication/unslop/SKILL.md"
record_fixture_hash unslop "$source_dir/communication/unslop"
if output=$(run_env "$batman_script" sync 2>&1); then
    fail 'sync should report a local/source conflict'
fi
assert_contains "$output" 'has local changes and a source update'

printf '%s\n' 'Testing explicit update confirmation...'
run_env "$batman_script" enable unslop >/dev/null
output=$(printf 'n\n' | run_env "$batman_script" update unslop 2>&1)
assert_contains "$output" 'preserved'
assert_file_contains "$codex_dir/unslop/SKILL.md" 'local edit'

output=$(printf 'y\n' | run_env "$batman_script" update unslop 2>&1)
assert_contains "$output" 'updated'
if grep -F 'local edit' "$codex_dir/unslop/SKILL.md" >/dev/null 2>&1; then
    fail 'confirmed update should replace local changes'
fi
assert_file_contains "$codex_dir/unslop/agents/openai.yaml" 'allow_implicit_invocation: true'
output=$(run_env "$batman_script" status 2>&1)
assert_contains "$output" 'unslop             automatic    clean        current'

printf '%s\n' 'Testing portable invocation projections...'
run_env "$batman_script" sync >/dev/null
run_env "$batman_script" enable to-spec >/dev/null
assert_file_contains "$codex_dir/to-spec/SKILL.md" 'disable-model-invocation: false'
run_env "$batman_script" disable to-spec >/dev/null
assert_file_contains "$codex_dir/to-spec/SKILL.md" 'disable-model-invocation: true'

printf '%s\n' 'Testing command installation and symlink invocation...'
run_env env BATMAN_BIN_DIR="$bin_dir" "$install_script" >/dev/null
[ "$(readlink "$bin_dir/batman")" = "$repo_dir/scripts/batman" ] || fail 'command symlink target'
output=$(env \
    BATMAN_SOURCE_DIR="$source_dir" \
    BATMAN_SKILLS_DIR="$codex_dir" \
    "$bin_dir/batman" status 2>&1)
assert_contains "$output" 'Skill              Invocation'

sh "$script_dir/test-batman-shared.sh"
sh "$script_dir/test-batman-entry.sh"
sh "$script_dir/test-batman-scan.sh"

printf '%s\n' 'All Batman regression tests passed.'
