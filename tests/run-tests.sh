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
  unset FAKE_CODEX_FAKE_THREAD_EVENT
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

# The status check is the wrapper's own subcommand, so these cases call it rather than copying a
# snippet out of SKILL.md: the skill and the test can no longer drift apart.

t3_code=0
t3_out=""
t3_err=""

t3_check() { # t3_check <status argument>...
  bash "$WRAPPER" status "$@" >"$case_dir/status-out" 2>"$case_dir/status-err"
  t3_code=$?
  t3_out=$(cat "$case_dir/status-out")
  t3_err=$(cat "$case_dir/status-err")
}

t3_seconds_since() { # t3_seconds_since <check output>
  printf '%s\n' "$1" | sed -n 's/^seconds since the log last moved: //p'
}

t3_assert_fresh_seconds() { # t3_assert_fresh_seconds <check output> <label>
  local secs
  secs=$(t3_seconds_since "$1")
  if [[ -n "$secs" ]] && ((secs >= 0 && secs < 10)); then
    pass "$2 (${secs}s since it moved)"
  else
    fail "$2 (got '$secs')"
  fi
}

# A run that is still going: the pid is alive and the log moved a moment ago.
case_status_mid_run() {
  local wrapper_pid run_dir="" status i

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

  t3_check "$run_dir"
  assert_eq 0 "$t3_code" "status on a live run exits 0"
  assert_contains "$t3_out" "pid $(cat "$run_dir/pid"): alive" "mid-run status reports the pid alive"
  assert_not_contains "$t3_out" "exited" "mid-run status does not report an exit"
  t3_assert_fresh_seconds "$t3_out" "mid-run status reports a fresh log"

  wait "$wrapper_pid"
  status=$?
  assert_eq 0 "$status" "the sleeping run exits 0"
}

# A finished run: the pid has exited and the exit code shown is the one the fake returned.
case_status_after_exit() {
  export FAKE_CODEX_EXIT=4
  t2_write_prompt "$case_dir/prompt"
  t2_run "$case_dir/prompt"
  assert_eq 4 "$t2_status" "the run exits with the fake's code"

  t3_check "$t2_run_dir"
  assert_eq 0 "$t3_code" "status on a finished run exits 0"
  assert_contains "$t3_out" "pid $(cat "$t2_run_dir/pid"): exited, exit code 4" \
    "status reports the pid exited with the fake's exit code"
  assert_contains "$t3_out" "--- tail $t2_run_dir/events.jsonl" "status tails events.jsonl"
  assert_contains "$t3_out" "thread.started" "the events tail shows the event stream"
  assert_contains "$t3_out" "--- tail $t2_run_dir/progress.log" "status tails progress.log"
  assert_contains "$t3_out" "fake-codex" "the progress tail shows the last stderr lines"
  if [[ -n "$(t3_seconds_since "$t3_out")" ]]; then
    pass "status still reports seconds since the log moved after the run"
  else
    fail "status still reports seconds since the log moved after the run"
  fi
}

# The thread id is on the status output, so a follow-up needs no second file read.
case_status_thread_id() {
  export FAKE_CODEX_THREAD_ID="$t4_thread"
  t2_write_prompt "$case_dir/prompt"
  t2_run "$case_dir/prompt"

  t3_check "$t2_run_dir"
  assert_eq 0 "$t3_code" "status after a run with a thread exits 0"
  assert_contains "$t3_out" "thread id: $t4_thread" "status prints the thread id"
}

# A review says what diff Codex read, straight from the run's own record of the scope.
case_status_review_scope() {
  t5_write_focus "$case_dir/focus"
  t5_review "$case_dir/focus" --uncommitted
  assert_eq 0 "$t5_status" "the review exits 0"

  t3_check "$t5_run_dir"
  assert_eq 0 "$t3_code" "status on a review exits 0"
  assert_contains "$t3_out" "review scope: --uncommitted" "status prints the review scope"
  assert_contains "$t3_out" "review scope delivered as: instructions" \
    "status prints how the scope was delivered"
}

# An abandoned resume shows up at the first status check, with the reason the wrapper recorded.
case_status_resume_fallback() {
  export FAKE_CODEX_RESUME_EXIT=1
  export FAKE_CODEX_RESUME_EMIT_THREAD=0
  export FAKE_CODEX_THREAD_ID="$t4_fresh_thread"
  t4_write_prompt "$case_dir/prompt"
  t4_run "$case_dir/prompt" --resume "$t4_thread"
  assert_file_exists "$t4_run_dir/resume-fallback" "the run dir records the abandoned resume"

  t3_check "$t4_run_dir"
  assert_eq 0 "$t3_code" "status on a fallen-back run exits 0"
  assert_contains "$t3_out" "resume fell back to a fresh run:" "status flags the fallback"
  assert_contains "$t3_out" "$(cat "$t4_run_dir/resume-fallback")" \
    "status quotes the recorded reason"
}

