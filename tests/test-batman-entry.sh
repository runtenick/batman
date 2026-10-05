#!/bin/sh

set -eu
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
batman="$repo_dir/scripts/batman"
test_root=$(mktemp -d "${TMPDIR:-/tmp}/batman-entry.XXXXXX")
trap 'rm -rf "$test_root"' EXIT HUP INT TERM

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
contains() { case $output in *"$1"*) ;; *) fail "missing output: $1" ;; esac; }

# Isolate detection from installed agents and all files in the owner's home.
mkdir -p "$test_root/tools" "$test_root/home"
for tool in env dirname basename readlink mktemp rm sed awk grep cat mkdir ln cp mv find sort sha256sum shasum wc tr diff chmod; do
    tool_path=$(command -v "$tool" || :)
    [ -z "$tool_path" ] || ln -s "$tool_path" "$test_root/tools/$tool"
done
entry_env() {
    env HOME="$test_root/home" PATH="$test_root/tools" \
        XDG_CONFIG_HOME="$test_root/config" BATMAN_SOURCE_DIR="$repo_dir/skills" \
        BATMAN_CODEX_SKILLS_DIR="$test_root/shared" \
        BATMAN_PORTABLE_SKILLS_DIR="$test_root/shared" \
        BATMAN_COPILOT_SKILLS_DIR="$test_root/copilot" \
        BATMAN_BIN_DIR="$test_root/bin" "$@"
}

printf '%s\n' 'Testing successful help without source validation or file changes...'
output=$(entry_env "$batman")
contains 'Start with: batman groups'
[ "$(printf '%s\n' "$output" | wc -l)" -le 20 ] || fail 'introductory help is too long'
for form in '--help' 'groups --help' 'scan --help' 'sync --help' 'status --help' \
    'enable --help' 'disable --help' 'update --help' \
    'enable grill-me --help' 'disable grill-me --help' 'update grill-me --help' \
    'experimental --help' 'experimental list --help' 'experimental add --help' \
    'experimental remove --help' 'experimental add prototype --help' \
    'config --help' 'config get --help' 'config set --help' 'config unset --help' \
    'config set default-profile codex --help'; do
    # Each form above intentionally expands into separate arguments.
    output=$(entry_env env BATMAN_SOURCE_DIR="$test_root/missing-source" "$batman" $form)
    contains 'Usage: batman'
done
[ ! -e "$test_root/shared" ] || fail 'help installed skills'
[ ! -e "$test_root/copilot" ] || fail 'help installed Copilot skills'
[ ! -e "$test_root/config" ] || fail 'help wrote configuration'
if entry_env "$batman" missing --help >/dev/null 2>&1; then fail 'unknown command succeeded'; fi

printf '%s\n' 'Testing command-only setup, repeated setup, and conflicts...'
output=$(entry_env env BATMAN_SOURCE_DIR="$test_root/missing-source" "$repo_dir/scripts/install.sh")
contains 'Command installed'
contains 'Add '
[ "$(readlink "$test_root/bin/batman")" = "$batman" ] || fail 'wrong command link'
output=$(entry_env "$repo_dir/scripts/install.sh")
contains 'Command already available'
output=$(entry_env "$test_root/bin/batman" groups)
contains 'dev-workflow'
[ ! -e "$test_root/shared" ] || fail 'setup installed skills'
[ ! -e "$test_root/copilot" ] || fail 'setup installed Copilot skills'
[ ! -e "$test_root/config" ] || fail 'setup wrote configuration'
if output=$(entry_env "$repo_dir/scripts/install.sh" --install-command 2>&1); then fail 'old flag accepted'; fi
contains 'use batman sync'
mkdir "$test_root/conflict"
printf '%s\n' 'keep this file' > "$test_root/conflict/batman"
if entry_env env BATMAN_BIN_DIR="$test_root/conflict" "$repo_dir/scripts/install.sh" >/dev/null 2>&1; then fail 'setup overwrote a command'; fi
[ "$(cat "$test_root/conflict/batman")" = 'keep this file' ] || fail 'command file changed'
mkdir "$test_root/link-conflict"
ln -s /unrelated/batman "$test_root/link-conflict/batman"
if entry_env env BATMAN_BIN_DIR="$test_root/link-conflict" "$repo_dir/scripts/install.sh" >/dev/null 2>&1; then fail 'setup overwrote an unrelated link'; fi
[ "$(readlink "$test_root/link-conflict/batman")" = /unrelated/batman ] || fail 'command link changed'

