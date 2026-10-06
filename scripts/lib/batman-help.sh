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
  enable        Allow automatic use of a skill.
  disable       Use a skill only when you ask for it.
  experimental  Browse, add, or remove skills under evaluation.

Start with: batman groups
For instructions and examples: batman <command> --help
HELP
}

destination_help() {
    cat <<'HELP'

Skills are shared by Codex and Copilot in ~/.agents/skills.
Set BATMAN_SKILLS_DIR to use a different directory.
Legacy --target values are deprecated aliases for this shared installation.
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
            printf 'Usage: batman %s [--group <name>]...\n\n' "$1"
            if [ "$1" = sync ]; then
                printf '%s\n' 'Install missing stable skills and refresh clean Batman copies.' 'Local edits and invocation preferences are preserved; conflicts are reported.' 'Experimental skills are added separately.'
            else
                printf '%s\n' 'Show installation, invocation mode, local edits, and available changes.' 'This does not change installed skills.'
            fi
            printf '\nExample: batman %s --group dev-workflow\n' "$1"
            printf '%s\n' 'Omit --group for all stable skills; repeat it to combine groups.'
            destination_help
            ;;
        update|enable|disable)
            printf 'Usage: batman %s <skill>\n\n' "$1"
            case $1 in
                update) printf '%s\n' 'Refresh one stable skill from this checkout.' 'If the installed copy has local edits, Batman asks before replacing them.' ;;
                enable) printf '%s\n' 'Allow both agents to use an installed stable skill automatically.' ;;
                disable) printf '%s\n' 'Return an installed stable skill to use only when you ask for it.' ;;
            esac
            printf '\nExample: batman %s grill-me\n' "$1"
            destination_help
            ;;
        config)
            printf '%s\n' 'Usage: batman config unset default-profile' '' 'Default profiles are retired. All commands use the shared installation.'
            ;;
        experimental)
            case ${2:-} in
                list) printf '%s\n' 'Usage: batman experimental list' ;;
                add|remove) printf 'Usage: batman experimental %s <skill>\n' "$2" ;;
                *)
                    printf '%s\n' 'Usage: batman experimental list' '       batman experimental add <skill>' '       batman experimental remove <skill>'
                    ;;
            esac
            cat <<'HELP'

Browse raw skills under evaluation. Add one explicitly to try it with its source invocation default.
Adding installs or refreshes a clean copy; local edits are preserved.
Removing deletes only Batman-managed copies and asks before removing local edits.
Ordinary sync does not install new experiments. It migrates already installed copies.

Example: batman experimental add prototype
HELP
            destination_help
            ;;
        ''|-h|--help) intro_help ;;
        *) printf 'batman: unknown command: %s\n' "$1" >&2; intro_help >&2; return 2 ;;
    esac
}
