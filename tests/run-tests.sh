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

# --- run the cases ---

# ticket 01
run_case case_unknown_subcommand
run_case case_missing_model
run_case case_missing_effort
run_case case_terminal_stdin
run_case case_wrapper_has_no_bypass

printf 'PASS: %s FAIL: %s\n' "$pass_count" "$fail_count"
((fail_count == 0)) || exit 1
exit 0
