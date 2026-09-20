#!/usr/bin/env bash
#
# Test runner for the codex-subagent wrapper.
#
# Observes the wrapper only through its command line, stdin, stdout, stderr, exit code and the
# run directory it creates. A fake `codex` first on PATH means nothing here reaches the real CLI.
# Run with: bash tests/run-tests.sh

set -uo pipefail

TESTS_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$TESTS_DIR/.." && pwd)
WRAPPER="$REPO_ROOT/plugins/codex-subagent/scripts/codex-subagent.sh"

PATH="$TESTS_DIR/fake-codex:$PATH"
export PATH

RUN_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/codex-subagent-tests.XXXXXX")
trap 'rm -rf "$RUN_ROOT"' EXIT

pass_count=0
fail_count=0
current_case=""
case_dir=""

pass() {
  pass_count=$((pass_count + 1))
  printf 'ok   %s: %s\n' "$current_case" "$1"
}

fail() {
  fail_count=$((fail_count + 1))
  printf 'FAIL %s: %s\n' "$current_case" "$1" >&2
}

assert_eq() { # assert_eq <expected> <actual> <label>
  if [[ "$1" == "$2" ]]; then
    pass "$3"
  else
    fail "$3 (expected '$1', got '$2')"
  fi
}

assert_contains() { # assert_contains <haystack> <needle> <label>
  if [[ "$1" == *"$2"* ]]; then
    pass "$3"
  else
    fail "$3 (missing '$2')"
  fi
}

assert_not_contains() { # assert_not_contains <haystack> <needle> <label>
  if [[ "$1" == *"$2"* ]]; then
    fail "$3 (found '$2')"
  else
    pass "$3"
  fi
}

assert_file_exists() { # assert_file_exists <path> <label>
  if [[ -f "$1" ]]; then
    pass "$2"
  else
    fail "$2 (no such file: $1)"
  fi
}

latest_argv_file() {
  local n
  n=$(cat "$FAKE_CODEX_RECORD_DIR/count" 2>/dev/null) || n=0
  printf '%s\n' "$FAKE_CODEX_RECORD_DIR/argv.$n"
}

