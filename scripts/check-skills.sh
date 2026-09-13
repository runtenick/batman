#!/bin/sh

set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
source_dir=${1:-"$repo_dir/skills"}

errors=0
skills_checked=0

portable_invocation_policy() {
    awk '
        NR == 1 && $0 == "---" {
            in_frontmatter = 1
            next
        }
        in_frontmatter && $0 == "---" {
            in_frontmatter = 0
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

for skill_dir in "$source_dir"/*; do
    [ -d "$skill_dir" ] || continue
    skills_checked=$((skills_checked + 1))

    skill_name=${skill_dir##*/}
    skill_file="$skill_dir/SKILL.md"
    metadata_file="$skill_dir/agents/openai.yaml"

    if [ ! -f "$skill_file" ]; then
        printf 'invalid  %s has no SKILL.md\n' "$skill_name" >&2
        errors=$((errors + 1))
        continue
    fi

    if ! portable_invocation_policy "$skill_file" >/dev/null; then
        printf '%s\n' "invalid  $skill_name must set disable-model-invocation to exactly true or false in SKILL.md (true is Batman's default)." >&2
        errors=$((errors + 1))
    fi

    if [ -f "$metadata_file" ] && has_codex_invocation_policy "$metadata_file"; then
        printf '%s\n' "invalid  $skill_name sets policy.allow_implicit_invocation in canonical agents/openai.yaml; the installer derives that Codex policy from disable-model-invocation." >&2
        errors=$((errors + 1))
    fi
done

if [ "$skills_checked" -eq 0 ]; then
    printf 'invalid  no skill directories found in %s\n' "$source_dir" >&2
    errors=$((errors + 1))
fi

if [ "$errors" -ne 0 ]; then
    exit 1
fi

printf 'All Batman skills have an explicit portable invocation policy.\n'
