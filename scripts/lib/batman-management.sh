#!/bin/sh

# shellcheck source=scripts/lib/batman-state.sh
. "$script_dir/lib/batman-state.sh"

source_dir=${BATMAN_SOURCE_DIR:-"$repo_dir/skills"}
codex_destination_dir=${BATMAN_CODEX_SKILLS_DIR:-${BATMAN_SKILLS_DIR:-"$HOME/.agents/skills"}}
copilot_destination_dir=${BATMAN_COPILOT_SKILLS_DIR:-"$HOME/.copilot/skills"}
portable_destination_dir=${BATMAN_PORTABLE_SKILLS_DIR:-${BATMAN_SKILLS_DIR:-"$HOME/.agents/skills"}}

hash_stdin() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum | awk '{print $1}'
        return
    fi

    if command -v shasum >/dev/null 2>&1; then
        shasum -a 256 | awk '{print $1}'
        return
    fi

    printf '%s\n' 'batman: sha256sum or shasum is required' >&2
    exit 2
}

hash_file() {
    hash_stdin < "$1"
}

managed_hash() {
    skill_dir=$1

    (
        cd "$skill_dir"
        find . -type f ! -name '.batman-source' | LC_ALL=C sort | while IFS= read -r relative_path; do
            case $relative_path in
                ./SKILL.md)
                    normalized_hash=$(awk '!/^disable-model-invocation:[[:space:]]*/' "$relative_path" | hash_stdin)
                    ;;
                ./agents/openai.yaml)
                    normalized_hash=$(awk '
                        BEGIN { in_policy = 0 }
                        /^policy:[[:space:]]*(#.*)?$/ {
                            in_policy = 1
                            next
                        }
                        in_policy && /^[^[:space:]#]/ {
                            in_policy = 0
                        }
                        !in_policy { print }
                    ' "$relative_path" | hash_stdin)
                    ;;
                *)
                    normalized_hash=$(hash_file "$relative_path")
                    ;;
            esac

            printf '%s\t%s\n' "$relative_path" "$normalized_hash"
        done
    ) | hash_stdin
}

