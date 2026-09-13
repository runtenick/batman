#!/bin/sh

set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
source_dir="$repo_dir/skills"

codex_destination_dir=${BATMAN_CODEX_SKILLS_DIR:-${BATMAN_SKILLS_DIR:-"$HOME/.agents/skills"}}
copilot_destination_dir=${BATMAN_COPILOT_SKILLS_DIR:-"$HOME/.copilot/skills"}
portable_destination_dir=${BATMAN_PORTABLE_SKILLS_DIR:-${BATMAN_SKILLS_DIR:-"$HOME/.agents/skills"}}

usage() {
    printf '%s\n' "Usage: $0 [--target codex|copilot|portable|all]"
    printf '\n%s\n' "With no target, installs Codex and Copilot projections (same as --target all)."
}

target=all
while [ "$#" -gt 0 ]; do
    case $1 in
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
    codex|copilot|portable|all) ;;
    *)
        printf 'install: invalid target: %s\n' "$target" >&2
        usage >&2
        exit 2
        ;;
esac

if [ "$target" = all ] && [ "$codex_destination_dir" = "$copilot_destination_dir" ]; then
    printf 'install: Codex and Copilot destinations must differ for --target all\n' >&2
    exit 2
fi

"$script_dir/check-skills.sh" "$source_dir"

projection_work_dir=$(mktemp -d "${TMPDIR:-/tmp}/batman-skills.XXXXXX")
trap 'rm -rf "$projection_work_dir"' EXIT HUP INT TERM

installed=0
updated=0
conflicts=0

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

render_codex_metadata() {
    source_file=$1
    destination_file=$2
    allow_implicit=$3

    if [ ! -f "$source_file" ]; then
        printf 'policy:\n  allow_implicit_invocation: %s\n' "$allow_implicit" > "$destination_file"
        return
    fi

    awk -v allow_implicit="$allow_implicit" '
        /^policy:[[:space:]]*(#.*)?$/ {
            found_policy = 1
            print
            print "  allow_implicit_invocation: " allow_implicit
            next
        }
        { print }
        END {
            if (!found_policy) {
                print "policy:"
                print "  allow_implicit_invocation: " allow_implicit
            }
        }
    ' "$source_file" > "$destination_file"
}

install_target() {
    target_name=$1
    destination_dir=$2
    projection_kind=$3

    mkdir -p "$destination_dir" "$projection_work_dir/$target_name"

    for skill_dir in "$source_dir"/*; do
        [ -d "$skill_dir" ] || continue
        [ -f "$skill_dir/SKILL.md" ] || continue

        skill_name=${skill_dir##*/}
        projection_dir="$projection_work_dir/$target_name/$skill_name"
        cp -R "$skill_dir" "$projection_dir"

        if [ "$projection_kind" = codex ]; then
            invocation_policy=$(portable_invocation_policy "$skill_dir/SKILL.md")
            if [ "$invocation_policy" = true ]; then
                allow_implicit=false
            else
                allow_implicit=true
            fi

            render_codex_skill "$skill_dir/SKILL.md" "$projection_dir/SKILL.md.tmp"
            mv "$projection_dir/SKILL.md.tmp" "$projection_dir/SKILL.md"
            mkdir -p "$projection_dir/agents"
            render_codex_metadata "$skill_dir/agents/openai.yaml" "$projection_dir/agents/openai.yaml.tmp" "$allow_implicit"
            mv "$projection_dir/agents/openai.yaml.tmp" "$projection_dir/agents/openai.yaml"
        fi

        printf '%s\n%s\n' "$skill_dir" "$projection_kind" > "$projection_dir/.batman-source"

        destination="$destination_dir/$skill_name"
        if [ -L "$destination" ]; then
            link_target=$(readlink "$destination")
            if [ "$link_target" != "$skill_dir" ]; then
                printf '%-18s %s -> %s\n' "$target_name conflict" "$skill_name" "$link_target" >&2
                conflicts=$((conflicts + 1))
                continue
            fi

            rm "$destination"
            mv "$projection_dir" "$destination"
            printf '%-18s %s\n' "$target_name migrated" "$skill_name"
            updated=$((updated + 1))
        elif [ -e "$destination" ]; then
            marker="$destination/.batman-source"
            if [ ! -f "$marker" ] || [ "$(sed -n '1p' "$marker")" != "$skill_dir" ]; then
                printf '%-18s %s already exists at %s\n' "$target_name conflict" "$skill_name" "$destination" >&2
                conflicts=$((conflicts + 1))
                continue
            fi

            rm -rf "$destination"
            mv "$projection_dir" "$destination"
            printf '%-18s %s\n' "$target_name updated" "$skill_name"
            updated=$((updated + 1))
        else
            mv "$projection_dir" "$destination"
            printf '%-18s %s\n' "$target_name installed" "$skill_name"
            installed=$((installed + 1))
        fi
    done
}

case $target in
    codex)
        install_target codex "$codex_destination_dir" codex
        ;;
    copilot)
        install_target copilot "$copilot_destination_dir" portable
        ;;
    portable)
        install_target portable "$portable_destination_dir" portable
        ;;
    all)
        install_target codex "$codex_destination_dir" codex
        install_target copilot "$copilot_destination_dir" portable
        ;;
esac

printf '\n%d installed, %d updated, %d conflicts\n' "$installed" "$updated" "$conflicts"

if [ "$conflicts" -ne 0 ]; then
    exit 1
fi