# A path that is not a run directory is an error, not an empty report.
case_status_missing_directory() {
  t3_check "$case_dir/no-such-run"
  assert_eq 64 "$t3_code" "status on a missing directory exits 64"
  assert_eq "" "$t3_out" "status on a missing directory prints no report"
  assert_contains "$t3_err" "codex-subagent:" "status on a missing directory says so on stderr"
}

# Status takes no flags: one is a mistake, not a run directory.
case_status_rejects_a_flag() {
  t2_write_prompt "$case_dir/prompt"
  t2_run "$case_dir/prompt"

  t3_check --read-only "$t2_run_dir"
  assert_eq 64 "$t3_code" "status with a flag exits 64"
  assert_eq "" "$t3_out" "status with a flag prints no report"
}

case_status_missing_argument() {
  t3_check
  assert_eq 64 "$t3_code" "status with no run directory exits 64"
  assert_eq "" "$t3_out" "status with no run directory prints no report"
  assert_contains "$t3_err" "codex-subagent:" "status with no run directory says so on stderr"
}

# A run directory this wrapper wrote holds a `pid` file. A readable directory without one is some
# other directory, so the path is wrong: an error, not a report with nothing in it.
case_status_plain_directory() {
  mkdir -p "$case_dir/not-a-run"
  t3_check "$case_dir/not-a-run"
  assert_eq 64 "$t3_code" "status on a directory with no pid file exits 64"
  assert_eq "" "$t3_out" "status on a directory with no pid file prints no report"
  assert_contains "$t3_err" "codex-subagent:" "status on a plain directory says so on stderr"
}

# A run directory checked before codex has started: the wrapper has written the prompt but no pid
# yet. That is a real run directory, so the check reports it rather than refusing it.
case_status_before_codex_starts() {
  mkdir -p "$case_dir/early-run"
  printf 'prompt\n' >"$case_dir/early-run/prompt.md"
  t3_check "$case_dir/early-run"
  assert_eq 0 "$t3_code" "status on a run that has not started exits 0"
  assert_contains "$t3_out" "pid: not started yet" "status says the run has not started"
  assert_not_contains "$t3_out" "alive" "status does not call an unstarted run alive"
  assert_contains "$t3_out" "no progress log yet" "status reports no log to age yet"
}

# A finished run's state comes from `exit-code`, not from the pid: the fixture's pid is this test
# shell, alive and unrelated, which is exactly what a recycled pid looks like from here.
case_status_exit_code_beats_a_live_pid() {
  mkdir -p "$case_dir/finished"
  printf '%s\n' "$$" >"$case_dir/finished/pid"
  printf '3\n' >"$case_dir/finished/exit-code"

  t3_check "$case_dir/finished"
  assert_eq 0 "$t3_code" "status on a finished fixture exits 0"
  assert_contains "$t3_out" "pid $$: exited, exit code 3" \
    "a recorded exit code is reported even though the pid is alive"
  assert_not_contains "$t3_out" "alive" "the live pid is not reported as this run still going"
}

# A pid file that holds no pid means the wrapper did not write this directory. `-1` is the one
# worth a case of its own: `kill -0 -1` signals every process the user owns, so it never gets there.
case_status_rejects_a_garbage_pid() {
  mkdir -p "$case_dir/garbage-pid" "$case_dir/negative-pid"
  printf 'not-a-pid\n' >"$case_dir/garbage-pid/pid"
  printf -- '-1\n' >"$case_dir/negative-pid/pid"

  t3_check "$case_dir/garbage-pid"
  assert_eq 64 "$t3_code" "status on a non-numeric pid file exits 64"
  assert_eq "" "$t3_out" "status on a non-numeric pid file prints no report"
  assert_contains "$t3_err" "codex-subagent:" "status on a non-numeric pid says so on stderr"

  t3_check "$case_dir/negative-pid"
  assert_eq 64 "$t3_code" "status on a negative pid exits 64"
  assert_eq "" "$t3_out" "status on a negative pid prints no report"
}

# Before the first event lands there is no log to age, so the seconds line says so rather than
# subtracting the 0 sentinel and reporting the age of the epoch.
case_status_before_the_log_moves() {
  mkdir -p "$case_dir/no-logs"
  printf '%s\n' "$$" >"$case_dir/no-logs/pid"

  t3_check "$case_dir/no-logs"
  assert_eq 0 "$t3_code" "status with no log files exits 0"
  assert_contains "$t3_out" "pid $$: alive" "status with no log files reads the pid"
  assert_eq "no progress log yet" "$(t3_seconds_since "$t3_out")" \
    "status with no log files says there is no progress log yet"
}


# --- ticket 05 ---

t5_status=0
t5_run_dir=""

t5_write_focus() { # t5_write_focus <path>
  printf '%s\n' 'Watch the "retry" path; $BACKOFF is off-by-one — café.' >"$1"
}

t5_review() { # t5_review <focus-file> [extra wrapper args...]
  local focus=$1
  shift
  bash "$WRAPPER" review --model test-model --effort medium "$@" \
    <"$focus" >"$case_dir/out" 2>"$case_dir/err"
  t5_status=$?
  t5_run_dir=$(head -n1 "$case_dir/out")
}

