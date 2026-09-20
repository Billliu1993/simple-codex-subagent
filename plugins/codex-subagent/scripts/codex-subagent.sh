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

# --- ticket 02 fills this ---
run_fresh() {
  die 70 "run: not implemented yet"
}

# --- ticket 04 fills this ---
run_resume() {
  die 70 "run --resume: not implemented yet"
}

# --- ticket 05 fills this ---
run_review() {
  die 70 "review: not implemented yet"
}

main() {
  parse_args "$@"
  check_preconditions
  make_run_dir

  if [[ $subcommand == review ]]; then
    run_review
  elif [[ -n $resume_id ]]; then
    run_resume
  else
    run_fresh
  fi
}

main "$@"
