#!/bin/sh

set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
batman_script="$script_dir/../scripts/batman"
test_root=$(mktemp -d "${TMPDIR:-/tmp}/batman-scan-tests.XXXXXX")
trap 'rm -rf "$test_root"' EXIT HUP INT TERM
scan_home="$test_root/home"
projects="$test_root/projects with spaces"
project="$projects/app"
mkdir -p "$scan_home" "$project/.git" "$project/src/deep"
printf '%s\n' 'ref: refs/heads/main' > "$project/.git/HEAD"

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

assert_contains() {
    case $output in *"$1"*) ;; *) fail "expected output to contain: $1" ;; esac
}

assert_absent() {
    case $output in *"$1"*) fail "unexpected output: $1" ;; esac
}

assert_row() {
    printf '%s\n' "$output" | awk -v name="$1" -v scope="$2" -v convention="$3" -v location="$4" '
        index($0, name) == 1 && index($0, scope) && index($0, convention) && index($0, location) { found = 1 }
        END { exit !found }
    ' || fail "missing row: $1 $2 $3 $4"
}

make_skill() {
    mkdir -p "$1"
    printf '%s\n' '---' "name: $2" 'description: Test fixture.' '---' 'Test instructions.' > "$1/SKILL.md"
}

scan() {
    env HOME="$scan_home" XDG_CONFIG_HOME="$test_root/config" \
        BATMAN_CODEX_SKILLS_DIR="$scan_home/.agents/skills" \
        BATMAN_COPILOT_SKILLS_DIR="$scan_home/.copilot/skills" \
        "$batman_script" scan "$@"
}

printf '%s\n' 'Testing scan inventory, scope, conventions, and unknown counts...'
make_skill "$scan_home/.agents/skills/shared" shared
make_skill "$scan_home/.copilot/skills/personal" personal
make_skill "$project/.agents/skills/shared" shared
make_skill "$project/.github/skills/deploy" '"deploy-task"'
make_skill "$projects/other/.claude/skills/check" check
make_skill "$project/examples/scattered" scattered
make_skill "$project/.agents/skills/shared/source" snapshot
make_skill "$project/.git/objects/ignored" ignored-git
before=$(find "$test_root" -type f -exec cksum {} \; | LC_ALL=C sort)
output=$(scan "$projects")
assert_absent 'Scanning skills...'
assert_contains Convention
assert_row shared Global 'Codex, Copilot' "$scan_home/.agents/skills/shared"
assert_row personal Global Copilot "$scan_home/.copilot/skills/personal"
assert_row shared Project 'Codex, Copilot' "$project/.agents/skills/shared"
assert_row deploy-task Project Copilot "$project/.github/skills/deploy"
assert_row check Project Copilot "$projects/other/.claude/skills/check"
assert_contains '2 skills found outside recognized installation locations.'
assert_contains 'Use --include-unknown to view them.'
assert_absent scattered
assert_absent snapshot
assert_absent ignored-git
after=$(find "$test_root" -type f -exec cksum {} \; | LC_ALL=C sort)
[ "$before" = "$after" ] || fail 'scan changed fixture files'

output=$(scan --include-unknown "$projects")
assert_row scattered Unknown '-' "$project/examples/scattered"
assert_row snapshot Unknown '-' "$project/.agents/skills/shared/source"
assert_absent 'Use --include-unknown'

printf '%s\n' 'Testing default project root and explicit directory boundaries...'
output=$(cd "$project/src/deep" && scan)
assert_row deploy-task Project Copilot "$project/.github/skills/deploy"
assert_absent "$projects/other"
output=$(scan "$project/src/deep")
assert_absent deploy-task
assert_contains '0 skills found outside recognized installation locations.'
mkdir -p "$test_root/no-repo"
output=$(cd "$test_root/no-repo" && scan)
assert_row shared Global 'Codex, Copilot' "$scan_home/.agents/skills/shared"
assert_absent deploy-task
# Worktrees use a .git file rather than a directory.
mkdir -p "$projects/worktree/src"
printf '%s\n' 'gitdir: /unused-test-path' > "$projects/worktree/.git"
make_skill "$projects/worktree/.github/skills/worktree" worktree
output=$(cd "$projects/worktree/src" && scan)
assert_row worktree Project Copilot "$projects/worktree/.github/skills/worktree"