t5_dirty_the_tree() {
  printf 'edited\n' >>seed.txt
}

# Which scope the wrapper settled on. Every case using this sends a non-empty focus, and Codex
# refuses a scope flag together with custom instructions, so the scope does not reach codex as
# argv here -- the run dir's record of it is what stays observable. The argv side of the same
# choice is asserted under "review focus vs scope" below.
t5_assert_scope() { # t5_assert_scope <flag> [value]
  local argv_file expected
  argv_file=$(latest_argv_file)
  assert_eq exec "$(sed -n 1p "$argv_file")" "first argument is exec"
  assert_eq review "$(sed -n 2p "$argv_file")" "second argument is review"
  assert_argv_lacks "$1"
  # One argument per line, so a branch name with a space stays one argument here too.
  expected=$(printf '%s\n' "$@" "delivered-as: instructions")
  assert_eq "$expected" "$(cat "$t5_run_dir/review-scope")" \
    "review-scope records '$*'"
}

case_review_scope_uncommitted() {
  t5_write_focus "$case_dir/focus"
  t5_review "$case_dir/focus" --uncommitted
  assert_eq 0 "$t5_status" "review --uncommitted exits 0"
  t5_assert_scope --uncommitted
}

case_review_scope_base() {
  t5_write_focus "$case_dir/focus"
  t5_review "$case_dir/focus" --base foo
  assert_eq 0 "$t5_status" "review --base exits 0"
  t5_assert_scope --base foo
}

case_review_scope_commit() {
  t5_write_focus "$case_dir/focus"
  t5_review "$case_dir/focus" --commit abc123
  assert_eq 0 "$t5_status" "review --commit exits 0"
  t5_assert_scope --commit abc123
}

case_review_conflicting_scopes() {
  local status
  t5_write_focus "$case_dir/focus"

  t5_review "$case_dir/focus" --uncommitted --base foo
  assert_eq 64 "$t5_status" "--uncommitted with --base exits 64"
  assert_contains "$(cat "$case_dir/err")" "codex-subagent: " "reason on stderr"

  t5_review "$case_dir/focus" --base foo --commit abc123
  assert_eq 64 "$t5_status" "--base with --commit exits 64"

  t5_review "$case_dir/focus" --commit abc123 --uncommitted
  assert_eq 64 "$t5_status" "--commit with --uncommitted exits 64"

  status=$(cat "$FAKE_CODEX_RECORD_DIR/count" 2>/dev/null) || status=0
  assert_eq 0 "$status" "a conflicting scope never reaches codex"
}

case_review_default_scope_dirty() {
  t5_write_focus "$case_dir/focus"
  t5_dirty_the_tree
  t5_review "$case_dir/focus"
  assert_eq 0 "$t5_status" "review with no scope exits 0"
  t5_assert_scope --uncommitted
  assert_argv_lacks "--base"
}

case_review_default_scope_clean() {
  local branch
  branch=$(git rev-parse --abbrev-ref HEAD)
  t5_write_focus "$case_dir/focus"
  t5_review "$case_dir/focus"
  assert_eq 0 "$t5_status" "review of a clean tree exits 0"
  t5_assert_scope --base "$branch"
  assert_argv_lacks "--uncommitted"
}

case_review_default_scope_origin_head() {
  # A symref is enough: git does not require the branch it points at to exist locally.
  git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/develop
  t5_write_focus "$case_dir/focus"
  t5_review "$case_dir/focus"
  assert_eq 0 "$t5_status" "review against origin/HEAD exits 0"
  t5_assert_scope --base origin/develop
}

case_review_focus_on_stdin() {
  local argv_file
  t5_write_focus "$case_dir/focus"
  t5_review "$case_dir/focus" --uncommitted
  argv_file=$(latest_argv_file)
  assert_eq '-' "$(tail -n1 "$argv_file")" "last argument is - so the instructions come from stdin"
  # The focus is composed into the instructions (scope line, blank line, focus), so what reaches
  # stdin is prompt.md; the focus itself is kept beside it, byte for byte, as it arrived.
  if cmp -s "$case_dir/focus" "$t5_run_dir/focus.md"; then
    pass "the focus is buffered to the run dir unchanged"
  else
    fail "the focus is buffered to the run dir unchanged"
  fi
  if cmp -s "$t5_run_dir/prompt.md" "$FAKE_CODEX_RECORD_DIR/stdin.1"; then
    pass "prompt.md is what reaches codex stdin, byte for byte"
  else
    fail "prompt.md is what reaches codex stdin, byte for byte"
  fi
  if tail -n +3 "$FAKE_CODEX_RECORD_DIR/stdin.1" | cmp -s - "$case_dir/focus"; then
    pass "focus bytes reach codex stdin unchanged, after the scope line"
  else
    fail "focus bytes reach codex stdin unchanged, after the scope line"
  fi
}