portable_invocation_policy() {
    awk '
        NR == 1 && $0 == "---" { in_frontmatter = 1; next }
        in_frontmatter && $0 == "---" { exit }
        in_frontmatter && /^disable-model-invocation:[[:space:]]*/ {
            line = $0
            sub(/^disable-model-invocation:[[:space:]]*/, "", line)
            sub(/[[:space:]]*(#.*)?$/, "", line)
            print line
            exit
        }
    ' "$1"
}

codex_invocation_policy() {
    awk '
        /^policy:[[:space:]]*(#.*)?$/ {
            in_policy = 1
            next
        }
        in_policy && /^[[:space:]]+allow_implicit_invocation:[[:space:]]*/ {
            line = $0
            sub(/^[[:space:]]+allow_implicit_invocation:[[:space:]]*/, "", line)
            sub(/[[:space:]]*(#.*)?$/, "", line)
            print line
            exit
        }
        in_policy && /^[^[:space:]#]/ {
            exit
        }
    ' "$1"
}

existing_invocation() {
    projection_kind=$1
    skill_dir=$2

    if [ "$projection_kind" = codex ]; then
        if [ -f "$skill_dir/agents/openai.yaml" ]; then
            policy=$(codex_invocation_policy "$skill_dir/agents/openai.yaml")
            if [ "$policy" = true ]; then
                printf '%s\n' automatic
                return
            fi
            if [ "$policy" = false ]; then
                printf '%s\n' manual
                return
            fi
        fi
    elif [ -f "$skill_dir/SKILL.md" ]; then
        policy=$(portable_invocation_policy "$skill_dir/SKILL.md") || policy=true
        if [ "$policy" = false ]; then
            printf '%s\n' automatic
            return
        fi
    fi

    printf '%s\n' manual
}

write_codex_invocation() {
    metadata_file=$1
    allow_implicit=$2
    metadata_tmp=$(mktemp "${metadata_file}.XXXXXX")

    if [ -f "$metadata_file" ]; then
        awk -v allow_implicit="$allow_implicit" '
            /^policy:[[:space:]]*(#.*)?$/ {
                found_policy = 1
                print
                print "  allow_implicit_invocation: " allow_implicit
                in_policy = 1
                next
            }
            in_policy && /^[^[:space:]#]/ {
                in_policy = 0
            }
            in_policy { next }
            { print }
            END {
                if (!found_policy) {
                    print "policy:"
                    print "  allow_implicit_invocation: " allow_implicit
                }
            }
        ' "$metadata_file" > "$metadata_tmp"
    else
        {
            printf '%s\n' 'interface:'
            printf '%s\n' '  # Batman-generated invocation policy'
            printf '%s\n' 'policy:'
            printf '  allow_implicit_invocation: %s\n' "$allow_implicit"
        } > "$metadata_tmp"
    fi

    mv "$metadata_tmp" "$metadata_file"
}

write_portable_invocation() {
    skill_file=$1
    invocation=$2
    skill_tmp=$(mktemp "${skill_file}.XXXXXX")

    awk -v invocation="$invocation" '
        NR == 1 && $0 == "---" {
            in_frontmatter = 1
            print
            next
        }
        in_frontmatter && $0 == "---" {
            if (!found_invocation) {
                if (invocation == "automatic") {
                    print "disable-model-invocation: false"
                } else {
                    print "disable-model-invocation: true"
                }
            }
            in_frontmatter = 0
            print
            next
        }
        in_frontmatter && /^disable-model-invocation:[[:space:]]*/ {
            if (invocation == "automatic") {
                print "disable-model-invocation: false"
            } else {
                print "disable-model-invocation: true"
            }
            found_invocation = 1
            next
        }
        { print }
    ' "$skill_file" > "$skill_tmp"

    mv "$skill_tmp" "$skill_file"
}

write_invocation() {
    projection_kind=$1
    skill_dir=$2
    invocation=$3

    if [ "$projection_kind" = codex ]; then
        mkdir -p "$skill_dir/agents"
        if [ "$invocation" = automatic ]; then
            write_codex_invocation "$skill_dir/agents/openai.yaml" true
        else
            write_codex_invocation "$skill_dir/agents/openai.yaml" false
        fi
    else
        write_portable_invocation "$skill_dir/SKILL.md" "$invocation"
    fi
}

render_codex_skill() {
    source_file=$1
    destination_file=$2

    awk '
        NR == 1 && $0 == "---" {
            in_frontmatter = 1
            print
            next
        }
        in_frontmatter && $0 == "---" {
            in_frontmatter = 0
            print
            next
        }
        in_frontmatter && /^disable-model-invocation:[[:space:]]*/ { next }
        { print }
    ' "$source_file" > "$destination_file"
}

render_update_projection() {
    skill_source=$1
    projection_dir=$2
    projection_kind=$3
    invocation=$4

    mkdir -p "$projection_dir"
    cp -R "$skill_source"/. "$projection_dir"/

    if [ "$projection_kind" = codex ]; then
        render_codex_skill "$skill_source/SKILL.md" "$projection_dir/SKILL.md.tmp"
        mv "$projection_dir/SKILL.md.tmp" "$projection_dir/SKILL.md"
        write_invocation codex "$projection_dir" "$invocation"
    else
        write_portable_invocation "$projection_dir/SKILL.md" "$invocation"
    fi

    printf '%s\n%s\n' "$skill_source" "$projection_kind" > "$projection_dir/.batman-source"
}

replace_projection() {
    destination=$1
    projection_dir=$2
    backup_parent=$(mktemp -d "${destination}.backup.XXXXXX")

    if ! mv "$destination" "$backup_parent/original"; then
        rm -rf "$backup_parent"
        return 1
    fi

    if mv "$projection_dir" "$destination"; then
        rm -rf "$backup_parent"
        return 0
    fi

    mv "$backup_parent/original" "$destination"
    rm -rf "$backup_parent"
    return 1
}

confirm_update() {
    skill_name=$1
    target_name=$2
    reason=$3

    printf '%s %s %s. Replace it with the current Batman version? [y/N] ' "$target_name" "$skill_name" "$reason" >&2
    answer=
    IFS= read -r answer || true
    case $answer in
        y|Y|yes|YES|Yes) return 0 ;;
        *) return 1 ;;
    esac
}

update_skill_on_target() {
    skill_name=$1
    target_name=$2
    destination_dir=$(target_destination "$target_name")
    projection_kind=$(target_projection_kind "$target_name")
    destination="$destination_dir/$skill_name"
    state_file="$destination_dir/.batman/state.tsv"
    skill_source="$source_dir/$skill_name"

    if [ ! -d "$destination" ] || [ ! -f "$destination/.batman-source" ] || [ "$(sed -n '1p' "$destination/.batman-source")" != "$skill_source" ]; then
        printf '%s %s is not an installed Batman skill; run sync first\n' "$target_name" "$skill_name" >&2
        return 1
    fi

    invocation=$(existing_invocation "$projection_kind" "$destination")
    source_hash=$(managed_hash "$skill_source")
    current_hash=$(managed_hash "$destination")
    previous_source_hash=$(state_get "$state_file" source-hash "$skill_name" 2>/dev/null || true)
    previous_installed_hash=$(state_get "$state_file" installed-hash "$skill_name" 2>/dev/null || true)
    reason=

    if [ -z "$previous_source_hash" ] || [ -z "$previous_installed_hash" ]; then
        reason='has no recorded baseline'
    elif [ "$current_hash" != "$previous_installed_hash" ]; then
        reason='has local changes'
    elif [ "$source_hash" = "$previous_source_hash" ]; then
        printf '%s %s is already current\n' "$target_name" "$skill_name"
        return 0
    fi

    if [ -n "$reason" ] && ! confirm_update "$skill_name" "$target_name" "$reason"; then
        printf '%s %s preserved\n' "$target_name" "$skill_name"
        return 0
    fi

    projection_dir="$management_work_dir/$target_name/$skill_name"
    render_update_projection "$skill_source" "$projection_dir" "$projection_kind" "$invocation"
    if ! replace_projection "$destination" "$projection_dir"; then
        printf '%s %s could not be replaced\n' "$target_name" "$skill_name" >&2
        return 1
    fi

    installed_hash=$(managed_hash "$destination")
    state_set "$state_file" invocation "$skill_name" "$invocation"
    state_set "$state_file" source-hash "$skill_name" "$source_hash"
    state_set "$state_file" installed-hash "$skill_name" "$installed_hash"
    printf '%s %s updated\n' "$target_name" "$skill_name"
}

target_destination() {
    case $1 in
        codex) printf '%s\n' "$codex_destination_dir" ;;
        copilot) printf '%s\n' "$copilot_destination_dir" ;;
        portable) printf '%s\n' "$portable_destination_dir" ;;
    esac
}

