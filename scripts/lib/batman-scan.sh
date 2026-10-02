#!/bin/sh

# Installation inventory only: these conventions do not establish runtime
# discovery, precedence, enablement, or whether instructions were loaded.

scan_loading_indicator() {
    trap 'exit 0' HUP INT TERM
    while :; do
        for scan_frame in '|' '/' '-' '\'; do
            printf '\rScanning skills... %s' "$scan_frame" >&2
            sleep 0.2
        done
    done
}

scan_start_loading() {
    scan_spinner_pid=
    # Keep both piped reports and redirected diagnostics free of animation.
    if [ -t 1 ] && [ -t 2 ]; then
        scan_loading_indicator &
        scan_spinner_pid=$!
        trap 'scan_stop_loading; rm -rf "$management_work_dir"' EXIT
        trap 'exit 129' HUP
        trap 'exit 130' INT
        trap 'exit 143' TERM
    fi
}

scan_stop_loading() {
    if [ -n "${scan_spinner_pid:-}" ]; then
        kill "$scan_spinner_pid" 2>/dev/null || :
        wait "$scan_spinner_pid" 2>/dev/null || :
        scan_spinner_pid=
        printf '\r\033[2K' >&2
    fi
}

scan_absolute_dir() {
    (CDPATH= cd -- "$1" 2>/dev/null && pwd -P)
}

scan_add_global_root() {
    [ -d "$1" ] || return 0
    scan_root=$(scan_absolute_dir "$1") || return 0
    printf '%s\t%s\n' "$scan_root" "$2" >> "$scan_roots"
}

scan_default_dir() {
    scan_start=$(pwd -P)
    scan_parent=$scan_start
    while :; do
        if [ -f "$scan_parent/.git/HEAD" ] ||
            { [ -f "$scan_parent/.git" ] && LC_ALL=C grep '^gitdir: ' "$scan_parent/.git" >/dev/null 2>&1; }; then
            printf '%s\n' "$scan_parent"
            return
        fi
        [ "$scan_parent" != / ] || break
        scan_parent=${scan_parent%/*}
        scan_parent=${scan_parent:-/}
    done
    printf '%s\n' "$scan_start"
}

scan_add_candidate() {
    # Resolve the containing root, not the skill folder: a linked installation
    # and its source are separate copies, but aliases of one root are not.
    scan_candidate_dir=${1%/SKILL.md}
    scan_candidate_root=$(scan_absolute_dir "${scan_candidate_dir%/*}") || return 0
    scan_candidate_scope=Unknown
    scan_candidate_convention=-
    scan_global=$(BATMAN_SCAN_ROOT="$scan_candidate_root" awk -F '\t' '
        $1 == ENVIRON["BATMAN_SCAN_ROOT"] {
            if (index($2, "Codex")) codex = 1
            if (index($2, "Copilot")) copilot = 1
        }
        END {
            if (codex && copilot) print "Codex, Copilot"
            else if (codex) print "Codex"
            else if (copilot) print "Copilot"
        }
    ' "$scan_roots")
    if [ -n "$scan_global" ]; then
        scan_candidate_scope=Global
        scan_candidate_convention=$scan_global
    else
        # Use the installation path for scope even if the root is a link.
        case ${scan_candidate_dir%/*} in
            */.agents/skills) scan_candidate_scope=Project; scan_candidate_convention='Codex, Copilot' ;;
            */.github/skills|*/.claude/skills) scan_candidate_scope=Project; scan_candidate_convention=Copilot ;;
        esac
    fi
    printf '%s/%s\t%s\t%s\t%s\n' "$scan_candidate_root" "${scan_candidate_dir##*/}" \
        "$scan_candidate_dir" "$scan_candidate_scope" "$scan_candidate_convention" >> "$scan_candidates"
}