case_review_empty_focus() {
  : >"$case_dir/focus"
  t5_review "$case_dir/focus" --uncommitted
  assert_eq 0 "$t5_status" "review with an empty focus exits 0"
  if grep -Fxq -- '-' "$(latest_argv_file)"; then
    fail "an empty focus sends no bare - argument"
  else
    pass "an empty focus sends no bare - argument"
  fi
  assert_eq 0 "$(wc -c <"$FAKE_CODEX_RECORD_DIR/stdin.1" | tr -d ' ')" "codex gets empty stdin"
}

case_review_model_and_effort() {
  t5_write_focus "$case_dir/focus"
  t5_review "$case_dir/focus" --uncommitted
  assert_argv_has -m test-model
  assert_argv_has --json
  assert_argv_has -o "$t5_run_dir/final-message.md"
  t2_assert_argv_pair -c 'model_reasoning_effort="medium"'
}

# A review only reads, and says so itself: `codex exec review` has no --sandbox flag, so the
# sandbox is pinned read-only by config override rather than inherited from the user's config, and
# --strict-config turns a key Codex no longer knows into a failure instead of a silent inheritance.
# Nothing overrides the network, which only applies to a workspace-write sandbox.
case_review_pins_read_only_sandbox() {
  local forbidden recorded
  t5_write_focus "$case_dir/focus"
  t5_review "$case_dir/focus" --uncommitted
  recorded=$(cat "$t5_run_dir/argv")
  t2_assert_argv_pair -c 'sandbox_mode="read-only"'
  assert_argv_has --strict-config
  assert_contains "$recorded" 'sandbox_mode="read-only"' "run dir argv records the read-only sandbox"
  # It searches the live web like every other run.
  t2_assert_argv_pair -c 'web_search="live"'
  for forbidden in --sandbox sandbox_workspace_write network_access; do
    assert_argv_lacks "$forbidden"
    assert_not_contains "$recorded" "$forbidden" "run dir argv lacks $forbidden"
  done
  while read -r forbidden; do
    assert_argv_lacks "$forbidden"
    assert_not_contains "$recorded" "$forbidden" "run dir argv lacks $forbidden"
  done < <(t2_forbidden_args)
}

case_review_run_directory_contents() {
  local name
  export FAKE_CODEX_FINAL_MESSAGE="two findings, one blocker"
  t5_write_focus "$case_dir/focus"
  t5_review "$case_dir/focus" --uncommitted
  for name in progress.log events.jsonl final-message.md pid exit-code argv review-scope; do
    assert_file_exists "$t5_run_dir/$name" "run dir has $name"
  done
  assert_contains "$(cat "$t5_run_dir/final-message.md")" "two findings, one blocker" \
    "findings arrive in final-message.md"
  assert_eq 0 "$(cat "$t5_run_dir/exit-code")" "exit-code records 0"
}

case_review_passes_through_exit_code() {
  t5_write_focus "$case_dir/focus"

  export FAKE_CODEX_EXIT=0
  t5_review "$case_dir/focus" --uncommitted
  assert_eq 0 "$t5_status" "wrapper exits 0 when codex exits 0"

  export FAKE_CODEX_EXIT=4
  t5_review "$case_dir/focus" --uncommitted
  assert_eq 4 "$t5_status" "wrapper exits 4 when codex exits 4"
  assert_eq 4 "$(cat "$t5_run_dir/exit-code")" "exit-code records 4"
}

# --- ticket 04 ---

t4_status=0
t4_run_dir=""
t4_thread="aaaaaaaa-1111-2222-3333-444444444444"
t4_fresh_thread="bbbbbbbb-5555-6666-7777-888888888888"

t4_write_prompt() { # t4_write_prompt <path>
  printf '%s\n' 'Follow-up: now fix items 2 and 4 — "as discussed".' >"$1"
}

t4_run() { # t4_run <prompt-file> [extra wrapper args...]
  local prompt=$1
  shift
  bash "$WRAPPER" run --model test-model --effort high "$@" \
    <"$prompt" >"$case_dir/out" 2>"$case_dir/err"
  t4_status=$?
  t4_run_dir=$(head -n1 "$case_dir/out")
}

t4_argv() { # t4_argv <invocation number>
  printf '%s\n' "$FAKE_CODEX_RECORD_DIR/argv.$1"
}

t4_invocations() {
  cat "$FAKE_CODEX_RECORD_DIR/count" 2>/dev/null || printf '0\n'
}

t4_assert_pair() { # t4_assert_pair <argv-file> <flag> <value>: value present and preceded by flag
  local line_no
  line_no=$(grep -Fxn -- "$3" "$1" 2>/dev/null | head -n1 | cut -d: -f1)
  if [[ -z "$line_no" ]]; then
    fail "argv has $2 $3 (no such argument)"
    return
  fi
  assert_eq "$2" "$(sed -n "$((line_no - 1))p" "$1")" "argv has $2 $3"
}

t4_assert_has_line() { # t4_assert_has_line <argv-file> <argument> <label>
  if grep -Fxq -- "$2" "$1" 2>/dev/null; then
    pass "$3"
  else
    fail "$3 (missing '$2')"
  fi
}

