#!/bin/sh

set -eu
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
batman="$repo_dir/scripts/batman"
test_root=$(mktemp -d "${TMPDIR:-/tmp}/batman-entry.XXXXXX")
trap 'rm -rf "$test_root"' EXIT HUP INT TERM

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
contains() { case $output in *"$1"*) ;; *) fail "missing output: $1" ;; esac; }

# Use system utilities: personal wrappers can require tools absent from this PATH.
# Isolate help and command setup from installed agents and the owner's home.
mkdir -p "$test_root/tools" "$test_root/home"
for tool in env dirname basename readlink mktemp rm sed awk grep cat mkdir ln cp mv find sort sha256sum shasum wc tr diff chmod; do
    tool_path=$(PATH=/usr/bin:/bin command -v "$tool" || :)
    [ -z "$tool_path" ] || ln -s "$tool_path" "$test_root/tools/$tool"
done
entry_env() {
    env HOME="$test_root/home" PATH="$test_root/tools" \
        XDG_CONFIG_HOME="$test_root/config" BATMAN_SOURCE_DIR="$repo_dir/skills" \
        BATMAN_SKILLS_DIR="$test_root/shared" \
        BATMAN_PORTABLE_SKILLS_DIR="$test_root/shared" \
        BATMAN_COPILOT_SKILLS_DIR="$test_root/copilot" \
        BATMAN_BIN_DIR="$test_root/bin" "$@"
}

printf '%s\n' 'Testing successful help without source validation or file changes...'
output=$(entry_env "$batman")
contains 'Start with: batman groups'
[ "$(printf '%s\n' "$output" | wc -l)" -le 20 ] || fail 'introductory help is too long'
for form in '--help' 'groups --help' 'scan --help' 'sync --help' 'status --help' \
    'enable --help' 'disable --help' 'update --help' \
    'enable grill-me --help' 'disable grill-me --help' 'update grill-me --help' \
    'experimental --help' 'experimental list --help' 'experimental add --help' \
    'experimental remove --help' 'experimental add prototype --help' \
    'config --help' 'config get --help' 'config set --help' 'config unset --help' \
    'config set default-profile codex --help'; do
    # Each form above intentionally expands into separate arguments.
    output=$(entry_env env BATMAN_SOURCE_DIR="$test_root/missing-source" "$batman" $form)
    contains 'Usage: batman'
done
[ ! -e "$test_root/shared" ] || fail 'help installed skills'
[ ! -e "$test_root/copilot" ] || fail 'help installed Copilot skills'
[ ! -e "$test_root/config" ] || fail 'help wrote configuration'
if entry_env "$batman" missing --help >/dev/null 2>&1; then fail 'unknown command succeeded'; fi

printf '%s\n' 'Testing command-only setup, repeated setup, and conflicts...'
output=$(entry_env env BATMAN_SOURCE_DIR="$test_root/missing-source" "$repo_dir/scripts/install.sh")
contains 'Command installed'
contains 'Add '
[ "$(readlink "$test_root/bin/batman")" = "$batman" ] || fail 'wrong command link'
output=$(entry_env "$repo_dir/scripts/install.sh")
contains 'Command already available'
output=$(entry_env "$test_root/bin/batman" groups)
contains 'dev-workflow'
[ ! -e "$test_root/shared" ] || fail 'setup installed skills'
[ ! -e "$test_root/copilot" ] || fail 'setup installed Copilot skills'
[ ! -e "$test_root/config" ] || fail 'setup wrote configuration'
if output=$(entry_env "$repo_dir/scripts/install.sh" --install-command 2>&1); then fail 'old flag accepted'; fi
contains 'use batman sync'
mkdir "$test_root/conflict"
printf '%s\n' 'keep this file' > "$test_root/conflict/batman"
if entry_env env BATMAN_BIN_DIR="$test_root/conflict" "$repo_dir/scripts/install.sh" >/dev/null 2>&1; then fail 'setup overwrote a command'; fi
[ "$(cat "$test_root/conflict/batman")" = 'keep this file' ] || fail 'command file changed'
mkdir "$test_root/link-conflict"
ln -s /unrelated/batman "$test_root/link-conflict/batman"
if entry_env env BATMAN_BIN_DIR="$test_root/link-conflict" "$repo_dir/scripts/install.sh" >/dev/null 2>&1; then fail 'setup overwrote an unrelated link'; fi
[ "$(readlink "$test_root/link-conflict/batman")" = /unrelated/batman ] || fail 'command link changed'

printf '%s\n' 'Testing shared installation without agent detection or saved profiles...'
mkdir -p "$test_root/config/batman"
printf '%s\n' copilot > "$test_root/config/batman/default-profile"
output=$(entry_env "$batman" sync --group communication 2>&1)
contains '2 installed'
[ -f "$test_root/shared/unslop/SKILL.md" ] || fail 'shared skill missing'
grep -F 'disable-model-invocation: true' "$test_root/shared/unslop/SKILL.md" >/dev/null || fail 'missing manual frontmatter'
grep -F 'allow_implicit_invocation: false' "$test_root/shared/unslop/agents/openai.yaml" >/dev/null || fail 'missing manual Codex policy'
[ ! -e "$test_root/copilot" ] || fail 'sync created duplicate skills'
output=$(entry_env "$batman" status </dev/null)
contains 'Skills directory:'
contains 'manual       clean        current'
output=$(entry_env "$batman" experimental add prototype)
contains 'shared installed'
for legacy_target in codex copilot portable all; do
    output=$(entry_env "$batman" sync --group communication --target "$legacy_target" 2>&1)
    contains '--target is deprecated'
    contains '2 unchanged'
done
[ ! -e "$test_root/copilot" ] || fail 'legacy alias created duplicates'
if entry_env "$batman" sync --target nonsense >/dev/null 2>&1; then fail 'invalid legacy target accepted'; fi
if entry_env "$batman" config set default-profile codex >/dev/null 2>&1; then fail 'retired profile was saved'; fi
output=$(entry_env "$batman" config get default-profile)
contains 'default-profile is retired'
[ "$(cat "$test_root/config/batman/default-profile")" = copilot ] || fail 'sync mutated retired configuration'
entry_env "$batman" config unset default-profile >/dev/null
[ ! -f "$test_root/config/batman/default-profile" ] || fail 'retired profile was not cleared'

printf '%s\n' 'Batman entry-point regression tests passed.'
