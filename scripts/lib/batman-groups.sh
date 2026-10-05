#!/bin/sh

# Grouped skills live one directory below the skills root. Installations remain
# flat so agents discover each skill by name.
selected_groups=

is_stable_skill_dir() {
    [ -f "$1/SKILL.md" ] || return 1
    stable_parent=${1%/*}
    [ "$stable_parent" = "$source_dir" ] && return 0
    [ "${stable_parent%/*}" = "$source_dir" ] || return 1
    [ "$stable_parent" != "$source_dir/experimental" ] || return 1
    # An ungrouped skill may contain an upstream source/SKILL.md snapshot.
    [ ! -f "$stable_parent/SKILL.md" ]
}

# Canonical fields preserve source defaults. Omitted fields are automatic only
# with a recorded source; an unprovenanced skill falls back to manual.
default_skill_invocation() {
    default_skill_dir=$1
    default_policy=$(portable_invocation_policy "$default_skill_dir/SKILL.md")
    if [ -z "$default_policy" ] && [ -f "$default_skill_dir/source/SOURCE.md" ] &&
        [ -f "$default_skill_dir/source/SKILL.md" ]; then
        default_policy=false
    fi
    case $default_skill_dir in
        "$source_dir"/experimental/*) default_policy=${default_policy:-false} ;;
    esac
    if [ "$default_policy" = false ]; then
        printf '%s\n' automatic
    else
        printf '%s\n' manual
    fi
}

stable_skill_source() {
    for lookup_dir in "$source_dir/$1" "$source_dir"/*/"$1"; do
        is_stable_skill_dir "$lookup_dir" || continue
        printf '%s\n' "$lookup_dir"
        return 0
    done
    return 1
}

stable_source_matches() {
    [ "$1" = "$2" ] && return 0
    # Accept the previous flat source path when migrating existing installs.
    [ "$1" = "$source_dir/${2##*/}" ] &&
        [ "$(stable_skill_source "${2##*/}")" = "$2" ]
}

validate_skill_groups() {
    for validation_root in "$source_dir"/*; do
        [ -d "$validation_root" ] || continue
        [ "$validation_root" = "$source_dir/experimental" ] && continue
        [ -f "$validation_root/SKILL.md" ] && continue
        validation_group_count=0
        for validation_child in "$validation_root"/*; do
            is_stable_skill_dir "$validation_child" || continue
            validation_group_count=$((validation_group_count + 1))
        done
        if [ "$validation_group_count" -eq 0 ]; then
            printf 'invalid  %s has no SKILL.md or grouped skills\n' "${validation_root##*/}" >&2
            return 1
        fi
    done
    group_seen_skills=
    for validation_dir in "$source_dir"/* "$source_dir"/*/*; do
        is_stable_skill_dir "$validation_dir" || continue
        validation_name=${validation_dir##*/}
        case " $group_seen_skills " in
            *" $validation_name "*)
                printf 'invalid  duplicate stable skill: %s\n' "$validation_name" >&2
                return 1
                ;;
        esac
        group_seen_skills="$group_seen_skills $validation_name"
    done
    [ -f "$source_dir/groups.tsv" ] || return 0

    awk -F '\t' -v source_dir="$source_dir" '
        function invalid(message) {
            print "invalid  " message > "/dev/stderr"
            errors++
        }
        /^[[:space:]]*#/ || /^[[:space:]]*$/ { next }
        {
            if (NF != 3 || $1 !~ /^[a-z0-9]+(-[a-z0-9]+)*$/ ||
                $2 !~ /^[a-z0-9]+(-[a-z0-9]+)*$/ ||
                ($3 != "-" && $3 !~ /^[a-z0-9]+(-[a-z0-9]+)*(,[a-z0-9]+(-[a-z0-9]+)*)*$/)) {
                invalid("malformed group manifest entry at line " NR)
                next
            }
            if ($1 in groups) {
                invalid("duplicate group membership: " $1)
            }
            path = source_dir "/" $2 "/" $1 "/SKILL.md"
            if ((getline line < path) < 0) {
                invalid("unknown stable skill in group manifest: " $1)
            }
            close(path)
            groups[$1] = $2
            dependencies[$1] = $3
        }
        END {
            for (skill in dependencies) {
                if (dependencies[skill] == "-") continue
                count = split(dependencies[skill], names, ",")
                for (i = 1; i <= count; i++) {
                    dependency = names[i]
                    if (!(dependency in groups) || groups[dependency] != groups[skill]) {
                        invalid(skill " dependency " dependency " must belong to group " groups[skill])
                    }
                }
            }
            exit errors ? 1 : 0
        }
    ' "$source_dir/groups.tsv" || return 1

    for validation_dir in "$source_dir"/*/*; do
        is_stable_skill_dir "$validation_dir" || continue
        validation_name=${validation_dir##*/}
        validation_parent=${validation_dir%/*}
        if [ "$validation_parent" != "$source_dir" ] && [ -f "$source_dir/groups.tsv" ]; then
            if ! awk -F '\t' -v skill="$validation_name" -v group="${validation_parent##*/}" '
                /^[[:space:]]*#/ || /^[[:space:]]*$/ { next }
                $1 == skill && $2 == group { found = 1 }
                END { exit found ? 0 : 1 }
            ' "$source_dir/groups.tsv"; then
                printf 'invalid  %s is missing membership for directory group %s\n' "$validation_name" "${validation_parent##*/}" >&2
                return 1
            fi
        fi
    done
}

select_group() {
    case $1 in
        ''|*[!a-z0-9-]*|-*|*-)
            printf 'batman: unknown group: %s\n' "$1" >&2
            return 2
            ;;
    esac
    group_found=0
    for selection_dir in "$source_dir/$1"/*; do
        if is_stable_skill_dir "$selection_dir"; then
            group_found=1
            break
        fi
    done
    if [ "$group_found" -eq 0 ]; then
        printf 'batman: unknown group: %s\n' "$1" >&2
        return 2
    fi
    case " $selected_groups " in
        *" $1 "*) ;;
        *) selected_groups="${selected_groups:+$selected_groups }$1" ;;
    esac
}

skill_group() {
    group_source=$(stable_skill_source "$1") || return 1
    group_parent=${group_source%/*}
    [ "$group_parent" = "$source_dir" ] || printf '%s\n' "${group_parent##*/}"
}

skill_selected() {
    [ -n "$selected_groups" ] || return 0
    selected_skill_group=$(skill_group "$1")
    [ -n "$selected_skill_group" ] || return 1
    case " $selected_groups " in
        *" $selected_skill_group "*) return 0 ;;
        *) return 1 ;;
    esac
}

list_skill_groups() {
    validate_skill_groups || return 1
    printf '%-18s %s\n' Group Skill
    for group_skill_dir in "$source_dir"/* "$source_dir"/*/*; do
        is_stable_skill_dir "$group_skill_dir" || continue
        group_skill_name=${group_skill_dir##*/}
        listed_group=$(skill_group "$group_skill_name")
        printf '%s\t%s\n' "${listed_group:-ungrouped}" "$group_skill_name"
    done | LC_ALL=C sort | while IFS="$(printf '\t')" read -r group_first group_second; do
        printf '%-18s %s\n' "$group_first" "$group_second"
    done
}