t4_assert_lacks_line() { # t4_assert_lacks_line <argv-file> <argument> <label>
  if grep -Fxq -- "$2" "$1" 2>/dev/null; then
    fail "$3 (found '$2')"
  else
    pass "$3"
  fi
}

# Substring, not whole argument: --sandbox=read-only would be just as wrong as --sandbox read-only.
t4_assert_lacks_sandbox_flag() { # t4_assert_lacks_sandbox_flag <argv-file>
  if grep -Fq -- '--sandbox' "$1" 2>/dev/null; then
    fail "resume argv lacks --sandbox (found it)"
  else
    pass "resume argv lacks --sandbox"
  fi
}

t4_assert_same_bytes() { # t4_assert_same_bytes <file-a> <file-b> <label>
  if cmp -s "$1" "$2"; then
    pass "$3"
  else
    fail "$3"
  fi
}

case_thread_id_from_first_event() {
  export FAKE_CODEX_THREAD_ID="$t4_thread"
  t4_write_prompt "$case_dir/prompt"
  t4_run "$case_dir/prompt"
  assert_eq 0 "$t4_status" "fresh run exits 0"
  assert_file_exists "$t4_run_dir/thread-id" "the run records a thread id"
  assert_eq "$t4_thread" "$(cat "$t4_run_dir/thread-id" 2>/dev/null)" \
    "thread-id is the id from the first event"
}

case_resume_argv() {
  export FAKE_CODEX_THREAD_ID="$t4_thread"
  local argv_file
  t4_write_prompt "$case_dir/prompt"
  t4_run "$case_dir/prompt" --resume "$t4_thread"
  argv_file=$(t4_argv 1)

  assert_eq 0 "$t4_status" "resume exits 0"
  assert_eq 1 "$(t4_invocations)" "a working resume is the only invocation"
  assert_eq exec "$(sed -n 1p "$argv_file")" "first argument is exec"
  assert_eq resume "$(sed -n 2p "$argv_file")" "second argument is resume"
  assert_eq "$t4_thread" "$(sed -n 3p "$argv_file")" "third argument is the thread id"
  t4_assert_pair "$argv_file" -m test-model
  t4_assert_pair "$argv_file" -c 'model_reasoning_effort="high"'
  t4_assert_pair "$argv_file" -c 'web_search="live"'
  t4_assert_has_line "$argv_file" --json "resume argv has --json"
  t4_assert_pair "$argv_file" -o "$t4_run_dir/final-message.md"
  assert_eq '-' "$(tail -n1 "$argv_file")" "last argument is - so the prompt comes from stdin"
  t4_assert_lacks_line "$argv_file" -C "resume argv lacks -C, which resume does not accept"
  t4_assert_lacks_sandbox_flag "$argv_file"
  t4_assert_same_bytes "$case_dir/prompt" "$FAKE_CODEX_RECORD_DIR/stdin.1" \
    "the delta reaches codex stdin unchanged"
}

case_resume_sandbox_read_only() {
  local argv_file
  t4_write_prompt "$case_dir/prompt"
  t4_run "$case_dir/prompt" --resume "$t4_thread" --read-only
  argv_file=$(t4_argv 1)
  t4_assert_pair "$argv_file" -c 'sandbox_mode="read-only"'
  t4_assert_lacks_sandbox_flag "$argv_file"
}

case_resume_sandbox_workspace_write() {
  local argv_file
  t4_write_prompt "$case_dir/prompt"
  t4_run "$case_dir/prompt" --resume "$t4_thread"
  argv_file=$(t4_argv 1)
  t4_assert_pair "$argv_file" -c 'sandbox_mode="workspace-write"'
  t4_assert_lacks_sandbox_flag "$argv_file"
}

# A resume that dies before the thread starts is abandoned: the same prompt runs fresh, in the
# sandbox this call asked for, and the fresh run's status and thread id are the ones that count.
t4_fallback_case() { # t4_fallback_case <expected sandbox> [wrapper args...]
  local expected=$1
  shift
  local first second name
  export FAKE_CODEX_RESUME_EXIT=1
  export FAKE_CODEX_RESUME_EMIT_THREAD=0
  export FAKE_CODEX_THREAD_ID="$t4_fresh_thread"
  t4_write_prompt "$case_dir/prompt"
  t4_run "$case_dir/prompt" --resume "$t4_thread" "$@"
  first=$(t4_argv 1)
  second=$(t4_argv 2)

  assert_eq 2 "$(t4_invocations)" "the abandoned resume and the fresh run are both invoked"
  assert_eq resume "$(sed -n 2p "$first")" "the first invocation is the resume"
  assert_eq exec "$(sed -n 1p "$second")" "the second invocation is a fresh exec"
  t4_assert_lacks_line "$second" resume "the fresh run does not resume"
  t4_assert_pair "$second" --sandbox "$expected"
  t4_assert_same_bytes "$case_dir/prompt" "$FAKE_CODEX_RECORD_DIR/stdin.2" \
    "the fresh run gets the same prompt bytes"
  assert_file_exists "$t4_run_dir/resume-fallback" "the run dir records the abandoned resume"
  assert_contains "$(cat "$case_dir/err")" \
    "codex-subagent: resume of $t4_thread failed before thread start; starting a fresh run" \
    "stderr says the resume was abandoned"
  assert_eq 0 "$t4_status" "the wrapper exits with the fresh run's status"
  assert_eq 0 "$(cat "$t4_run_dir/exit-code" 2>/dev/null)" "exit-code is the fresh run's"
  assert_eq "$t4_fresh_thread" "$(cat "$t4_run_dir/thread-id" 2>/dev/null)" \
    "thread-id holds the fresh run's id"
  for name in resume-argv resume-events.jsonl resume-progress.log; do
    assert_file_exists "$t4_run_dir/$name" "the abandoned attempt's $name is kept"
  done
}

