#!/usr/bin/env bash
#
# codex-subagent: the wrapper. Claude decides what to send; this script decides how Codex runs.
#
# By design this script offers no bypass and no full access option, and has no code path that
# could add one: every run is sandboxed by Codex as read-only or workspace-write, and the sandbox
# is chosen here, never inherited from a thread or from the user's Codex config.
#
# Usage:
#   codex-subagent.sh run    --model <m> --effort <e> [--read-only] [--resume <thread-id>]
#   codex-subagent.sh review --model <m> --effort <e> [--uncommitted | --base <branch> | --commit <sha>]
#
# The prompt (run) or focus (review) arrives on stdin. The first line of stdout is the run
# directory. The exit status is Codex's own, except for the wrapper's own failures:
#   64 unknown subcommand, unknown flag, or conflicting review scope
#   65 missing --model
#   66 missing --effort
#   67 stdin is a terminal
#   68 not inside a git repository
#   69 codex not found on PATH

set -euo pipefail

die() { # die <exit-code> <reason>
  printf 'codex-subagent: %s\n' "$2" >&2
  exit "$1"
}

subcommand=""
model=""
effort=""
sandbox="workspace-write"
resume_id=""
review_scope=""       # --uncommitted, --base, or --commit
review_scope_value=""
run_dir=""
git_toplevel=""
codex_stdin=""         # what codex reads on stdin; the buffered prompt unless set otherwise