scan_skill_name() {
    # Read only a scalar name in frontmatter, never instruction body text.
    # Fall back to the directory name for missing or non-scalar metadata.
    awk '
        NR == 1 { if ($0 != "---" && $0 != "---\r") exit; next }
        /^---\r?$/ { exit }
        /^name:[[:space:]]*/ {
            sub(/^name:[[:space:]]*/, "")
            sub(/\r$/, "")
            sub(/[[:space:]]+$/, "")
            if ($0 ~ /^".*"$/ || $0 ~ /^\047.*\047$/) {
                print substr($0, 2, length($0) - 2)
            } else if ($0 !~ /^[>|[{&*!]/ && length($0)) {
                sub(/[[:space:]]+#.*$/, "")
                print
            }
            exit
        }
    ' "$1" 2>/dev/null
}

run_scan() {
    scan_dir=
    scan_include_unknown=0
    scan_positional=0
    while [ "$#" -gt 0 ]; do
        case $1 in
            --include-unknown) scan_include_unknown=1 ;;
            -h|--help)
                printf '%s\n' 'Usage: batman scan [<dir>] [--include-unknown]'
                return 0
                ;;
            --)
                shift
                if [ "$#" -ne 1 ] || [ "$scan_positional" -eq 1 ]; then
                    printf '%s\n' 'batman: scan expects at most one directory' >&2
                    return 2
                fi
                scan_dir=$1
                scan_positional=1
                break
                ;;
            -*)
                printf 'batman: unknown scan argument: %s\n' "$1" >&2
                return 2
                ;;
            *)
                if [ "$scan_positional" -eq 1 ]; then
                    printf '%s\n' 'batman: scan expects at most one directory' >&2
                    return 2
                fi
                scan_dir=$1
                scan_positional=1
                ;;
        esac
        shift
    done
    if [ "$scan_positional" -eq 0 ]; then
        scan_dir=$(scan_default_dir)
    fi
    if ! scan_dir=$(scan_absolute_dir "$scan_dir"); then
        printf '%s\n' 'batman: scan requires an accessible directory' >&2
        return 2
    fi

    scan_start_loading
    scan_roots="$management_work_dir/scan-roots.tsv"
    scan_candidates="$management_work_dir/scan-candidates"
    scan_rows="$management_work_dir/scan-rows.tsv"
    scan_errors="$management_work_dir/scan-errors"
    : > "$scan_roots"
    : > "$scan_candidates"
    : > "$scan_rows"
    : > "$scan_errors"
    scan_add_global_root "$HOME/.agents/skills" 'Codex, Copilot'
    scan_add_global_root "$HOME/.copilot/skills" Copilot
    scan_add_global_root /etc/codex/skills Codex
    # Honor Batman destinations without treating the shared default as Codex-only.
    scan_add_global_root "$codex_destination_dir" Codex
    scan_add_global_root "$copilot_destination_dir" Copilot

    scan_tab=$(printf '\t')
    while IFS="$scan_tab" read -r scan_root scan_convention; do
        # Shell globs follow installed skill-directory symlinks, while retaining
        # the installation path that determines scope.
        for scan_file in "$scan_root"/*/SKILL.md "$scan_root"/.[!.]*/SKILL.md "$scan_root"/..?*/SKILL.md; do
            [ -f "$scan_file" ] || continue
            scan_add_candidate "$scan_file"
        done
    done < "$scan_roots"

    # Do not follow arbitrary directory links or walk Git object stores. Keep
    # unknown source/examples in the count rather than guessing their scope.
    scan_incomplete=0
    if ! find "$scan_dir" -name .git -type d -prune -o \
        -name SKILL.md \( -type f -o -type l \) -print \
        -o -type l -print > "$management_work_dir/scan-found" 2> "$scan_errors"; then
        scan_incomplete=1
    fi
    while IFS= read -r scan_found; do
        if [ "${scan_found##*/}" = SKILL.md ]; then
            [ -f "$scan_found" ] || continue
            scan_add_candidate "$scan_found"
        elif [ -f "$scan_found/SKILL.md" ]; then
            scan_add_candidate "$scan_found/SKILL.md"
        elif [ -d "$scan_found" ]; then
            # Follow links only when they are convention roots, never arbitrary
            # project links. This also avoids symlink cycles during recursion.
            case $scan_found in
                */.agents/skills|*/.github/skills|*/.claude/skills)
                    for scan_file in "$scan_found"/*/SKILL.md; do
                        [ -f "$scan_file" ] || continue
                        scan_add_candidate "$scan_file"
                    done
                    ;;
            esac
        fi
    done < "$management_work_dir/scan-found"
    awk -F '\t' '!seen[$1]++' "$scan_candidates" > "$management_work_dir/scan-sorted"

    while IFS="$scan_tab" read -r scan_identity scan_location scan_scope scan_convention; do
        scan_name=$(scan_skill_name "$scan_location/SKILL.md")
        scan_name=${scan_name:-${scan_location##*/}}
        printf '%s\t%s\t%s\t%s\n' "$scan_name" "$scan_scope" "$scan_convention" "$scan_location" >> "$scan_rows"
    done < "$management_work_dir/scan-sorted"

    scan_stop_loading
    LC_ALL=C sort "$scan_rows" | awk -F '\t' -v include_unknown="$scan_include_unknown" '
        {
            rows[NR] = $0
            if ($2 == "Unknown") unknown++
            else {
                known++
                if (index($3, "Codex")) codex = 1
                if (index($3, "Copilot")) copilot = 1
            }
        }
        END {
            multiple = codex && copilot
            if (multiple) printf "%-24s %-10s %-18s %s\n", "Skill", "Scope", "Convention", "Location"
            else printf "%-24s %-10s %s\n", "Skill", "Scope", "Location"
            for (i = 1; i <= NR; i++) {
                split(rows[i], row, "\t")
                if (row[2] == "Unknown" && !include_unknown) continue
                if (multiple) printf "%-24s %-10s %-18s %s\n", row[1], row[2], row[3], row[4]
                else printf "%-24s %-10s %s\n", row[1], row[2], row[4]
            }
            if (!known) print "No skills found in recognized installation locations."
            printf "\n%d skills found outside recognized installation locations.\n", unknown
            if (unknown && !include_unknown) print "Use --include-unknown to view them."
        }
    '
    if [ "$scan_incomplete" -eq 1 ]; then
        printf '%s\n' 'batman: scan incomplete; some paths could not be read:' >&2
        cat "$scan_errors" >&2
        return 1
    fi
}