case_resume_fallback_workspace_write() {
  t4_fallback_case workspace-write
}

case_resume_fallback_read_only() {
  t4_fallback_case read-only --read-only
}

# A fallback does not swallow the failure that follows it: the status the wrapper exits with, and
# the one it records, are the fresh run's, not the abandoned resume's and not a success.
case_resume_fallback_keeps_the_fresh_runs_failure() {
  export FAKE_CODEX_RESUME_EXIT=1
  export FAKE_CODEX_RESUME_EMIT_THREAD=0
  export FAKE_CODEX_EXIT=5
  t4_write_prompt "$case_dir/prompt"
  t4_run "$case_dir/prompt" --resume "$t4_thread"

  assert_eq 2 "$(t4_invocations)" "the abandoned resume and the failing fresh run are both invoked"
  assert_file_exists "$t4_run_dir/resume-fallback" "the run dir records the abandoned resume"
  assert_eq 5 "$t4_status" "the wrapper exits with the fresh run's status, not the resume's"
  assert_eq 5 "$(cat "$t4_run_dir/exit-code" 2>/dev/null)" "exit-code records the fresh run's 5"
}

# A resume that fails after its thread started is an ordinary failed run, not a stale thread.
case_resume_failure_after_thread_start() {
  export FAKE_CODEX_RESUME_EXIT=2
  export FAKE_CODEX_THREAD_ID="$t4_thread"
  t4_write_prompt "$case_dir/prompt"
  t4_run "$case_dir/prompt" --resume "$t4_thread"

  assert_eq 2 "$t4_status" "the wrapper passes through the resume's status"
  assert_eq 1 "$(t4_invocations)" "no fresh run follows"
  if [[ -e "$t4_run_dir/resume-fallback" ]]; then
    fail "no fallback is recorded"
  else
    pass "no fallback is recorded"
  fi
  assert_not_contains "$(cat "$case_dir/err")" "starting a fresh run" \
    "stderr claims no fallback"
  assert_eq 2 "$(cat "$t4_run_dir/exit-code" 2>/dev/null)" "exit-code records 2"
}

# --- fix pass ---

# An unrecognised config key is only rejected under --strict-config, and that is how the sandbox
# travels on both forms that have no --sandbox flag: without it a renamed key would silently leave
# the sandbox to the thread on a resume and to the user's config on a review. A fresh run carries
# the sandbox as a real flag, so it needs no such guard.
case_strict_config_where_the_sandbox_is_config() {
  t4_write_prompt "$case_dir/prompt"

  t4_run "$case_dir/prompt"
  assert_argv_lacks --strict-config

  t4_run "$case_dir/prompt" --resume "$t4_thread"
  assert_argv_has --strict-config

  t5_write_focus "$case_dir/focus"
  t5_review "$case_dir/focus" --uncommitted
  assert_argv_has --strict-config
}

# An event that merely mentions a thread id is not a thread that started: nothing is recorded as
# the thread, and a resume that dies with only such an event still falls back to a fresh run.
case_thread_id_needs_thread_started() {
  export FAKE_CODEX_FAKE_THREAD_EVENT=1
  export FAKE_CODEX_RESUME_EXIT=1
  t4_write_prompt "$case_dir/prompt"

  t4_run "$case_dir/prompt"
  assert_contains "$(cat "$t4_run_dir/events.jsonl")" "thread_id" "the fake event carries a thread id"
  if [[ -e "$t4_run_dir/thread-id" ]]; then
    fail "no thread-id is recorded from an event that is not thread.started"
  else
    pass "no thread-id is recorded from an event that is not thread.started"
  fi

  t4_run "$case_dir/prompt" --resume "$t4_thread"
  assert_file_exists "$t4_run_dir/resume-fallback" "the resume falls back to a fresh run"
  assert_contains "$(cat "$case_dir/err")" "starting a fresh run" "stderr says the resume was abandoned"
  if [[ -e "$t4_run_dir/thread-id" ]]; then
    fail "the fallback run records no thread id either"
  else
    pass "the fallback run records no thread id either"
  fi
}

