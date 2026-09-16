#!/bin/sh

state_get() {
    state_file=$1
    record=$2
    skill_name=$3

    [ -f "$state_file" ] || return 1

    awk -F '\t' -v wanted_record="$record" -v wanted_skill="$skill_name" '
        $1 == wanted_record && $2 == wanted_skill {
            print $3
            found = 1
            exit
        }
        END {
            if (!found) {
                exit 1
            }
        }
    ' "$state_file"
}

state_set() {
    state_file=$1
    record=$2
    skill_name=$3
    value=$4
    state_dir=${state_file%/*}

    mkdir -p "$state_dir"
    state_tmp=$(mktemp "$state_dir/.state.tsv.XXXXXX")

    if [ -f "$state_file" ]; then
        awk -F '\t' -v OFS='\t' \
            -v wanted_record="$record" \
            -v wanted_skill="$skill_name" \
            -v replacement="$value" '
            BEGIN { found = 0 }
            $1 == wanted_record && $2 == wanted_skill {
                if (!found) {
                    print wanted_record, wanted_skill, replacement
                    found = 1
                }
                next
            }
            { print }
            END {
                if (!found) {
                    print wanted_record, wanted_skill, replacement
                }
            }
        ' "$state_file" > "$state_tmp"
    else
        {
            printf '%s\n' '# batman-state-v1'
            printf '%s\n' '# record<TAB>skill<TAB>value'
            printf '%s\t%s\t%s\n' "$record" "$skill_name" "$value"
        } > "$state_tmp"
    fi

    mv "$state_tmp" "$state_file"
}

state_delete_skill() {
    state_file=$1
    skill_name=$2

    [ -f "$state_file" ] || return 0

    state_dir=${state_file%/*}
    state_tmp=$(mktemp "$state_dir/.state.tsv.XXXXXX")
    awk -F '\t' -v wanted_skill="$skill_name" '
        $2 != wanted_skill { print }
    ' "$state_file" > "$state_tmp"
    mv "$state_tmp" "$state_file"
}
