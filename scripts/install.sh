#!/bin/sh

set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
source_dir=${BATMAN_SOURCE_DIR:-"$repo_dir/skills"}

# shellcheck source=scripts/lib/batman-state.sh
. "$script_dir/lib/batman-state.sh"

codex_destination_dir=${BATMAN_CODEX_SKILLS_DIR:-${BATMAN_SKILLS_DIR:-"$HOME/.agents/skills"}}
copilot_destination_dir=${BATMAN_COPILOT_SKILLS_DIR:-"$HOME/.copilot/skills"}
portable_destination_dir=${BATMAN_PORTABLE_SKILLS_DIR:-${BATMAN_SKILLS_DIR:-"$HOME/.agents/skills"}}
command_bin_dir=${BATMAN_BIN_DIR:-"$HOME/.local/bin"}

usage() {
    printf '%s\n' "Usage: $0 [--target codex|copilot|portable|all] [--install-command]"
    printf '\n%s\n' "With no target, installs Codex and Copilot projections (same as --target all)."
    printf '%s\n' '       --install-command also installs the batman command in $BATMAN_BIN_DIR or ~/.local/bin.'
}

target=all
install_command=0
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
        --install-command)
            install_command=1
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
unchanged=0
preserved=0
conflicts=0

hash_stdin() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum | awk '{print $1}'
        return
    fi

    if command -v shasum >/dev/null 2>&1; then
        shasum -a 256 | awk '{print $1}'
        return
    fi

    printf '%s\n' 'install: sha256sum or shasum is required' >&2
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

render_portable_skill() {
    source_file=$1
    destination_file=$2
    invocation=$3

    awk -v invocation="$invocation" '
        in_frontmatter && /^disable-model-invocation:[[:space:]]*/ {
            if (invocation == "automatic") {
                print "disable-model-invocation: false"
            } else {
                print "disable-model-invocation: true"
            }
            next
        }
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
        { print }
    ' "$source_file" > "$destination_file"
}

render_projection() {
    skill_dir=$1
    projection_dir=$2
    projection_kind=$3
    invocation=$4

    cp -R "$skill_dir" "$projection_dir"

    if [ "$projection_kind" = codex ]; then
        render_codex_skill "$skill_dir/SKILL.md" "$projection_dir/SKILL.md.tmp"
        mv "$projection_dir/SKILL.md.tmp" "$projection_dir/SKILL.md"
        mkdir -p "$projection_dir/agents"
        if [ "$invocation" = automatic ]; then
            allow_implicit=true
        else
            allow_implicit=false
        fi
        render_codex_metadata "$skill_dir/agents/openai.yaml" "$projection_dir/agents/openai.yaml.tmp" "$allow_implicit"
        mv "$projection_dir/agents/openai.yaml.tmp" "$projection_dir/agents/openai.yaml"
    else
        render_portable_skill "$skill_dir/SKILL.md" "$projection_dir/SKILL.md.tmp" "$invocation"
        mv "$projection_dir/SKILL.md.tmp" "$projection_dir/SKILL.md"
    fi

    printf '%s\n%s\n' "$skill_dir" "$projection_kind" > "$projection_dir/.batman-source"
}

replace_projection() {
    destination=$1
    projection_dir=$2
    backup_dir=$3

    mv "$destination" "$backup_dir"
    if mv "$projection_dir" "$destination"; then
        rm -rf "$backup_dir"
        return 0
    fi

    mv "$backup_dir" "$destination"
    return 1
}

install_cli_command() {
    command_path="$command_bin_dir/batman"
    command_target="$script_dir/batman"

    mkdir -p "$command_bin_dir"

    if [ -L "$command_path" ]; then
        existing_target=$(readlink "$command_path")
        if [ "$existing_target" = "$command_target" ]; then
            printf 'command unchanged %s\n' "$command_path"
            return 0
        fi

        printf 'install: command path already links to %s: %s\n' "$existing_target" "$command_path" >&2
        return 1
    fi

    if [ -e "$command_path" ]; then
        printf 'install: command path already exists: %s\n' "$command_path" >&2
        return 1
    fi

    ln -s "$command_target" "$command_path"
    printf 'command installed %s -> %s\n' "$command_path" "$command_target"
}

install_target() {
    target_name=$1
    destination_dir=$2
    projection_kind=$3

    mkdir -p "$destination_dir" "$projection_work_dir/$target_name"
    state_file="$destination_dir/.batman/state.tsv"

    for skill_dir in "$source_dir"/*; do
        [ -d "$skill_dir" ] || continue
        [ -f "$skill_dir/SKILL.md" ] || continue

        skill_name=${skill_dir##*/}
        projection_dir="$projection_work_dir/$target_name/$skill_name"
        destination="$destination_dir/$skill_name"
        source_hash=$(managed_hash "$skill_dir")

        if [ -L "$destination" ]; then
            link_target=$(readlink "$destination")
            if [ "$link_target" != "$skill_dir" ]; then
                printf '%-18s %s -> %s\n' "$target_name conflict" "$skill_name" "$link_target" >&2
                conflicts=$((conflicts + 1))
                continue
            fi

            invocation=$(state_get "$state_file" invocation "$skill_name" 2>/dev/null || existing_invocation "$projection_kind" "$destination")
            render_projection "$skill_dir" "$projection_dir" "$projection_kind" "$invocation"
            backup_dir="$projection_work_dir/$target_name/$skill_name.backup"
            rm -rf "$backup_dir"
            replace_projection "$destination" "$projection_dir" "$backup_dir"
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
            if [ ! -f "$marker" ] || [ "$(sed -n '1p' "$marker")" != "$skill_dir" ]; then
                printf '%-18s %s already exists at %s\n' "$target_name conflict" "$skill_name" "$destination" >&2
                conflicts=$((conflicts + 1))
                continue
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

            render_projection "$skill_dir" "$projection_dir" "$projection_kind" "$invocation"
            backup_dir="$projection_work_dir/$target_name/$skill_name.backup"
            rm -rf "$backup_dir"
            replace_projection "$destination" "$projection_dir" "$backup_dir"
            installed_hash=$(managed_hash "$destination")
            state_set "$state_file" invocation "$skill_name" "$invocation"
            state_set "$state_file" source-hash "$skill_name" "$source_hash"
            state_set "$state_file" installed-hash "$skill_name" "$installed_hash"
            printf '%-18s %s\n' "$target_name updated" "$skill_name"
            updated=$((updated + 1))
        else
            invocation=$(state_get "$state_file" invocation "$skill_name" 2>/dev/null || printf '%s\n' manual)
            render_projection "$skill_dir" "$projection_dir" "$projection_kind" "$invocation"
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

if [ "$install_command" -eq 1 ]; then
    install_cli_command
fi

printf '\n%d installed, %d updated, %d unchanged, %d preserved, %d conflicts\n' "$installed" "$updated" "$unchanged" "$preserved" "$conflicts"

if [ "$conflicts" -ne 0 ]; then
    exit 1
fi
