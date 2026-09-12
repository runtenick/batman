#!/bin/sh

set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
source_dir="$repo_dir/skills"
shared_destination_dir=${BATMAN_SKILLS_DIR:-"$HOME/.agents/skills"}
copilot_destination_dir=${BATMAN_COPILOT_SKILLS_DIR:-"$HOME/.copilot/skills"}

mkdir -p "$shared_destination_dir" "$copilot_destination_dir"

projection_work_dir=$(mktemp -d "${TMPDIR:-/tmp}/batman-skills.XXXXXX")
trap 'rm -rf "$projection_work_dir"' EXIT HUP INT TERM

shared_installed=0
shared_unchanged=0
copilot_installed=0
copilot_updated=0
conflicts=0

is_manual_only() {
    metadata_file=$1
    [ -f "$metadata_file" ] || return 1
    grep -q '^[[:space:]]*allow_implicit_invocation:[[:space:]]*false[[:space:]]*$' "$metadata_file"
}

render_copilot_skill() {
    source_file=$1
    destination_file=$2
    manual_only=$3

    awk -v manual_only="$manual_only" '
        NR == 1 && $0 == "---" {
            in_frontmatter = 1
            print
            next
        }
        in_frontmatter && $0 == "---" {
            if (manual_only == "true") {
                print "disable-model-invocation: true"
            }
            print
            found_end = 1
            in_frontmatter = 0
            next
        }
        { print }
        END {
            if (!found_end) {
                exit 1
            }
        }
    ' "$source_file" > "$destination_file"
}

for skill_dir in "$source_dir"/*; do
    [ -d "$skill_dir" ] || continue
    [ -f "$skill_dir/SKILL.md" ] || continue

    skill_name=${skill_dir##*/}
    destination="$shared_destination_dir/$skill_name"

    if [ -L "$destination" ]; then
        link_target=$(readlink "$destination")
        if [ "$link_target" = "$skill_dir" ]; then
            printf 'shared unchanged  %s\n' "$skill_name"
            shared_unchanged=$((shared_unchanged + 1))
        else
            printf 'shared conflict   %s -> %s\n' "$skill_name" "$link_target" >&2
            conflicts=$((conflicts + 1))
        fi
    elif [ -e "$destination" ]; then
        printf 'shared conflict   %s already exists at %s\n' "$skill_name" "$destination" >&2
        conflicts=$((conflicts + 1))
    else
        ln -s "$skill_dir" "$destination"
        printf 'shared installed  %s\n' "$skill_name"
        shared_installed=$((shared_installed + 1))
    fi

    if grep -q '^disable-model-invocation:' "$skill_dir/SKILL.md"; then
        printf 'invalid    %s has harness-specific invocation metadata in SKILL.md\n' "$skill_name" >&2
        conflicts=$((conflicts + 1))
        continue
    fi

    projection_dir="$projection_work_dir/$skill_name"
    cp -R "$skill_dir" "$projection_dir"

    manual_only=false
    if is_manual_only "$skill_dir/agents/openai.yaml"; then
        manual_only=true
    fi
    render_copilot_skill "$skill_dir/SKILL.md" "$projection_dir/SKILL.md" "$manual_only"
    printf '%s\n' "$skill_dir" > "$projection_dir/.batman-source"

    copilot_destination="$copilot_destination_dir/$skill_name"
    if [ -e "$copilot_destination" ] || [ -L "$copilot_destination" ]; then
        marker="$copilot_destination/.batman-source"
        if [ ! -f "$marker" ] || [ "$(sed -n '1p' "$marker")" != "$skill_dir" ]; then
            printf 'copilot conflict  %s already exists at %s\n' "$skill_name" "$copilot_destination" >&2
            conflicts=$((conflicts + 1))
            continue
        fi

        rm -rf "$copilot_destination"
        mv "$projection_dir" "$copilot_destination"
        printf 'copilot updated    %s\n' "$skill_name"
        copilot_updated=$((copilot_updated + 1))
    else
        mv "$projection_dir" "$copilot_destination"
        printf 'copilot installed  %s\n' "$skill_name"
        copilot_installed=$((copilot_installed + 1))
    fi
done

printf '\nshared: %d installed, %d unchanged\n' "$shared_installed" "$shared_unchanged"
printf 'copilot: %d installed, %d updated\n' "$copilot_installed" "$copilot_updated"
printf 'conflicts: %d\n' "$conflicts"

if [ "$conflicts" -ne 0 ]; then
    exit 1
fi
