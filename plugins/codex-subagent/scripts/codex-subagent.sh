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

# A flag's value, checked before it is taken. A value starting with `--` is the next flag: the
# caller dropped the value, and swallowing the flag as one would run something they never asked for.
require_value() { # require_value <flag> <remaining-arg-count> <value>
  (($2 >= 2)) || die 64 "$1 needs a value"
  [[ $3 != --* ]] || die 64 "$1 needs a value, but '$3' is a flag"
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
        require_value --model "$#" "${2:-}"
        model=$2
        shift 2
        ;;
      --effort)
        require_value --effort "$#" "${2:-}"
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
        require_value --resume "$#" "${2:-}"
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
        require_value --base "$#" "${2:-}"
        review_scope="--base"
        review_scope_value=$2
        shift 2
        ;;
      --commit)
        [[ $subcommand == review ]] || die 64 "--commit belongs to 'review'"
        [[ -z $review_scope ]] || die 64 "review takes one scope; already given $review_scope"
        require_value --commit "$#" "${2:-}"
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
  mkdir -p "$tmp_root/codex-subagent"
  # mktemp, not a bare mkdir: the run directory holds the prompt and the result, so it must be
  # this run's alone -- 0700, and never a directory someone else pre-created -- and must not
  # collide with a second run that starts in the same second under a recycled pid.
  run_dir=$(mktemp -d "$tmp_root/codex-subagent/$(date +%Y%m%d-%H%M%S)-$$-XXXXXX")
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

# Codex's first JSONL event is the thread start and carries the thread id. Parsed tolerantly, so
# no jq is needed, but the line has to be a `thread.started` event: an error that merely mentions a
# thread id is not a thread that started, and the resume fallback keys on that difference. Only the
# head of the stream is scanned, so the poll loop never re-reads a growing file.
capture_thread_id() {
  local line id
  line=$(head -n 50 "$run_dir/events.jsonl" 2>/dev/null |
    grep -m1 '"type"[[:space:]]*:[[:space:]]*"thread\.started"') || return 1
  id=$(printf '%s\n' "$line" |
    sed -n 's/.*"thread_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
  [[ -n $id ]] || return 1
  printf '%s\n' "$id" >"$run_dir/thread-id"
}

record_exit_code() { # record_exit_code <exit-code>
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
  # The thread id lands in `thread-id` as soon as the first event arrives, so a follow-up can
  # resume a run that is still going and a status check can name the thread.
  while kill -0 "$codex_pid" 2>/dev/null; do
    if capture_thread_id; then break; fi
    sleep 0.2
  done
  wait "$codex_pid" || status=$?
  capture_thread_id || true
  record_exit_code "$status"
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

# A follow-up on an existing thread. The resume form takes no `--sandbox` and no `-C`, so the
# sandbox travels as a config override (never inherited from the thread or the user's config) and
# the working directory is set by cd'ing to the git toplevel first.
#
# `--strict-config` is what makes that override load-bearing: without it Codex ignores a key it does
# not know, so the day `sandbox_mode` is renamed a read-only follow-up would silently inherit the
# thread's workspace-write sandbox. With it, the resume fails instead.
#
# A resume that dies before Codex ever started the thread means the thread is stale, missing, or
# unusable: the task is still worth doing, so the same prompt starts a fresh run, and the failed
# attempt is kept beside it under `resume-*` names. A resume that dies after the thread started
# is an ordinary failure of a real run, and its status is Codex's answer.
run_resume() {
  read_prompt_to_file
  cd "$git_toplevel"

  local status=0
  invoke_codex codex exec resume "$resume_id" \
    --strict-config \
    -m "$model" \
    -c "model_reasoning_effort=\"$effort\"" \
    -c "sandbox_mode=\"$sandbox\"" \
    -c 'web_search="live"' \
    -c 'sandbox_workspace_write.network_access=true' \
    --json \
    -o "$run_dir/final-message.md" \
    - || status=$?

  if ((status == 0)) || capture_thread_id; then
    return "$status"
  fi

  printf 'resume of %s failed before thread start (exit %s); thread abandoned, fresh run started\n' \
    "$resume_id" "$status" >"$run_dir/resume-fallback"
  printf 'codex-subagent: resume of %s failed before thread start; starting a fresh run\n' \
    "$resume_id" >&2
  mv "$run_dir/events.jsonl" "$run_dir/resume-events.jsonl"
  mv "$run_dir/progress.log" "$run_dir/resume-progress.log"
  mv "$run_dir/argv" "$run_dir/resume-argv"

  status=0
  run_fresh || status=$?
  return "$status"
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

# The scope this review diffs: the flag the caller gave, else what the tree suggests. Fills the
# caller's `scope` array, so a branch name with a space stays one argument.
set_review_scope() {
  if [[ -n $review_scope_value ]]; then
    scope=("$review_scope" "$review_scope_value")
  elif [[ -n $review_scope ]]; then
    scope=("$review_scope")
  elif [[ -n $(git status --porcelain) ]]; then
    scope=(--uncommitted)
  else
    scope=(--base "$(review_default_branch)")
  fi
}

# The same scope, said in words: the sentence that opens a focused review's instructions, since
# such a review cannot carry the flag. Takes the `scope` array as its arguments, so the sentence
# and the flag can never disagree about what is being reviewed.
review_scope_sentence() { # review_scope_sentence <scope-arg>...
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

# `codex exec review` takes no --sandbox and no -C: it edits nothing, so there is no sandbox to
# choose, and the repository is whichever one the process sits in. Hence the cd, and hence no
# network override. Web search is live here as on every other run, so a review can check what the
# current documentation says rather than what it remembers.
#
# The scope reaches Codex one of two ways, never both. Verified against codex-cli 0.155.1: the
# positional PROMPT of `codex exec review` is a fourth scope preset, mutually exclusive with every
# scope flag, so a scope flag plus a prompt dies in argument parsing --
#   error: the argument '--base <BRANCH>' cannot be used with '[PROMPT]'
# -- with exit 2 and nothing run, the same for `--uncommitted` and `--commit`. So: no focus, and
# the scope is the flag; a focus, and the scope becomes the first line of the instructions with
# the focus following it unchanged. Either way `review-scope` records the scope the wrapper chose
# and how it was delivered, so the run directory still says what was actually reviewed.
run_review() {
  read_prompt_to_file
  cd "$git_toplevel"

  local -a scope=()
  set_review_scope
  local -a scope_flags=("${scope[@]}")
  local delivered_as=flag

  # An empty focus with `-` would leave codex waiting on an empty prompt, so pass no prompt at all.
  local -a focus_arg=()
  if [[ -s $run_dir/prompt.md ]]; then
    delivered_as=instructions
    mv "$run_dir/prompt.md" "$run_dir/focus.md"
    {
      review_scope_sentence "${scope[@]}"
      printf '\n'
      cat "$run_dir/focus.md"
    } >"$run_dir/prompt.md"
    focus_arg=(-)
    scope_flags=()
  else
    codex_stdin=/dev/null
  fi

  {
    printf '%s\n' "${scope[@]}"
    printf 'delivered-as: %s\n' "$delivered_as"
  } >"$run_dir/review-scope"

  local status=0
  invoke_codex codex exec review ${scope_flags[@]+"${scope_flags[@]}"} \
    -m "$model" \
    -c "model_reasoning_effort=\"$effort\"" \
    -c 'web_search="live"' \
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