printf '%s\n' 'Testing no-agent portable fallback and experimental boundary...'
output=$(entry_env "$batman" sync --group communication 2>&1)
contains "Using portable skills at $test_root/shared"
[ -f "$test_root/shared/unslop/SKILL.md" ] || fail 'portable skill missing'
grep -F 'disable-model-invocation: true' "$test_root/shared/unslop/SKILL.md" >/dev/null || fail 'portable skill is not manual-only'
[ ! -e "$test_root/copilot" ] || fail 'fallback installed Copilot skills'
output=$(entry_env "$batman" status 2>&1)
contains 'Using portable skills'
contains 'portable'
if output=$(entry_env "$batman" experimental list 2>&1); then fail 'experimental fallback chose an agent'; fi
contains 'experimental skills require --target'

printf '%s\n' 'Testing detected agents, remembered choice, and explicit overrides...'
printf '#!/bin/sh\nexit 0\n' > "$test_root/tools/codex"
chmod +x "$test_root/tools/codex"
output=$(entry_env "$batman" status)
contains 'codex'
case $output in *'Using portable skills'*) fail 'missed sole agent' ;; esac
cp "$test_root/tools/codex" "$test_root/tools/copilot"
if output=$(entry_env "$batman" status </dev/null 2>&1); then fail 'ambiguous detection succeeded without choice'; fi
contains 'multiple agents are available'
entry_env "$batman" config set default-profile copilot >/dev/null
output=$(entry_env "$batman" status)
contains 'copilot'
output=$(entry_env "$batman" status --target codex)
contains 'codex'
output=$(entry_env "$batman" config get default-profile)
[ "$output" = copilot ] || fail 'override changed default'
entry_env "$batman" config unset default-profile >/dev/null

# A real controlling terminal is needed to verify /dev/tty prompts.
if command -v python3 >/dev/null 2>&1; then
    printf '%s\n' 'Testing interactive choice and optional saved default...'
    entry_env "$(command -v python3)" - "$batman" <<'PY'
import errno
import os
import pty
import select
import signal
import sys
import time

def run(answers):
    pid, fd = pty.fork()
    if pid == 0:
        os.execv(sys.argv[1], [sys.argv[1], 'status'])
    transcript = b''
    deadline = time.monotonic() + 15
    prompts = [(b'Select [1-2]: ', answers[0]), (b'for future commands? [y/N]: ', answers[1])]
    try:
        while time.monotonic() < deadline:
            if not select.select([fd], [], [], 0.1)[0]:
                continue
            try:
                chunk = os.read(fd, 65536)
            except OSError as exc:
                if exc.errno == errno.EIO:
                    break
                raise
            if not chunk:
                break
            transcript += chunk
            if prompts and prompts[0][0] in transcript:
                os.write(fd, prompts.pop(0)[1])
        else:
            raise AssertionError('interactive selection timed out')
        _, status = os.waitpid(pid, 0)
        assert status == 0, transcript.decode()
        assert not prompts, transcript.decode()
        return transcript.decode()
    except BaseException:
        os.kill(pid, signal.SIGKILL)
        os.waitpid(pid, 0)
        raise
    finally:
        os.close(fd)

profile = os.path.join(os.environ['XDG_CONFIG_HOME'], 'batman', 'default-profile')
run([b'2\n', b'n\n'])
assert not os.path.exists(profile), 'declined default was saved'
assert 'Default profile set to codex.' in run([b'1\n', b'y\n'])
with open(profile) as saved:
    assert saved.read() == 'codex\n'
PY
else
    printf '%s\n' 'Skipping terminal prompt checks: python3 is unavailable.'
fi

printf '%s\n' 'Batman entry-point regression tests passed.'
