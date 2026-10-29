#!/bin/bash
set -euo pipefail

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
test_dir=$(mktemp -d "${TMPDIR:-/tmp}/runner-workspace.XXXXXX")
test_dir=$(cd "$test_dir" && pwd -P)
trap 'rm -rf "$test_dir"' EXIT
export HOME="$test_dir/home"
BASE_DIR="$test_dir/fleet with spaces"
mkdir -p "$HOME" "$BASE_DIR/runner-one"
source "$project_dir/lib/workspace.sh"
source "$project_dir/lib/setup.sh"
source "$project_dir/lib/cleanup.sh"

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
assert_equal() { [ "$1" = "$2" ] || fail "Expected '$2', got '$1'"; }
uname() { printf '%s\n' "$test_os"; }
runner_dir="$BASE_DIR/runner-one"
printf '{"workFolder":"_work","agentId":42}\n' > "$runner_dir/.runner"

test_os=Linux
assert_equal "$(prepare_runner_workspace "$runner_dir")" "$runner_dir/_work"
assert_equal "$(jq -r .workFolder "$runner_dir/.runner")" "_work"

test_os=Darwin
expected=$(default_runner_work_dir "$runner_dir")
actual=$(prepare_runner_workspace "$runner_dir")
expected=$(cd "$expected" && pwd -P)
assert_equal "$actual" "$expected"
assert_equal "$(jq -r .workFolder "$runner_dir/.runner")" "$expected"
assert_equal "$(jq -r .agentId "$runner_dir/.runner")" "42"
[ -d "$expected/_temp" ] || fail "Missing temporary directory"
[ -d "$runner_dir/_work" ] || fail "Old workspace was removed"
assert_equal "$(prepare_runner_workspace "$runner_dir")" "$expected"

mkdir -p "$expected/_tool" "$expected/_PipelineMapping" "$expected/repo" "$expected/_actions"
touch "$expected/_tool/keep" "$expected/_PipelineMapping/keep" "$expected/repo/delete"
RUNNER_FLEET_RUNNER_DIR="$runner_dir" RUNNER_FLEET_WORK_DIR="$expected" \
    bash "$project_dir/lib/job-completed-cleanup.sh"
[ -f "$expected/_tool/keep" ] || fail "Tool cache removed"
[ -f "$expected/_PipelineMapping/keep" ] || fail "Pipeline mapping removed"
[ ! -e "$expected/repo" ] || fail "Checkout not cleaned"
[ ! -e "$expected/_actions" ] || fail "Actions not cleaned"

mkdir -p "$test_dir/unrelated/_work"
touch "$test_dir/unrelated/_work/keep"
if RUNNER_FLEET_RUNNER_DIR="$runner_dir" RUNNER_FLEET_WORK_DIR="$test_dir/unrelated/_work" \
    bash "$project_dir/lib/job-completed-cleanup.sh" 2>/dev/null; then
    fail "Unconfigured cleanup target accepted"
fi
[ -f "$test_dir/unrelated/_work/keep" ] || fail "Unrelated directory modified"

# Legacy hook environments do not include RUNNER_FLEET_RUNNER_DIR.
mkdir -p "$BASE_DIR/legacy/_work/repo"
printf '{"workFolder":"_work"}\n' > "$BASE_DIR/legacy/.runner"
RUNNER_FLEET_WORK_DIR="$BASE_DIR/legacy/_work" \
    bash "$project_dir/lib/job-completed-cleanup.sh"
[ ! -e "$BASE_DIR/legacy/_work/repo" ] || fail "Legacy hook failed"
rm "$BASE_DIR/legacy/.runner"

mv "$runner_dir/.runner" "$runner_dir/.runner_migrated"
assert_equal "$(runner_work_dir "$runner_dir")" "$expected"
printf 'invalid json\n' > "$runner_dir/.runner"
if prepare_runner_workspace "$runner_dir" 2>/dev/null; then
    fail "Invalid configuration accepted"