parse_args() {
  subcommand=${1:-}
  case "$subcommand" in
    run | review) shift ;;
    "") die 64 "missing subcommand; expected 'run' or 'review'" ;;
    *) die 64 "unknown subcommand '$subcommand'; expected 'run' or 'review'" ;;
  esac

  while (($# > 0)); do
    case "$1" in
      --model)
        (($# >= 2)) || die 64 "--model needs a value"
        model=$2
        shift 2
        ;;
      --effort)
        (($# >= 2)) || die 64 "--effort needs a value"
        effort=$2
        shift 2
        ;;
      --read-only)
        [[ $subcommand == run ]] || die 64 "--read-only belongs to 'run'"
        sandbox="read-only"
        shift
        ;;
      --resume)
        [[ $subcommand == run ]] || die 64 "--resume belongs to 'run'"
        (($# >= 2)) || die 64 "--resume needs a thread id"
        resume_id=$2
        shift 2
        ;;
      --uncommitted)
        [[ $subcommand == review ]] || die 64 "--uncommitted belongs to 'review'"
        [[ -z $review_scope ]] || die 64 "review takes one scope; already given $review_scope"
        review_scope="--uncommitted"
        shift
        ;;
      --base)
        [[ $subcommand == review ]] || die 64 "--base belongs to 'review'"
        [[ -z $review_scope ]] || die 64 "review takes one scope; already given $review_scope"
        (($# >= 2)) || die 64 "--base needs a branch"
        review_scope="--base"
        review_scope_value=$2
        shift 2
        ;;
      --commit)
        [[ $subcommand == review ]] || die 64 "--commit belongs to 'review'"
        [[ -z $review_scope ]] || die 64 "review takes one scope; already given $review_scope"
        (($# >= 2)) || die 64 "--commit needs a sha"
        review_scope="--commit"
        review_scope_value=$2
        shift 2
        ;;
      *)
        die 64 "unknown flag '$1'"
        ;;
    esac
  done
}

check_preconditions() {
  [[ -n $model ]] || die 65 "--model is required"
  [[ -n $effort ]] || die 66 "--effort is required"
  [[ ! -t 0 ]] || die 67 "stdin is a terminal; send the prompt on stdin"
  git_toplevel=$(git rev-parse --show-toplevel 2>/dev/null) ||
    die 68 "not inside a git repository"
  [[ -n $git_toplevel ]] || die 68 "not inside a git repository"
  command -v codex >/dev/null 2>&1 || die 69 "codex not found on PATH"
}

make_run_dir() {
  local tmp_root="${TMPDIR:-/tmp}"
  tmp_root=${tmp_root%/}
  run_dir="$tmp_root/codex-subagent/$(date +%Y%m%d-%H%M%S)-$$"
  mkdir -p "$run_dir"
  printf '%s\n' "$run_dir"
}

# Buffer stdin to a file: stdin can only be read once, and a resume that falls back to a fresh run
# needs the same prompt a second time. Calling this twice keeps the first read.
read_prompt_to_file() {
  if [[ ! -f $run_dir/prompt.md ]]; then
    cat >"$run_dir/prompt.md"
  fi
}

# The exact argv handed to codex, one argument per line, for debugging and for the user.
write_argv() { # write_argv <arg>...
  local arg
  : >"$run_dir/argv"
  for arg in "$@"; do
    printf '%s\n' "$arg" >>"$run_dir/argv"
  done
}

# Codex's first JSONL event carries the thread id. Parsed tolerantly, so no jq is needed.
# Returns non-zero when no thread ever started, which is what a resume fallback keys on.
capture_thread_id() {
  local line id
  line=$(grep -m1 'thread_id' "$run_dir/events.jsonl" 2>/dev/null) || return 1
  id=$(printf '%s\n' "$line" |
    sed -n 's/.*"thread_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
  [[ -n $id ]] || return 1
  printf '%s\n' "$id" >"$run_dir/thread-id"
}

record_result() { # record_result <exit-code>
  printf '%s\n' "$1" >"$run_dir/exit-code"
}

# One codex invocation, run to completion: stdin from the buffered prompt, JSONL events and the
# progress log into the run directory, the pid recorded while it runs, the thread id and the exit
# code recorded after. Returns Codex's own status; `|| status=$?` keeps set -e from swallowing it.
invoke_codex() { # invoke_codex codex <arg>...
  local status=0 codex_pid
  write_argv "$@"
  "$@" <"${codex_stdin:-$run_dir/prompt.md}" >"$run_dir/events.jsonl" 2>"$run_dir/progress.log" &
  codex_pid=$!
  printf '%s\n' "$codex_pid" >"$run_dir/pid"
  wait "$codex_pid" || status=$?
  capture_thread_id || true
  record_result "$status"
  return "$status"
}

run_fresh() {
  read_prompt_to_file
  local status=0
  invoke_codex codex exec \
    --sandbox "$sandbox" \
    -m "$model" \
    -c "model_reasoning_effort=\"$effort\"" \
    -c 'web_search="live"' \
    -c 'sandbox_workspace_write.network_access=true' \
    -C "$git_toplevel" \
    --json \
    -o "$run_dir/final-message.md" \
    - || status=$?
  return "$status"
}

# --- ticket 04 fills this ---
run_resume() {
  die 70 "run --resume: not implemented yet"
}

# What a review with no scope flag diffs against on a clean tree: the branch the repo merges into.
# `origin/HEAD`'s short name (`origin/main`, say) when the remote publishes one, since the remote
# tracking branch is the honest base; otherwise whichever of main or master exists here.
review_default_branch() {
  local ref=""
  ref=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null) || ref=""
  if [[ -n $ref ]]; then
    printf '%s\n' "$ref"
  elif git show-ref --verify --quiet refs/heads/main; then
    printf 'main\n'
  else
    printf 'master\n'
  fi
}

# The scope this review diffs: the flag the caller gave, else what the tree suggests.
review_scope_args() {
  if [[ -n $review_scope_value ]]; then
    printf '%s\n%s\n' "$review_scope" "$review_scope_value"
  elif [[ -n $review_scope ]]; then
    printf '%s\n' "$review_scope"
  elif [[ -n $(git status --porcelain) ]]; then
    printf -- '--uncommitted\n'
  else
    printf -- '--base\n%s\n' "$(review_default_branch)"
  fi
}

# `codex exec review` takes no --sandbox and no -C: it edits nothing, so there is no sandbox to
# choose, and the repository is whichever one the process sits in. Hence the cd, and hence no
# network or web-search override here either.
run_review() {
  read_prompt_to_file
  cd "$git_toplevel"

  local -a scope=()
  local line
  while IFS= read -r line; do
    scope+=("$line")
  done < <(review_scope_args)
  printf '%s\n' "${scope[*]}" >"$run_dir/review-scope"

  # An empty focus with `-` would leave codex waiting on an empty prompt, so pass no prompt at all.
  local -a focus_arg=()
  if [[ -s $run_dir/prompt.md ]]; then
    focus_arg=(-)
  else
    codex_stdin=/dev/null
  fi

  local status=0
  invoke_codex codex exec review "${scope[@]}" \
    -m "$model" \
    -c "model_reasoning_effort=\"$effort\"" \
    --json \
    -o "$run_dir/final-message.md" \
    ${focus_arg[@]+"${focus_arg[@]}"} || status=$?
  return "$status"
}

main() {
  parse_args "$@"
  check_preconditions
  make_run_dir

  local status=0
  if [[ $subcommand == review ]]; then
    run_review || status=$?
  elif [[ -n $resume_id ]]; then
    run_resume || status=$?
  else
    run_fresh || status=$?
  fi
  exit "$status"
}

main "$@"