# A dropped value would otherwise make the next flag the value: `--base --commit` reviewed a branch
# named `--commit`.
case_flag_value_that_is_a_flag() {
  local status
  t4_write_prompt "$case_dir/prompt"

  bash "$WRAPPER" run --model --effort high <"$case_dir/prompt" >/dev/null 2>"$case_dir/err"
  assert_eq 64 "$?" "--model followed by a flag exits 64"
  assert_contains "$(cat "$case_dir/err")" "codex-subagent: --model needs a value" "reason on stderr"

  bash "$WRAPPER" run --model m --effort --read-only <"$case_dir/prompt" >/dev/null 2>&1
  assert_eq 64 "$?" "--effort followed by a flag exits 64"

  bash "$WRAPPER" run --model m --effort high --resume --read-only <"$case_dir/prompt" >/dev/null 2>&1
  assert_eq 64 "$?" "--resume followed by a flag exits 64"

  bash "$WRAPPER" review --model m --effort high --base --commit <"$case_dir/prompt" >/dev/null 2>&1
  assert_eq 64 "$?" "--base followed by a flag exits 64"

  bash "$WRAPPER" review --model m --effort high --commit --base <"$case_dir/prompt" >/dev/null 2>&1
  assert_eq 64 "$?" "--commit followed by a flag exits 64"

  status=$(cat "$FAKE_CODEX_RECORD_DIR/count" 2>/dev/null) || status=0
  assert_eq 0 "$status" "none of them reach codex"
}

# Choosing a model is a CLAUDE.md edit, never a plugin release, so nothing the plugin runs may name
# one: not the wrapper, not either skill, not the manifest. The plugin README is excluded on purpose
# — it shows one example of the section the setup skill writes, copied from a real run, and a real
# run names the model it ran on. An example in prose starts no run; a name in the wrapper or a skill
# would.
case_plugin_names_no_model() {
  local hits
  hits=$(grep -rn -- 'gpt-' \
    "$REPO_ROOT/plugins/codex-subagent/scripts" \
    "$REPO_ROOT/plugins/codex-subagent/skills" \
    "$REPO_ROOT/plugins/codex-subagent/.claude-plugin" 2>/dev/null)
  assert_eq "" "$hits" "no wrapper, skill or manifest file under plugins/ names a model"
}

# --- review focus vs scope ---
#
# codex-cli 0.155.1 treats the positional PROMPT of `codex exec review` as a fourth scope preset,
# mutually exclusive with `--uncommitted`, `--base` and `--commit`: passing a scope flag and a
# prompt together fails in argument parsing and nothing runs. So a review states its scope as a
# flag or in words, never both. The scope sentences are spelled out here rather than sourced from
# the wrapper, so a change to the wording has to be made deliberately in both places.

rf_scope_line() { # rf_scope_line <flag> [value]
  case "$1" in
    --uncommitted)
      printf 'Review the uncommitted changes in the working tree: staged, unstaged, and untracked files.\n'
      ;;
    --base)
      printf 'Review the changes on the current branch relative to the base branch %s, i.e. the diff %s...HEAD.\n' \
        "$2" "$2"
      ;;
    --commit)
      printf 'Review the changes introduced by commit %s.\n' "$2"
      ;;
  esac
}

# What codex should read on stdin: the scope line, a blank line, then the focus bytes unchanged.
rf_assert_stdin() { # rf_assert_stdin <focus-file> <flag> [value]
  local focus=$1
  shift
  {
    rf_scope_line "$@"
    printf '\n'
    cat "$focus"
  } >"$case_dir/expected-stdin"
  if cmp -s "$case_dir/expected-stdin" "$FAKE_CODEX_RECORD_DIR/stdin.1"; then
    pass "stdin is the '$*' scope line, a blank line, then the focus"
  else
    fail "stdin is the '$*' scope line, a blank line, then the focus"
  fi
}

# A focused review carries no scope flag at all, and ends with `-` so codex reads the composed
# instructions from stdin.
rf_assert_no_scope_flag() {
  assert_argv_lacks --uncommitted
  assert_argv_lacks --base
  assert_argv_lacks --commit
  assert_eq '-' "$(tail -n1 "$(latest_argv_file)")" "argv ends with -"
}

case_review_focus_with_uncommitted() {
  t5_write_focus "$case_dir/focus"
  t5_review "$case_dir/focus" --uncommitted
  assert_eq 0 "$t5_status" "--uncommitted with a focus exits 0"
  rf_assert_no_scope_flag
  rf_assert_stdin "$case_dir/focus" --uncommitted
  # Dropping the scope flag drops nothing else: the read-only sandbox is pinned on this delivery
  # route too.
  t2_assert_argv_pair -c 'sandbox_mode="read-only"'
  assert_argv_has --strict-config
}

case_review_focus_with_base() {
  t5_write_focus "$case_dir/focus"
  t5_review "$case_dir/focus" --base release-2
  assert_eq 0 "$t5_status" "--base with a focus exits 0"
  rf_assert_no_scope_flag
  assert_argv_lacks release-2
  rf_assert_stdin "$case_dir/focus" --base release-2
}

case_review_focus_with_commit() {
  t5_write_focus "$case_dir/focus"
  t5_review "$case_dir/focus" --commit abc123
  assert_eq 0 "$t5_status" "--commit with a focus exits 0"
  rf_assert_no_scope_flag
  assert_argv_lacks abc123
  rf_assert_stdin "$case_dir/focus" --commit abc123
}

