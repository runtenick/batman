#!/bin/sh

# Each skill runs in a subshell: metadata and hash helpers use shell globals.
migrate_shared_skill() (
    migration_old=$1
    migration_name=${migration_old##*/}
    [ -z "${migration_only_skill:-}" ] || [ "$migration_name" = "$migration_only_skill" ] || return 0
    migration_marker="$migration_old/.batman-source"
    if [ -f "$migration_marker" ]; then
        migration_source=$(sed -n '1p' "$migration_marker")
        migration_kind=$(sed -n '2p' "$migration_marker")
    elif [ -L "$migration_old" ]; then
        migration_source=$(readlink "$migration_old")
        migration_canonical=$(stable_skill_source "$migration_name" 2>/dev/null || printf '%s\n' "$source_dir/experimental/$migration_name")
        stable_source_matches "$migration_source" "$migration_canonical" || return 0
        if [ "${migration_old%/*}" = "$copilot_destination_dir" ]; then
            migration_kind=portable
        else
            migration_kind=codex
        fi
    else
        return 0
    fi
    case $migration_source in
        "$source_dir"/*) ;;
        *) return 0 ;;
    esac
    [ "${migration_source##*/}" = "$migration_name" ] || return 0
    if [ -n "$selected_groups" ]; then
        skill_selected "$migration_name" || return 0
    fi
    [ -f "$migration_old/SKILL.md" ] || return 0
    migration_new="$shared_destination_dir/$migration_name"
    migration_old_root=${migration_old%/*}
    migration_old_state="$migration_old_root/.batman/state.tsv"
    migration_state="$shared_destination_dir/.batman/state.tsv"
    if [ -L "$migration_old" ] && [ ! -f "$migration_marker" ]; then
        migration_mode=$(state_get "$migration_old_state" invocation "$migration_name" 2>/dev/null || default_skill_invocation "$migration_canonical")
    else
        migration_mode=$(state_get "$migration_old_state" invocation "$migration_name" 2>/dev/null || existing_invocation "$migration_kind" "$migration_old")
    fi
    if [ "$migration_kind" = shared ]; then
        migration_mode=$(existing_invocation shared "$migration_old")
    fi
    if [ "$migration_kind" = shared ] && [ "$migration_old" = "$migration_new" ]; then
        write_invocation shared "$migration_old" "$migration_mode" || return 1
        state_set "$migration_state" invocation "$migration_name" "$migration_mode" || return 1
        return 0
    fi
    migration_old_hash=$(managed_hash "$migration_old")
    migration_baseline=$(state_get "$migration_old_state" installed-hash "$migration_name" 2>/dev/null || true)
    migration_source_hash=$(state_get "$migration_old_state" source-hash "$migration_name" 2>/dev/null || printf '%s\n' "$migration_old_hash")
    migration_canonical=$(stable_skill_source "$migration_name" 2>/dev/null || printf '%s\n' "$migration_source")
    migration_stage=$(mktemp -d "$projection_work_dir/migrate.XXXXXX") || return 1
    cp -R "$migration_old"/. "$migration_stage"/ || return 1
    # Supplement portable copies with the same UI metadata as shared copies.
    if [ ! -f "$migration_stage/agents/openai.yaml" ]; then
        migration_metadata=$(codex_metadata_source "$migration_canonical")
        if [ -f "$migration_metadata" ]; then
            mkdir -p "$migration_stage/agents" || return 1
            cp "$migration_metadata" "$migration_stage/agents/openai.yaml" || return 1
        fi
    fi
    write_invocation shared "$migration_stage" "$migration_mode" || return 1
    printf '%s\nshared\n' "$migration_canonical" > "$migration_stage/.batman-source" || return 1
    migration_new_hash=$(managed_hash "$migration_stage")
    if [ -z "$migration_baseline" ] && [ -f "$migration_canonical/SKILL.md" ]; then
        # Without a historical baseline, compare against a pristine current
        # projection. Older or edited content remains protected as modified.
        migration_reference=$(mktemp -d "$projection_work_dir/reference.XXXXXX") || return 1
        render_update_projection "$migration_canonical" "$migration_reference" shared "$migration_mode" || return 1
        migration_baseline=$(managed_hash "$migration_reference")
        migration_source_hash=$(managed_hash "$migration_canonical")
    fi

    if [ "$migration_old" != "$migration_new" ] && { [ -e "$migration_new" ] || [ -L "$migration_new" ]; }; then
        if [ ! -f "$migration_new/.batman-source" ] || ! stable_source_matches "$(sed -n '1p' "$migration_new/.batman-source")" "$migration_canonical"; then
            printf 'migration conflict: %s already exists at %s; preserved %s\n' "$migration_name" "$migration_new" "$migration_old" >&2
            return 1
        fi
        migration_new_mode=$(state_get "$migration_state" invocation "$migration_name" 2>/dev/null || existing_invocation "$(sed -n '2p' "$migration_new/.batman-source")" "$migration_new")
        if [ "$migration_mode" != "$migration_new_mode" ] || [ "$migration_new_hash" != "$(managed_hash "$migration_new")" ]; then
            printf 'migration conflict: %s differs in content or invocation preference:\n  %s\n  %s\nBoth copies preserved.\n' "$migration_name" "$migration_new" "$migration_old" >&2
            return 1
        fi
        # Equal copies need only the legacy installation archived.
        migration_replace=0
    else
        migration_replace=1
    fi

    mkdir -p "$shared_destination_dir" "$archive_dir" || return 1
    migration_archive=$(mktemp -d "$archive_dir/$migration_name.XXXXXX") || return 1
    cp -R "$migration_old"/. "$migration_archive"/skill || return 1
    if [ -f "$migration_old_state" ]; then
        awk -F '\t' -v name="$migration_name" '$2 == name' "$migration_old_state" > "$migration_archive/state.tsv" || return 1
    fi
    printf '%s\n' "$migration_old" > "$migration_archive/location" || return 1
    if [ "$migration_replace" -eq 1 ]; then
        if [ "$migration_old" = "$migration_new" ]; then
            replace_projection "$migration_new" "$migration_stage" || return 1
        else
            mv "$migration_stage" "$migration_new" || return 1
        fi
        if [ -n "$migration_baseline" ] && [ "$migration_baseline" = "$migration_old_hash" ]; then
            migration_baseline=$migration_new_hash
        fi
        state_set "$migration_state" invocation "$migration_name" "$migration_mode" || return 1
        state_set "$migration_state" source-hash "$migration_name" "$migration_source_hash" || return 1
        if [ -n "$migration_baseline" ]; then
            state_set "$migration_state" installed-hash "$migration_name" "$migration_baseline" || return 1
        fi
    fi
    if [ "$migration_old" != "$migration_new" ]; then
        rm -rf "$migration_old" || return 1
        state_delete_skill "$migration_old_state" "$migration_name"
    fi
    printf 'shared migrated    %s (previous copy archived at %s)\n' "$migration_name" "$migration_archive"
)

migrate_shared_installation() {
    archive_dir=${BATMAN_ARCHIVE_DIR:-"$(dirname -- "$shared_destination_dir")/.batman-archive"}
    # Normalize the shared folder first so comparisons use the same metadata.
    migration_roots="$projection_work_dir/migration-roots"
    {
        printf '%s\n' "$shared_destination_dir"
        if [ "$shared_destination_dir" = "$HOME/.agents/skills" ]; then
            printf '%s\n' "$codex_destination_dir" "$copilot_destination_dir" "$portable_destination_dir"
        else
            # A custom destination must not pull skills out of the real home.
            [ -z "${BATMAN_CODEX_SKILLS_DIR:-}" ] || printf '%s\n' "$codex_destination_dir"
            [ -z "${BATMAN_COPILOT_SKILLS_DIR:-}" ] || printf '%s\n' "$copilot_destination_dir"
            [ -z "${BATMAN_PORTABLE_SKILLS_DIR:-}" ] || printf '%s\n' "$portable_destination_dir"
        fi
    } | awk '!seen[$0]++' > "$migration_roots"
    while IFS= read -r migration_root; do
        [ -d "$migration_root" ] || continue
        # Avoid aliases of the shared folder and duplicate configured roots.
        migration_real=$(CDPATH= cd -- "$migration_root" && pwd -P)
        if [ -f "$projection_work_dir/migration-seen" ] && grep -Fx "$migration_real" "$projection_work_dir/migration-seen" >/dev/null; then
            continue
        fi
        printf '%s\n' "$migration_real" >> "$projection_work_dir/migration-seen"
        for migration_entry in "$migration_root"/*; do
            if ! migrate_shared_skill "$migration_entry"; then
                migration_failures=$((migration_failures + 1))
            fi
        done
    done < "$migration_roots"
}