fi
rm "$runner_dir/.runner"

# A symlinked storage root must not reintroduce the Documents privacy prompt.
mkdir -p "$HOME/Documents"
mv "$HOME/.local" "$HOME/Documents/storage"
ln -s "$HOME/Documents/storage" "$HOME/.local"
if prepare_runner_workspace "$runner_dir" 2>/dev/null; then
    fail "Protected workspace accepted"
fi
rm "$HOME/.local"
mv "$HOME/Documents/storage" "$HOME/.local"

mkdir -p "$BASE_DIR/lib"
cp "$project_dir/lib/job-completed-cleanup.sh" "$BASE_DIR/lib/"
cp "$project_dir/lib/workspace.sh" "$BASE_DIR/lib/"
chmod +x "$BASE_DIR/lib/job-completed-cleanup.sh"
cat > "$runner_dir/run.sh" <<'RUNNER'
#!/bin/bash
printf '%s\n%s\n%s\n' "$RUNNER_FLEET_WORK_DIR" "$RUNNER_FLEET_RUNNER_DIR" \
    "$ACTIONS_RUNNER_HOOK_JOB_COMPLETED" > "$(dirname "$0")/started"
RUNNER
BLUE='' RED='' GREEN='' YELLOW=''
print_color() { :; }
pgrep() { return 1; }
start_all_runners <<< ''
wait
assert_equal "$(sed -n '1p' "$runner_dir/started")" "$expected"
assert_equal "$(sed -n '2p' "$runner_dir/started")" "$runner_dir"
assert_equal "$(sed -n '3p' "$runner_dir/started")" "$BASE_DIR/lib/job-completed-cleanup.sh"

rm "$runner_dir/started"
pgrep() { return 0; }
start_all_runners <<< ''
[ ! -e "$runner_dir/started" ] || fail "Already running runner restarted"

printf '{"workFolder":"_work"}\n' > "$runner_dir/.runner"
print_color() { printf '%s\n' "$*"; }
output=$(start_all_runners <<< '')
case "$output" in
    *"Workspace migration NOT applied"*) ;;
    *) fail "Running legacy runner did not report pending migration" ;;
esac
assert_equal "$(jq -r .workFolder "$runner_dir/.runner")" "_work"
rm "$runner_dir/.runner"
print_color() { :; }

pgrep() {
    case "$*" in
        *Listener*) return 0 ;;
        *) return 1 ;;
    esac
}
start_all_runners <<< ''
[ ! -e "$runner_dir/started" ] || fail "Active service runner restarted"

pgrep() { return 1; }
printf 'invalid json\n' > "$runner_dir/.runner"
start_all_runners <<< ''
[ ! -e "$runner_dir/started" ] || fail "Runner started with invalid configuration"
rm "$runner_dir/.runner"

mkdir -p "$expected/repo"
touch "$expected/repo/remove"
cleanup_temp_files <<< $'2\n'
[ ! -e "$expected/repo" ] || fail "Manual cleanup missed external workspace"
[ -f "$expected/_tool/keep" ] || fail "Manual cleanup removed tools"

mkdir -p "$expected/repo"
touch "$expected/repo/keep"
pgrep() { return 0; }
cleanup_temp_files <<< $'2\n'
[ -f "$expected/repo/keep" ] || fail "Manual cleanup touched active workspace"

cat > "$runner_dir/config.sh" <<'CONFIG'
#!/bin/bash
printf '%s\n' "$@" > config.args
CONFIG
chmod +x "$runner_dir/config.sh"
(setup_single_runner "$runner_dir" "https://github.com/example/repo" "fake-token" "runner-one" "")
assert_equal "$(sed -n '/^--work$/{n;p;}' "$runner_dir/config.args")" "$expected"

printf 'PASS: workspace preparation, migration, startup and cleanup\n'