# The default scope still comes from the tree; only how it is delivered changes.
case_review_focus_default_scope_dirty() {
  t5_write_focus "$case_dir/focus"
  t5_dirty_the_tree
  t5_review "$case_dir/focus"
  assert_eq 0 "$t5_status" "a focused review with no scope flag exits 0"
  rf_assert_no_scope_flag
  assert_eq "$(rf_scope_line --uncommitted)" "$(head -n1 "$FAKE_CODEX_RECORD_DIR/stdin.1")" \
    "a dirty tree opens the instructions with the uncommitted scope line"
  rf_assert_stdin "$case_dir/focus" --uncommitted
}

case_review_focus_default_scope_clean() {
  local branch
  branch=$(git rev-parse --abbrev-ref HEAD)
  t5_write_focus "$case_dir/focus"
  t5_review "$case_dir/focus"
  assert_eq 0 "$t5_status" "a focused review of a clean tree exits 0"
  rf_assert_no_scope_flag
  assert_contains "$(head -n1 "$FAKE_CODEX_RECORD_DIR/stdin.1")" "$branch" \
    "the scope line names the resolved default branch"
  rf_assert_stdin "$case_dir/focus" --base "$branch"
}

# With no focus there are no custom instructions to collide with, so the flag travels as a flag.
case_review_empty_focus_keeps_the_flag() {
  : >"$case_dir/focus"
  t5_review "$case_dir/focus" --base main
  assert_eq 0 "$t5_status" "an empty focus with --base exits 0"
  assert_argv_has --base main
  if grep -Fxq -- '-' "$(latest_argv_file)"; then
    fail "an empty focus sends no bare - argument"
  else
    pass "an empty focus sends no bare - argument"
  fi
  assert_eq 0 "$(wc -c <"$FAKE_CODEX_RECORD_DIR/stdin.1" | tr -d ' ')" "codex gets empty stdin"
}

# The run dir says both what was reviewed and how the scope got there, and keeps the raw focus
# only when there was one.
case_review_scope_records_delivery() {
  t5_write_focus "$case_dir/focus"
  t5_review "$case_dir/focus" --commit abc123
  assert_eq "$(printf '%s\n' --commit abc123 'delivered-as: instructions')" \
    "$(cat "$t5_run_dir/review-scope")" "review-scope records the scope and 'instructions'"
  assert_file_exists "$t5_run_dir/focus.md" "the raw focus is kept beside the composed prompt"

  : >"$case_dir/empty-focus"
  t5_review "$case_dir/empty-focus" --commit abc123
  assert_eq "$(printf '%s\n' --commit abc123 'delivered-as: flag')" \
    "$(cat "$t5_run_dir/review-scope")" "review-scope records the scope and 'flag'"
  if [[ -e "$t5_run_dir/focus.md" ]]; then
    fail "no focus.md is written when there is no focus"
  else
    pass "no focus.md is written when there is no focus"
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
run_case case_status_mid_run
run_case case_status_after_exit
run_case case_status_thread_id
run_case case_status_review_scope
run_case case_status_resume_fallback
run_case case_status_missing_directory
run_case case_status_rejects_a_flag
run_case case_status_missing_argument

# ticket 05
run_case case_review_scope_uncommitted
run_case case_review_scope_base
run_case case_review_scope_commit
run_case case_review_conflicting_scopes
run_case case_review_default_scope_dirty
run_case case_review_default_scope_clean
run_case case_review_default_scope_origin_head
run_case case_review_focus_on_stdin
run_case case_review_empty_focus
run_case case_review_model_and_effort
run_case case_review_pins_read_only_sandbox
run_case case_review_run_directory_contents
run_case case_review_passes_through_exit_code

# ticket 04
run_case case_thread_id_from_first_event
run_case case_resume_argv
run_case case_resume_sandbox_read_only
run_case case_resume_sandbox_workspace_write
run_case case_resume_fallback_workspace_write
run_case case_resume_fallback_read_only
run_case case_resume_fallback_keeps_the_fresh_runs_failure
run_case case_resume_failure_after_thread_start

# fix pass
run_case case_strict_config_where_the_sandbox_is_config
run_case case_thread_id_needs_thread_started
run_case case_flag_value_that_is_a_flag
run_case case_plugin_names_no_model

run_case case_review_focus_with_uncommitted
run_case case_review_focus_with_base
run_case case_review_focus_with_commit
run_case case_review_focus_default_scope_dirty
run_case case_review_focus_default_scope_clean
run_case case_review_empty_focus_keeps_the_flag
run_case case_review_scope_records_delivery

run_case case_status_plain_directory
run_case case_status_before_codex_starts
run_case case_status_exit_code_beats_a_live_pid
run_case case_status_rejects_a_garbage_pid
run_case case_status_before_the_log_moves

printf 'PASS: %s FAIL: %s\n' "$pass_count" "$fail_count"
((fail_count == 0)) || exit 1
exit 0
