#!/bin/sh

set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
source_dir=${1:-"$repo_dir/skills"}

# shellcheck source=scripts/lib/batman-groups.sh
. "$script_dir/lib/batman-groups.sh"
validate_skill_groups || exit 1

errors=0
skills_checked=0

hash_stdin() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum | awk '{print $1}'
        return
    fi

    if command -v shasum >/dev/null 2>&1; then
        shasum -a 256 | awk '{print $1}'
        return
    fi

    printf '%s\n' 'check-skills: sha256sum or shasum is required' >&2
    exit 2
}

hash_file() {
    hash_stdin < "$1"
}

raw_skill_hash() {
    skill_dir=$1

    (
        cd "$skill_dir"
        find . -type f | LC_ALL=C sort | while IFS= read -r relative_path; do
            printf '%s\t%s\n' "$relative_path" "$(hash_file "$relative_path")"
        done
    ) | hash_stdin
}

portable_invocation_policy() {
    awk -v allow_missing="${2:-false}" '
        NR == 1 && $0 == "---" {
            in_frontmatter = 1
            next
        }
        in_frontmatter && $0 == "---" {
            in_frontmatter = 0
            if (count == 0 && allow_missing == "true") {
                valid = 1
                print "false"
                exit 0
            }
            if (count == 1 && (value == "true" || value == "false")) {
                valid = 1
                print value
                exit 0
            }
            exit 1
        }
        in_frontmatter && /^disable-model-invocation:[[:space:]]*/ {
            line = $0
            sub(/^disable-model-invocation:[[:space:]]*/, "", line)
            sub(/[[:space:]]*(#.*)?$/, "", line)
            count++
            value = line
        }
        END {
            if (!valid) {
                exit 1
            }
        }
    ' "$1"
}

has_codex_invocation_policy() {
    awk '
        /^[^[:space:]#]/ {
            in_policy = ($0 ~ /^policy:[[:space:]]*(#.*)?$/)
        }
        in_policy && /^[[:space:]]+allow_implicit_invocation:[[:space:]]*/ {
            found = 1
        }
        END {
            exit found ? 0 : 1
        }
    ' "$1"
}

for skill_dir in "$source_dir"/* "$source_dir"/*/*; do
    is_stable_skill_dir "$skill_dir" || continue

    skill_name=${skill_dir##*/}
    skills_checked=$((skills_checked + 1))

    skill_file="$skill_dir/SKILL.md"
    metadata_file="$skill_dir/agents/openai.yaml"

    if [ ! -f "$skill_file" ]; then
        printf 'invalid  %s has no SKILL.md\n' "$skill_name" >&2
        errors=$((errors + 1))
        continue
    fi

    allow_missing=false
    is_borrowed_skill "$skill_name" && allow_missing=true
    if ! portable_invocation_policy "$skill_file" "$allow_missing" >/dev/null; then
        printf 'invalid  %s has an invalid invocation policy; authored skills must declare disable-model-invocation.\n' "$skill_name" >&2
        errors=$((errors + 1))
    fi

    if [ -f "$metadata_file" ] && has_codex_invocation_policy "$metadata_file" &&
        ! is_borrowed_skill "$skill_name"; then
        printf 'invalid  %s sets a canonical Codex policy; the installer derives authored skill policies.\n' "$skill_name" >&2
        errors=$((errors + 1))
    fi
done

# Experiments are ordinary skill folders. They need no pin or integrity manifest.
for skill_dir in "$source_dir"/experimental/*; do
    [ -d "$skill_dir" ] || continue
    skill_name=${skill_dir##*/}
    if [ ! -f "$skill_dir/SKILL.md" ]; then
        printf 'invalid  experimental skill %s has no SKILL.md\n' "$skill_name" >&2
        errors=$((errors + 1))
    elif ! portable_invocation_policy "$skill_dir/SKILL.md" true >/dev/null; then
        printf 'invalid  experimental skill %s has an invalid invocation policy\n' "$skill_name" >&2
        errors=$((errors + 1))
    fi
    if stable_skill_source "$skill_name" >/dev/null; then
        printf 'invalid  %s exists as both a stable and experimental skill\n' "$skill_name" >&2
        errors=$((errors + 1))
    fi
done

if [ -f "$source_dir/sources.tsv" ]; then
    seen_sources=
    tab=$(printf '\t')
    while IFS="$tab" read -r skill_name repository upstream_path ref commit expected_hash extra; do
        case $skill_name in ''|'#'*) continue ;; esac
        case " $seen_sources " in
            *" $skill_name "*)
                printf 'invalid  duplicate provenance: %s\n' "$skill_name" >&2
                errors=$((errors + 1))
                ;;
        esac
        seen_sources="$seen_sources $skill_name"
        if [ -n "$extra" ] || [ -z "$repository" ] || [ -z "$upstream_path" ] ||
            [ -z "$ref" ] || [ -z "$commit" ] || [ "${#expected_hash}" -ne 64 ]; then
            printf 'invalid  malformed provenance: %s\n' "$skill_name" >&2
            errors=$((errors + 1))
            continue
        fi
        if ! canonical_dir=$(stable_skill_source "$skill_name"); then
            printf 'invalid  provenance for unknown stable skill: %s\n' "$skill_name" >&2
            errors=$((errors + 1))
            continue
        fi
        if [ "$(raw_skill_hash "$canonical_dir")" != "$expected_hash" ]; then
            printf 'invalid  %s differs from its recorded upstream content\n' "$skill_name" >&2
            errors=$((errors + 1))
        fi
    done < "$source_dir/sources.tsv"
fi

if [ "$skills_checked" -eq 0 ]; then
    printf 'invalid  no skill directories found in %s\n' "$source_dir" >&2
    errors=$((errors + 1))
fi

if [ "$errors" -ne 0 ]; then
    exit 1
fi