target_projection_kind() {
    if [ "$1" = codex ]; then
        printf '%s\n' codex
    else
        printf '%s\n' portable
    fi
}

target_list() {
    case $1 in
        codex|copilot|portable)
            printf '%s\n' "$1"
            ;;
        all)
            printf '%s\n' codex copilot
            ;;
    esac
}

validate_target() {
    case $1 in
        codex|copilot|portable|all) return 0 ;;
        *)
            printf 'batman: invalid target: %s\n' "$1" >&2
            return 1
            ;;
    esac
}

validate_skill() {
    skill_name=$1

    case $skill_name in
        ''|.|..|*/*)
            printf 'batman: invalid skill name: %s\n' "$skill_name" >&2
            return 1
            ;;
    esac

    if [ ! -f "$source_dir/$skill_name/SKILL.md" ]; then
        printf 'batman: unknown skill: %s\n' "$skill_name" >&2
        return 1
    fi
}

status_target() {
    target_name=$1
    destination_dir=$(target_destination "$target_name")
    projection_kind=$(target_projection_kind "$target_name")
    state_file="$destination_dir/.batman/state.tsv"

    for skill_dir in "$source_dir"/*; do
        [ -d "$skill_dir" ] || continue
        [ -f "$skill_dir/SKILL.md" ] || continue

        skill_name=${skill_dir##*/}
        destination="$destination_dir/$skill_name"
        source_hash=$(managed_hash "$skill_dir")
        invocation=manual
        local_state=missing
        update_state=current

        if [ -e "$destination" ] || [ -L "$destination" ]; then
            if [ ! -d "$destination" ] || [ ! -f "$destination/.batman-source" ] || [ "$(sed -n '1p' "$destination/.batman-source")" != "$skill_dir" ]; then
                invocation=unknown
                local_state=conflict
                update_state=unknown
            else
                invocation=$(existing_invocation "$projection_kind" "$destination")
                previous_source_hash=$(state_get "$state_file" source-hash "$skill_name" 2>/dev/null || true)
                previous_installed_hash=$(state_get "$state_file" installed-hash "$skill_name" 2>/dev/null || true)

                if [ -z "$previous_source_hash" ] || [ -z "$previous_installed_hash" ]; then
                    local_state=untracked
                    update_state=unknown
                else
                    current_hash=$(managed_hash "$destination")
                    if [ "$current_hash" != "$previous_installed_hash" ]; then
                        local_state=modified
                        if [ "$source_hash" != "$previous_source_hash" ]; then
                            update_state=available
                        else
                            update_state=current
                        fi
                    elif [ "$source_hash" != "$previous_source_hash" ]; then
                        local_state=clean
                        update_state=available
                    else
                        local_state=clean
                        update_state=current
                    fi
                fi
            fi
        fi

        printf '%-18s %-16s %-12s %-12s %s\n' "$skill_name" "$target_name" "$invocation" "$local_state" "$update_state"
    done
}

set_skill_invocation() {
    skill_name=$1
    invocation=$2
    target_name=$3
    destination_dir=$(target_destination "$target_name")
    projection_kind=$(target_projection_kind "$target_name")
    destination="$destination_dir/$skill_name"
    state_file="$destination_dir/.batman/state.tsv"

    if [ ! -d "$destination" ] || [ ! -f "$destination/.batman-source" ] || [ "$(sed -n '1p' "$destination/.batman-source")" != "$source_dir/$skill_name" ]; then
        printf '%s %s is not an installed Batman skill; run sync first\n' "$target_name" "$skill_name" >&2
        return 1
    fi

    write_invocation "$projection_kind" "$destination" "$invocation"
    state_set "$state_file" invocation "$skill_name" "$invocation"
    printf '%s %s set to %s\n' "$target_name" "$skill_name" "$invocation"
}
