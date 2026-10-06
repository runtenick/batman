#!/bin/sh

set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
source_dir=${BATMAN_SOURCE_DIR:-"$repo_dir/skills"}

. "$script_dir/lib/batman-management.sh"
. "$script_dir/lib/batman-migration.sh"

usage() {
    printf '%s\n' "Usage: $0 [--group <name>]..."
    printf '\n%s\n' "Installs shared skills in ~/.agents/skills. Override with BATMAN_SKILLS_DIR."
    printf '%s\n' '       --group limits synchronization to that group; repeat to combine groups.'
}

validate_skill_groups || exit 1
target=shared
while [ "$#" -gt 0 ]; do
    case $1 in
        --group)
            if [ "$#" -lt 2 ]; then
                printf '%s\n' 'install: --group requires a value' >&2
                exit 2
            fi
            select_group "$2" || exit 2
            shift 2
            ;;
        --group=*)
            select_group "${1#--group=}" || exit 2
            shift
            ;;
        --target)
            if [ "$#" -lt 2 ]; then
                printf '%s\n' 'install: --target requires a value' >&2
                usage >&2
                exit 2
            fi
            target=$2
            shift 2
            ;;
        --target=*)
            target=${1#--target=}
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            printf 'install: unknown argument: %s\n' "$1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

case $target in
    shared|codex|copilot|portable|all) ;;
    *)
        printf 'install: invalid target: %s\n' "$target" >&2
        usage >&2
        exit 2
        ;;
esac

if [ "$target" != shared ]; then
    printf '%s\n' 'batman: --target is deprecated; using the shared skills folder.' >&2
fi

"$script_dir/check-skills.sh" "$source_dir"

projection_work_dir=$(mktemp -d "${TMPDIR:-/tmp}/batman-skills.XXXXXX")
trap 'rm -rf "$projection_work_dir"' EXIT HUP INT TERM

installed=0
updated=0
unchanged=0
preserved=0
conflicts=0

install_target() {
    target_name=$1
    destination_dir=$2
    projection_kind=$3

    mkdir -p "$destination_dir" "$projection_work_dir/$target_name"
    state_file="$destination_dir/.batman/state.tsv"

    for skill_dir in "$source_dir"/* "$source_dir"/*/*; do
        is_stable_skill_dir "$skill_dir" || continue

        skill_name=${skill_dir##*/}
        skill_selected "$skill_name" || continue
        projection_dir="$projection_work_dir/$target_name/$skill_name"
        destination="$destination_dir/$skill_name"
        source_hash=$(managed_hash "$skill_dir")

        if [ -L "$destination" ]; then
            link_target=$(readlink "$destination")
            if ! stable_source_matches "$link_target" "$skill_dir"; then
                printf '%-18s %s -> %s\n' "$target_name conflict" "$skill_name" "$link_target" >&2
                conflicts=$((conflicts + 1))
                continue
            fi

            invocation=$(state_get "$state_file" invocation "$skill_name" 2>/dev/null || existing_invocation "$projection_kind" "$destination")
            render_update_projection "$skill_dir" "$projection_dir" "$projection_kind" "$invocation"
            replace_projection "$destination" "$projection_dir"
            installed_hash=$(managed_hash "$destination")
            state_set "$state_file" invocation "$skill_name" "$invocation"
            state_set "$state_file" source-hash "$skill_name" "$source_hash"
            state_set "$state_file" installed-hash "$skill_name" "$installed_hash"
            printf '%-18s %s\n' "$target_name migrated" "$skill_name"
            updated=$((updated + 1))
            continue
        fi

        if [ -e "$destination" ]; then
            marker="$destination/.batman-source"
            if [ ! -f "$marker" ] || ! stable_source_matches "$(sed -n '1p' "$marker")" "$skill_dir"; then
                printf '%-18s %s already exists at %s\n' "$target_name conflict" "$skill_name" "$destination" >&2
                conflicts=$((conflicts + 1))
                continue
            fi

            if [ "$(sed -n '1p' "$marker")" != "$skill_dir" ]; then
                printf '%s\n%s\n' "$skill_dir" "$projection_kind" > "$marker"
            fi
            invocation=$(state_get "$state_file" invocation "$skill_name" 2>/dev/null || existing_invocation "$projection_kind" "$destination")
            current_hash=$(managed_hash "$destination")
            previous_source_hash=$(state_get "$state_file" source-hash "$skill_name" 2>/dev/null || true)
            previous_installed_hash=$(state_get "$state_file" installed-hash "$skill_name" 2>/dev/null || true)

            if [ -z "$previous_source_hash" ] || [ -z "$previous_installed_hash" ]; then
                state_set "$state_file" invocation "$skill_name" "$invocation"
                state_set "$state_file" source-hash "$skill_name" "$current_hash"
                state_set "$state_file" installed-hash "$skill_name" "$current_hash"
                printf '%-18s %s (baseline recorded; existing copy preserved)\n' "$target_name migrated" "$skill_name"
                continue
            fi

            if [ "$current_hash" != "$previous_installed_hash" ]; then
                if [ "$source_hash" != "$previous_source_hash" ]; then
                    printf '%-18s %s has local changes and a source update\n' "$target_name conflict" "$skill_name" >&2
                    conflicts=$((conflicts + 1))
                else
                    printf '%-18s %s local changes preserved\n' "$target_name preserved" "$skill_name"
                    preserved=$((preserved + 1))
                fi
                continue
            fi

            if [ "$source_hash" = "$previous_source_hash" ]; then
                printf '%-18s %s\n' "$target_name unchanged" "$skill_name"
                unchanged=$((unchanged + 1))
                continue
            fi

            render_update_projection "$skill_dir" "$projection_dir" "$projection_kind" "$invocation"
            replace_projection "$destination" "$projection_dir"
            installed_hash=$(managed_hash "$destination")
            state_set "$state_file" invocation "$skill_name" "$invocation"
            state_set "$state_file" source-hash "$skill_name" "$source_hash"
            state_set "$state_file" installed-hash "$skill_name" "$installed_hash"
            printf '%-18s %s\n' "$target_name updated" "$skill_name"
            updated=$((updated + 1))
        else
            invocation=$(state_get "$state_file" invocation "$skill_name" 2>/dev/null || default_skill_invocation "$skill_dir")
            render_update_projection "$skill_dir" "$projection_dir" "$projection_kind" "$invocation"
            mv "$projection_dir" "$destination"
            installed_hash=$(managed_hash "$destination")
            state_set "$state_file" invocation "$skill_name" "$invocation"
            state_set "$state_file" source-hash "$skill_name" "$source_hash"
            state_set "$state_file" installed-hash "$skill_name" "$installed_hash"
            printf '%-18s %s\n' "$target_name installed" "$skill_name"
            installed=$((installed + 1))
        fi
    done
}

migration_failures=0
migrate_shared_installation
if [ "$migration_failures" -ne 0 ]; then
    printf '\n%d migration conflicts; resolve these before synchronizing sources.\n' "$migration_failures" >&2
    exit 1
fi
install_target shared "$shared_destination_dir" shared

printf '\n%d installed, %d updated, %d unchanged, %d preserved, %d conflicts\n' "$installed" "$updated" "$unchanged" "$preserved" "$conflicts"
[ "$conflicts" -eq 0 ]