printf '%s\n' 'Testing linked installs, duplicate names, and root deduplication...'
make_skill "$test_root/external/source" linked
ln -s "$test_root/external/source" "$scan_home/.agents/skills/linked"
ln -s "$test_root/external/source" "$project/.agents/skills/linked"
ln -s "$project" "$project/loop"
output=$(scan "$project")
assert_row linked Global 'Codex, Copilot' "$scan_home/.agents/skills/linked"
assert_row linked Project 'Codex, Copilot' "$project/.agents/skills/linked"
mkdir -p "$projects/linked-root/.agents"
ln -s "$scan_home/.agents/skills" "$projects/linked-root/.agents/skills"
output=$(scan "$scan_home")
shared_rows=$(printf '%s\n' "$output" | awk '/^shared[[:space:]]/ { n++ } END { print n + 0 }')
[ "$shared_rows" -eq 1 ] || fail 'global and recursive scan duplicated an installation'
output=$(scan "$projects/linked-root")
assert_row shared Global 'Codex, Copilot' "$scan_home/.agents/skills/shared"
make_skill "$test_root/external/skill-root/root-skill" root-skill
mkdir -p "$projects/external-root/.agents"
ln -s "$test_root/external/skill-root" "$projects/external-root/.agents/skills"
output=$(scan "$projects/external-root")
assert_row root-skill Project 'Codex, Copilot' "$projects/external-root/.agents/skills/root-skill"

printf '%s\n' 'Testing single-convention output, overrides, metadata fallback, and empty scans...'
single_home="$test_root/single-home"
mkdir -p "$single_home/.copilot/skills/fallback" "$test_root/empty"
printf '%s\n' '# No frontmatter' 'name: not-the-name' > "$single_home/.copilot/skills/fallback/SKILL.md"
output=$(env HOME="$single_home" BATMAN_CODEX_SKILLS_DIR="$test_root/missing" \
    BATMAN_COPILOT_SKILLS_DIR="$single_home/.copilot/skills" "$batman_script" scan "$test_root/empty")
assert_absent Convention
assert_contains fallback
assert_absent not-the-name
make_skill "$test_root/custom-codex/custom" custom
output=$(env HOME="$single_home" BATMAN_CODEX_SKILLS_DIR="$test_root/custom-codex" \
    BATMAN_COPILOT_SKILLS_DIR="$single_home/.copilot/skills" "$batman_script" scan "$test_root/empty")
assert_row custom Global Codex "$test_root/custom-codex/custom"
assert_row fallback Global Copilot "$single_home/.copilot/skills/fallback"
output=$(env HOME="$test_root/empty" BATMAN_CODEX_SKILLS_DIR="$test_root/missing" \
    BATMAN_COPILOT_SKILLS_DIR="$test_root/missing" "$batman_script" scan "$test_root/empty")
assert_contains 'No skills found in recognized installation locations.'
assert_contains '0 skills found outside recognized installation locations.'

printf '%s\n' 'Testing scan argument validation...'
for argument in --target=codex --unknown "$test_root/missing"; do
    if scan "$argument" >/dev/null 2>&1; then fail "accepted invalid argument: $argument"; fi
done
if scan "$project" "$projects" >/dev/null 2>&1; then fail 'accepted two directories'; fi
output=$(scan --help)
assert_contains 'Usage: batman scan [<dir>] [--include-unknown]'
output=$(scan -- "$project")
assert_contains deploy-task

if [ "$(id -u)" -ne 0 ]; then
    printf '%s\n' 'Testing incomplete scan reporting...'
    mkdir -p "$project/unreadable"
    chmod 000 "$project/unreadable"
    scan_status=0
    scan "$project" > "$test_root/partial-output" 2> "$test_root/partial-errors" || scan_status=$?
    chmod 700 "$project/unreadable"
    [ "$scan_status" -eq 1 ] || fail 'unreadable paths should fail the scan'
    output=$(cat "$test_root/partial-output")
    assert_contains deploy-task
    output=$(cat "$test_root/partial-errors")
    assert_contains 'scan incomplete'
fi

printf '%s\n' 'All Batman scan tests passed.'