assert_argv_has() { # assert_argv_has <flag> [value]
  local argv_file line_no
  argv_file=$(latest_argv_file)
  if [[ ! -f "$argv_file" ]]; then
    fail "argv has $1 (codex was never invoked)"
    return
  fi
  line_no=$(grep -Fxn -- "$1" "$argv_file" | head -n1 | cut -d: -f1)
  if [[ -z "$line_no" ]]; then
    fail "argv has $1"
    return
  fi
  if (($# < 2)); then
    pass "argv has $1"
    return
  fi
  local actual
  actual=$(sed -n "$((line_no + 1))p" "$argv_file")
  assert_eq "$2" "$actual" "argv has $1 $2"
}

assert_argv_lacks() { # assert_argv_lacks <substring>
  local argv_file
  argv_file=$(latest_argv_file)
  if [[ ! -f "$argv_file" ]]; then
    pass "argv lacks $1"
    return
  fi
  if grep -Fq -- "$1" "$argv_file"; then
    fail "argv lacks $1 (found it)"
  else
    pass "argv lacks $1"
  fi
}

setup_case() { # setup_case <name>
  current_case=$1
  case_dir="$RUN_ROOT/$1"
  mkdir -p "$case_dir/repo" "$case_dir/record" "$case_dir/tmp"

  unset FAKE_CODEX_EXIT FAKE_CODEX_RESUME_EXIT FAKE_CODEX_RESUME_EMIT_THREAD
  unset FAKE_CODEX_THREAD_ID FAKE_CODEX_FINAL_MESSAGE FAKE_CODEX_SLEEP
  export FAKE_CODEX_RECORD_DIR="$case_dir/record"
  export TMPDIR="$case_dir/tmp"

  cd "$case_dir/repo" || return 1
  git init -q -b main . 2>/dev/null || git init -q .
  git config user.name "codex-subagent tests"
  git config user.email "tests@example.invalid"
  printf 'seed\n' >seed.txt
  git add seed.txt
  git commit -qm "seed"
}

run_case() { # run_case <function>
  local fn=$1
  setup_case "${fn#case_}" || {
    fail "setup failed"
    return
  }
  "$fn"
  cd "$RUN_ROOT" || true
}

# --- ticket 01 ---

case_unknown_subcommand() {
  local status
  bash "$WRAPPER" frobnicate --model m --effort high >"$case_dir/out" 2>"$case_dir/err" </dev/null
  status=$?
  assert_eq 64 "$status" "unknown subcommand exits 64"
  assert_contains "$(cat "$case_dir/err")" "codex-subagent: " "reason on stderr"
  assert_eq 1 "$(wc -l <"$case_dir/err" | tr -d ' ')" "exactly one line on stderr"
}

case_missing_model() {
  local status
  bash "$WRAPPER" run --effort high >"$case_dir/out" 2>"$case_dir/err" </dev/null
  status=$?
  assert_eq 65 "$status" "missing --model exits 65"
  assert_contains "$(cat "$case_dir/err")" "codex-subagent: " "reason on stderr"
  assert_contains "$(cat "$case_dir/err")" "--model" "reason names --model"
}

case_missing_effort() {
  local status
  bash "$WRAPPER" run --model some-model >"$case_dir/out" 2>"$case_dir/err" </dev/null
  status=$?
  assert_eq 66 "$status" "missing --effort exits 66"
  assert_contains "$(cat "$case_dir/err")" "--effort" "reason names --effort"
}

case_terminal_stdin() {
  # `script` hands the wrapper a real tty on fd 0; the inner shell reports the status out of band
  # because BSD `script` does not reliably propagate it.
  local status
  script -q /dev/null bash -c \
    "bash '$WRAPPER' run --model some-model --effort high >'$case_dir/out' 2>'$case_dir/err'; printf '%s' \$? >'$case_dir/status'" \
    >/dev/null 2>&1
  if [[ ! -f "$case_dir/status" ]]; then
    fail "terminal stdin: script(1) did not run the wrapper"
    return
  fi
  status=$(cat "$case_dir/status")
  assert_eq 67 "$status" "terminal on stdin exits 67"
  assert_contains "$(cat "$case_dir/err")" "terminal" "reason names the terminal"
}

case_wrapper_has_no_bypass() {
  local source
  source=$(cat "$WRAPPER")
  local forbidden
  for forbidden in dangerously danger-full-access add-dir approve-for-me ephemeral skip-git-repo-check; do
    assert_not_contains "$source" "$forbidden" "wrapper source omits '$forbidden'"
  done
}

# --- ticket 02 ---

t2_status=0
t2_run_dir=""

# Quotes, a shell variable, backticks, a non-ASCII character and a trailing newline: anything a
# layer of shell quoting would mangle on the way to Codex.
t2_write_prompt() { # t2_write_prompt <path>
  printf '%s\n' 'He said "hi"; $VAR stays literal, `date` too — café.' >"$1"
}

t2_run() { # t2_run <prompt-file> [extra wrapper args...]
  local prompt=$1
  shift
  bash "$WRAPPER" run --model test-model --effort high "$@" \
    <"$prompt" >"$case_dir/out" 2>"$case_dir/err"
  t2_status=$?
  t2_run_dir=$(head -n1 "$case_dir/out")
}

t2_assert_argv_pair() { # t2_assert_argv_pair <flag> <value>: value present and preceded by flag
  local argv_file line_no
  argv_file=$(latest_argv_file)
  line_no=$(grep -Fxn -- "$2" "$argv_file" 2>/dev/null | head -n1 | cut -d: -f1)
  if [[ -z "$line_no" ]]; then
    fail "argv has $1 $2 (no such argument)"
    return
  fi
  assert_eq "$1" "$(sed -n "$((line_no - 1))p" "$argv_file")" "argv has $1 $2"
}

t2_forbidden_args() {
  printf '%s\n' --ask-for-approval --ephemeral --dangerously-bypass-approvals-and-sandbox \
    --dangerously-bypass-hook-trust danger-full-access --add-dir --approve-for-me \
    --worktree --search --skip-git-repo-check
}

case_run_read_only_sandbox() {
  t2_write_prompt "$case_dir/prompt"
  t2_run "$case_dir/prompt" --read-only
  assert_eq 0 "$t2_status" "read-only run exits 0"
  assert_argv_has --sandbox read-only
}

case_run_default_sandbox() {
  t2_write_prompt "$case_dir/prompt"
  t2_run "$case_dir/prompt"
  assert_eq 0 "$t2_status" "default run exits 0"
  assert_argv_has --sandbox workspace-write
}

case_run_overrides() {
  local toplevel argv_file
  toplevel=$(git rev-parse --show-toplevel)
  t2_write_prompt "$case_dir/prompt"
  t2_run "$case_dir/prompt"
  argv_file=$(latest_argv_file)

  assert_eq exec "$(sed -n 1p "$argv_file")" "first argument is exec"
  assert_argv_has -m test-model
  assert_argv_has -C "$toplevel"
  assert_argv_has --json
  assert_argv_has -o "$t2_run_dir/final-message.md"
  t2_assert_argv_pair -c 'model_reasoning_effort="high"'
  t2_assert_argv_pair -c 'web_search="live"'
  t2_assert_argv_pair -c 'sandbox_workspace_write.network_access=true'
  assert_eq '-' "$(tail -n1 "$argv_file")" "last argument is - so the prompt comes from stdin"
}

case_run_carries_no_bypass() {
  local forbidden recorded
  t2_write_prompt "$case_dir/prompt"
  t2_run "$case_dir/prompt"
  recorded=$(cat "$t2_run_dir/argv")
  while read -r forbidden; do
    assert_argv_lacks "$forbidden"
    assert_not_contains "$recorded" "$forbidden" "run dir argv lacks $forbidden"
  done < <(t2_forbidden_args)
}

case_run_stdin_byte_for_byte() {
  t2_write_prompt "$case_dir/prompt"
  t2_run "$case_dir/prompt"
  if cmp -s "$case_dir/prompt" "$FAKE_CODEX_RECORD_DIR/stdin.1"; then
    pass "prompt bytes reach codex stdin unchanged"
  else
    fail "prompt bytes reach codex stdin unchanged"
  fi
  if cmp -s "$case_dir/prompt" "$t2_run_dir/prompt.md"; then
    pass "prompt is buffered to the run dir unchanged"
  else
    fail "prompt is buffered to the run dir unchanged"
  fi
}

case_run_directory_contents() {
  local name
  export FAKE_CODEX_THREAD_ID="aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
  export FAKE_CODEX_FINAL_MESSAGE="done and dusted"
  t2_write_prompt "$case_dir/prompt"
  t2_run "$case_dir/prompt"

  for name in progress.log events.jsonl final-message.md pid thread-id exit-code argv prompt.md; do
    assert_file_exists "$t2_run_dir/$name" "run dir has $name"
  done
  assert_eq "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee" "$(cat "$t2_run_dir/thread-id")" \
    "thread-id is the id from the event stream"
  assert_eq 0 "$(cat "$t2_run_dir/exit-code")" "exit-code records 0"
  assert_contains "$(cat "$t2_run_dir/final-message.md")" "done and dusted" "final message is written"
  assert_contains "$(cat "$t2_run_dir/progress.log")" "fake-codex" "progress log holds codex stderr"
  assert_contains "$(cat "$t2_run_dir/events.jsonl")" "thread.started" "events.jsonl holds codex stdout"
  assert_eq "$(cat "$t2_run_dir/pid")" "$(cat "$t2_run_dir/pid" | tr -cd '0-9')" "pid file holds a number"
}

case_run_prints_run_dir_first() {
  t2_write_prompt "$case_dir/prompt"
  t2_run "$case_dir/prompt"
  if [[ -d "$t2_run_dir" ]]; then
    pass "first stdout line is the run directory"
  else
    fail "first stdout line is the run directory (got '$t2_run_dir')"
  fi
  assert_eq 1 "$(wc -l <"$case_dir/out" | tr -d ' ')" "stdout is that one line"
  assert_contains "$t2_run_dir" "$TMPDIR/codex-subagent/" "run directory sits under the temp root"
}

case_run_passes_through_exit_code() {
  t2_write_prompt "$case_dir/prompt"

  export FAKE_CODEX_EXIT=0
  t2_run "$case_dir/prompt"
  assert_eq 0 "$t2_status" "wrapper exits 0 when codex exits 0"

  export FAKE_CODEX_EXIT=3
  t2_run "$case_dir/prompt"
  assert_eq 3 "$t2_status" "wrapper exits 3 when codex exits 3"
  assert_eq 3 "$(cat "$t2_run_dir/exit-code")" "exit-code records 3"
}

# --- ticket 03 ---

# The status check, copied verbatim from the "Status check" section of SKILL.md, so this test
# covers the command as documented. Only two things change in the copy: the snippet's first line
# (`d=<run dir>`) becomes this function's argument, and the body is indented into the function.
# Keep the two in step: an edit to the skill's snippet is an edit here.
t3_status_check() { # t3_status_check <run dir>
  local d=$1
  pid=$(cat "$d/pid")
  if kill -0 "$pid" 2>/dev/null; then
    echo "pid $pid: alive"
  else
    echo "pid $pid: exited, exit code $(cat "$d/exit-code" 2>/dev/null || echo 'not recorded')"
  fi
  newest=0
  for f in "$d/events.jsonl" "$d/progress.log"; do
    # GNU stat first: BSD stat rejects -c, and BSD's -f prints a mount point under GNU.
    m=$(stat -c %Y "$f" 2>/dev/null || stat -f %m "$f" 2>/dev/null) || m=0
    [ "$m" -gt "$newest" ] && newest=$m
  done
  echo "seconds since the log last moved: $(( $(date +%s) - newest ))"
  for f in "$d/events.jsonl" "$d/progress.log"; do
    if [ -s "$f" ]; then
      echo "--- tail $f"
      tail -n 5 "$f"
    fi
  done
}

t3_seconds_since() { # t3_seconds_since <check output>
  printf '%s\n' "$1" | sed -n 's/^seconds since the log last moved: //p'
}

case_status_check_mid_run_and_after() {
  local wrapper_pid run_dir="" mid after status secs i

  printf 'watch me work\n' >"$case_dir/prompt"
  export FAKE_CODEX_SLEEP=3
  bash "$WRAPPER" run --model test-model --effort high \
    <"$case_dir/prompt" >"$case_dir/out" 2>"$case_dir/err" &
  wrapper_pid=$!

  # The run directory is the wrapper's first stdout line; the pid file appears once codex starts.
  for i in $(seq 1 100); do
    run_dir=$(head -n1 "$case_dir/out" 2>/dev/null)
    [[ -n "$run_dir" && -f "$run_dir/pid" ]] && break
    sleep 0.1
  done
  if [[ -z "$run_dir" || ! -f "$run_dir/pid" ]]; then
    fail "run directory with a pid file appears while the run is live"
    wait "$wrapper_pid"
    return
  fi
  pass "run directory with a pid file appears while the run is live"

  mid=$(t3_status_check "$run_dir")
  assert_contains "$mid" "alive" "mid-run check reports the pid alive"
  assert_not_contains "$mid" "exited" "mid-run check does not report an exit"
  secs=$(t3_seconds_since "$mid")
  if [[ -n "$secs" ]] && ((secs >= 0 && secs < 10)); then
    pass "mid-run check reports a fresh log (${secs}s since it moved)"
  else
    fail "mid-run check reports a fresh log (got '$secs')"
  fi

  wait "$wrapper_pid"
  status=$?
  assert_eq 0 "$status" "the sleeping run exits 0"

  after=$(t3_status_check "$run_dir")
  assert_contains "$after" "exited" "check after the run reports the pid exited"
  assert_contains "$after" "exit code 0" "check after the run shows the recorded exit code"
  assert_contains "$after" "--- tail $run_dir/events.jsonl" "check tails events.jsonl"
  assert_contains "$after" "thread.started" "events tail shows the event stream"
  assert_contains "$after" "--- tail $run_dir/progress.log" "check tails progress.log"
  assert_contains "$after" "fake-codex: progress 3" "progress tail shows the last stderr lines"
  if [[ -n "$(t3_seconds_since "$after")" ]]; then
    pass "check after the run still reports seconds since the log moved"
  else
    fail "check after the run still reports seconds since the log moved"
  fi
}

# --- run the cases ---

# ticket 01
run_case case_unknown_subcommand
run_case case_missing_model
run_case case_missing_effort
run_case case_terminal_stdin
run_case case_wrapper_has_no_bypass

# ticket 02
run_case case_run_read_only_sandbox
run_case case_run_default_sandbox
run_case case_run_overrides
run_case case_run_carries_no_bypass
run_case case_run_stdin_byte_for_byte
run_case case_run_directory_contents
run_case case_run_prints_run_dir_first
run_case case_run_passes_through_exit_code

# ticket 03
run_case case_status_check_mid_run_and_after

printf 'PASS: %s FAIL: %s\n' "$pass_count" "$fail_count"
((fail_count == 0)) || exit 1
exit 0
