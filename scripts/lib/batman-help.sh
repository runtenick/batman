#!/bin/sh

intro_help() {
    cat <<'HELP'
Usage: batman <command>

Manage your local AI skills.

  groups        Browse Batman's skill groups.
  scan          Find skills already on your machine.
  sync          Install skills and refresh clean Batman copies.
  status        See installed skills, local edits, and available changes.
  update        Refresh one skill, asking before replacing local edits.
  enable        Allow an agent to use a skill automatically.
  disable       Use a skill only when you ask for it.
  experimental  Browse, add, or remove skills under evaluation.
  config        View, save, or clear your default agent.

Start with: batman groups
For instructions and examples: batman <command> --help
HELP
}

target_help() {
    if [ "${1:-}" = experimental ]; then
        printf '\n%s\n' 'Choose where skills go with --target codex|copilot|all.'
    else
        printf '\n%s\n' 'Choose where skills go with --target codex|copilot|portable|all.'
    fi
    cat <<'HELP'
The saved default wins; otherwise Batman uses the only detected agent.
If both are found, Batman asks and offers to save a default.
HELP
    if [ "${1:-}" = experimental ]; then
        printf '%s\n' 'If neither is found, choose --target codex or --target copilot.'
    else
        printf '%s\n' 'If neither is found, use portable files in ~/.agents/skills by default.'
    fi
    cat <<'HELP'
In a script, choose --target or save a default when both agents are found.
"all" means Codex and Copilot. Explicit --target overrides the default.
HELP
}

command_help() {
    case $1 in
        groups)
            cat <<'HELP'
Usage: batman groups

Browse stable skills by group, including skills without a group.
Next: batman sync --group dev-workflow
HELP
            ;;
        scan)
            cat <<'HELP'
Usage: batman scan [<dir>] [--include-unknown]

Find local skills in known global folders and beneath the current project.
Pass a directory to search there instead. This does not change any files.
--include-unknown also lists skill files outside recognized locations.

Example: batman scan ~/projects
HELP
            ;;
        sync|status)
            printf 'Usage: batman %s [--group <name>]... [--target codex|copilot|portable|all]\n\n' "$1"
            if [ "$1" = sync ]; then
                printf '%s\n' 'Install missing stable skills and refresh clean Batman copies.' 'Local edits and invocation preferences are preserved; conflicts are reported.' 'Experimental skills are added separately.'
            else
                printf '%s\n' 'Show installation, invocation mode, local edits, and available changes.' 'This does not change installed skills.'
            fi
            printf '\nExample: batman %s --group dev-workflow\n' "$1"
            printf '%s\n' 'Omit --group for all stable skills; repeat it to combine groups.'
            target_help
            ;;
        update|enable|disable)
            printf 'Usage: batman %s <skill> [--target codex|copilot|portable|all]\n\n' "$1"
            case $1 in
                update) printf '%s\n' 'Refresh one stable skill from this checkout.' 'If the installed copy has local edits, Batman asks before replacing them.' ;;
                enable) printf '%s\n' 'Allow the agent to use an installed stable skill automatically.' ;;
                disable) printf '%s\n' 'Return an installed stable skill to use only when you ask for it.' ;;
            esac
            printf '\nExample: batman %s grill-me\n' "$1"
            target_help
            ;;
        config)
            case ${2:-} in
                get) printf '%s\n' 'Usage: batman config get default-profile' ;;
                set) printf '%s\n' 'Usage: batman config set default-profile <codex|copilot>' ;;
                unset) printf '%s\n' 'Usage: batman config unset default-profile' ;;
                *)
                    printf '%s\n' 'Usage: batman config get default-profile' '       batman config set default-profile <codex|copilot>' '       batman config unset default-profile'
                    ;;
            esac
            cat <<'HELP'

View, save, or clear the agent used when --target is omitted.
This setting chooses the destination for skills, not a model.

Example: batman config set default-profile codex
Use --target copilot on a command to override the saved choice once.
HELP
            ;;
        experimental)
            case ${2:-} in
                list) printf '%s\n' 'Usage: batman experimental list [--target codex|copilot|all]' ;;
                add|remove) printf 'Usage: batman experimental %s <skill> [--target codex|copilot|all]\n' "$2" ;;
                *)
                    printf '%s\n' 'Usage: batman experimental list [--target codex|copilot|all]' '       batman experimental add <skill> [--target codex|copilot|all]' '       batman experimental remove <skill> [--target codex|copilot|all]'
                    ;;
            esac
            cat <<'HELP'

Browse raw skills under evaluation. Add one explicitly to try it as manual-only.
Adding installs or refreshes a clean copy; local edits are preserved.
Removing deletes only Batman-managed copies and asks before removing local edits.
Ordinary sync does not install these skills. Portable mode is not supported.

Example: batman experimental add prototype --target codex
HELP
            target_help experimental
            ;;
        ''|-h|--help) intro_help ;;
        *) printf 'batman: unknown command: %s\n' "$1" >&2; intro_help >&2; return 2 ;;
    esac
}
