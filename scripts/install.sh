#!/bin/sh

set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
command_bin_dir=${BATMAN_BIN_DIR:-"$HOME/.local/bin"}
command_path="$command_bin_dir/batman"
command_target="$script_dir/batman"

usage() {
    cat <<'HELP'
Usage: ./scripts/install.sh

Make the batman command available. No skills are installed.
Then run batman to see what you can do.

Older installer options have moved to batman sync:
  ./scripts/install.sh --target codex  ->  batman sync --target codex
  ./scripts/install.sh --install-command  ->  ./scripts/install.sh
HELP
}

case ${1:-} in
    '') ;;
    -h|--help) usage; exit 0 ;;
    *)
        printf '%s\n' 'install: setup takes no options; use batman sync to install skills.' >&2
        usage >&2
        exit 2
        ;;
esac
[ "$#" -eq 0 ] || { usage >&2; exit 2; }

mkdir -p "$command_bin_dir"
if [ -L "$command_path" ]; then
    existing_target=$(readlink "$command_path")
    if [ "$existing_target" != "$command_target" ]; then
        printf 'install: command path already links to %s: %s\n' "$existing_target" "$command_path" >&2
        exit 1
    fi
    printf 'Command already available at %s.\n' "$command_path"
elif [ -e "$command_path" ]; then
    printf 'install: command path already exists: %s\n' "$command_path" >&2
    exit 1
else
    ln -s "$command_target" "$command_path"
    printf 'Command installed at %s.\n' "$command_path"
fi

case :$PATH: in
    *:"$command_bin_dir":*) printf '%s\n' 'Next: run batman.' ;;
    *)
        printf 'Add %s to PATH in your shell configuration, then run batman.\n' "$command_bin_dir"
        printf 'For this terminal: export PATH="%s:$PATH"\n' "$command_bin_dir"
        ;;
esac
