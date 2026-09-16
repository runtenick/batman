#!/bin/sh

set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
source_dir=${1:-"$repo_dir/skills"}

errors=0
skills_checked=0
experimental_skills_checked=0

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

    skill_name=${skill_dir##*/}
    [ "$skill_name" = experimental ] && continue
    skills_checked=$((skills_checked + 1))

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

experimental_dir="$source_dir/experimental"
if [ -d "$experimental_dir" ]; then
    manifest_file="$experimental_dir/sources.tsv"
    manifest_skills=

    if [ ! -f "$manifest_file" ]; then
        printf 'invalid  experimental skills have no sources.tsv manifest\n' >&2
        errors=$((errors + 1))
    else
        tab=$(printf '\t')
        while IFS="$tab" read -r skill_name repository commit upstream_path expected_hash yaml_source extra; do
            case $skill_name in
                ''|'#'*) continue ;;
            esac

            experimental_skills_checked=$((experimental_skills_checked + 1))

            case $skill_name in
                *[!a-z0-9-]*|-*|*-)
                    printf 'invalid  experimental skill name: %s\n' "$skill_name" >&2
                    errors=$((errors + 1))
                    continue
                    ;;
            esac

            case " $manifest_skills " in
                *" $skill_name "*)
                    printf 'invalid  duplicate experimental manifest entry: %s\n' "$skill_name" >&2
                    errors=$((errors + 1))
                    continue
                    ;;
            esac
            manifest_skills="$manifest_skills $skill_name"

            if [ -n "$extra" ] || [ -z "$repository" ] || [ -z "$upstream_path" ] || [ -z "$expected_hash" ] || [ -z "$yaml_source" ]; then
                printf 'invalid  malformed experimental manifest entry: %s\n' "$skill_name" >&2
                errors=$((errors + 1))
                continue
            fi

            if [ "${#commit}" -ne 40 ]; then
                printf 'invalid  %s must pin a full 40-character commit SHA\n' "$skill_name" >&2
                errors=$((errors + 1))
            else
                case $commit in
                    *[!0-9a-f]*)
                        printf 'invalid  %s has a non-hex commit SHA\n' "$skill_name" >&2
                        errors=$((errors + 1))
                        ;;
                esac
            fi

            if [ "${#expected_hash}" -ne 64 ]; then
                printf 'invalid  %s must record a full SHA-256 content hash\n' "$skill_name" >&2
                errors=$((errors + 1))
            else
                case $expected_hash in
                    *[!0-9a-f]*)
                        printf 'invalid  %s has a non-hex content hash\n' "$skill_name" >&2
                        errors=$((errors + 1))
                        ;;
                esac
            fi

            case $yaml_source in
                upstream)
                    if [ ! -f "$experimental_dir/$skill_name/agents/openai.yaml" ]; then
                        printf 'invalid  %s declares an upstream agents/openai.yaml, but the file is missing\n' "$skill_name" >&2
                        errors=$((errors + 1))
                    fi
                    ;;
                batman)
                    if [ ! -f "$experimental_dir/$skill_name/agents/openai.yaml" ]; then
                        printf 'invalid  %s declares a Batman-created agents/openai.yaml, but the file is missing\n' "$skill_name" >&2
                        errors=$((errors + 1))
                    fi
                    ;;
                *)
                    printf 'invalid  %s has an unknown openai-yaml source: %s\n' "$skill_name" "$yaml_source" >&2
                    errors=$((errors + 1))
                    ;;
            esac

            if [ -f "$source_dir/$skill_name/SKILL.md" ]; then
                printf 'invalid  %s exists as both a stable and experimental skill\n' "$skill_name" >&2
                errors=$((errors + 1))
            fi

            if [ ! -f "$experimental_dir/$skill_name/SKILL.md" ]; then
                printf 'invalid  experimental skill %s has no SKILL.md\n' "$skill_name" >&2
                errors=$((errors + 1))
                continue
            fi

            actual_hash=$(raw_skill_hash "$experimental_dir/$skill_name")
            if [ "$actual_hash" != "$expected_hash" ]; then
                printf 'invalid  %s differs from its pinned raw source\n' "$skill_name" >&2
                errors=$((errors + 1))
            fi
        done < "$manifest_file"
    fi

    for skill_dir in "$experimental_dir"/*; do
        [ -d "$skill_dir" ] || continue
        skill_name=${skill_dir##*/}
        case " $manifest_skills " in
            *" $skill_name "*) ;;
            *)
                printf 'invalid  experimental skill %s has no manifest entry\n' "$skill_name" >&2
                errors=$((errors + 1))
                ;;
        esac
    done
fi

if [ "$skills_checked" -eq 0 ]; then
    printf 'invalid  no skill directories found in %s\n' "$source_dir" >&2
    errors=$((errors + 1))
fi

if [ "$errors" -ne 0 ]; then
    exit 1
fi

printf 'All stable Batman skills have an explicit portable invocation policy.\n'
if [ "$experimental_skills_checked" -gt 0 ]; then
    printf 'All experimental Batman skills match their pinned source hashes.\n'
fi
