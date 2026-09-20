#!/usr/bin/env bash
#
# check-codex-updates: report whether the codex-subagent wrapper still matches the installed
# Codex CLI. Reads only; the one thing it ever writes is the snapshot directory, and only
# under --refresh. It never edits the wrapper.
#
# Usage:
#   check.sh              report drift
#   check.sh --refresh    re-take the snapshots for the installed version
#
# Exit: 0 no drift and installed == latest; 1 drift or a newer version exists; 2 own error.

set -uo pipefail

# Help output wraps to the terminal width, so pin it: an unpinned width makes every diff noise.
export COLUMNS=100

# codex subcommand -> snapshot basename.
HELP_COMMANDS=(
  "exec:exec"
  "exec resume:exec-resume"
  "exec review:exec-review"
)

RELEASE_NOTES_LIMIT=10

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$script_dir/../../.." && pwd)
wrapper="$repo_root/plugins/codex-subagent/scripts/codex-subagent.sh"
snapshot_root="$repo_root/snapshots"

die() { printf 'check-codex-updates: %s\n' "$1" >&2; exit 2; }
heading() { printf '\n== %s ==\n\n' "$1"; }

work_dir=$(mktemp -d "${TMPDIR:-/tmp}/check-codex-updates.XXXXXX") || die "could not make a temp dir"
trap 'rm -rf "$work_dir"' EXIT

drift=0        # set when help output moved or a newer version exists
refresh=0

case "${1:-}" in
  "") ;;
  --refresh) refresh=1 ;;
  *) die "unknown argument '$1'; expected nothing or --refresh" ;;
esac

command -v codex >/dev/null 2>&1 || die "codex not found on PATH"
[[ -f $wrapper ]] || die "wrapper not found at $wrapper"

# A version string out of whatever `codex --version` prints ("codex-cli 0.155.1").
installed_version=$(codex --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+[A-Za-z0-9.+-]*' | head -1)
[[ -n $installed_version ]] || die "could not read a version out of 'codex --version'"

# Take the three help outputs into <dir>. They print help and never call the model.
capture_help() { # capture_help <dir>
  local dir=$1 entry cmd base
  mkdir -p "$dir" || return 1
  for entry in "${HELP_COMMANDS[@]}"; do
    cmd=${entry%%:*}
    base=${entry##*:}
    # shellcheck disable=SC2086 # cmd is a deliberate multi-word subcommand
    codex $cmd --help >"$dir/$base.txt" 2>&1 || return 1
  done
}

# --- refresh -----------------------------------------------------------------

if ((refresh)); then
  target="$snapshot_root/codex-$installed_version"
  existed=0
  [[ -d $target ]] && existed=1

  # Capture all four files into the work dir first and move them in only once every one of them
  # succeeded: a capture that dies on the third command must not leave the committed snapshots
  # half-overwritten, with one of them holding an error message.
  staged="$work_dir/refresh"
  capture_help "$staged" || die "could not capture help output from codex"
  printf '%s\n' "$installed_version" >"$staged/VERSION" || die "could not write a VERSION file"

  mkdir -p "$target" || die "could not create $target"
  for entry in "${HELP_COMMANDS[@]}" "VERSION:VERSION"; do
    base=${entry##*:}
    [[ $base == VERSION ]] || base="$base.txt"
    mv -f "$staged/$base" "$target/$base" || die "could not write $target/$base"
  done

  if ((existed)); then
    printf 'Refreshed snapshots in %s (codex-cli %s).\n' "${target#"$repo_root"/}" "$installed_version"
  else
    printf 'Wrote new snapshots to %s (codex-cli %s).\n' "${target#"$repo_root"/}" "$installed_version"
  fi
  printf 'Nothing else was written. Review the diff and bump the plugin version.\n'
  exit 0
fi

# --- versions ----------------------------------------------------------------

heading "Versions"

printf 'installed: %s\n' "$installed_version"

latest_version=""
latest_source=""
if command -v npm >/dev/null 2>&1; then
  latest_version=$(npm view @openai/codex version 2>/dev/null | tr -d '[:space:]')
  [[ -n $latest_version ]] && latest_source="npm @openai/codex"
fi
if [[ -z $latest_version ]] && command -v gh >/dev/null 2>&1; then
  tag=$(gh api repos/openai/codex/releases/latest --jq .tag_name 2>/dev/null | tr -d '[:space:]')
  if [[ -n $tag ]]; then
    latest_version=${tag#rust-v}
    latest_version=${latest_version#v}
    latest_source="github releases ($tag)"
  fi
fi

if [[ -z $latest_version ]]; then
  printf 'latest:    unknown (no version lookup succeeded; offline, or npm and gh are both unavailable)\n'
elif [[ $latest_version == "$installed_version" ]]; then
  printf 'latest:    %s (via %s)\nUp to date.\n' "$latest_version" "$latest_source"
else
  printf 'latest:    %s (via %s)\nDIFFERENT: installed %s, latest %s. Upgrade before trusting the drift check.\n' \
    "$latest_version" "$latest_source" "$installed_version" "$latest_version"
  drift=1
fi

# --- snapshots ---------------------------------------------------------------

heading "Help drift"

snapshot_version=$(find "$snapshot_root" -maxdepth 1 -type d -name 'codex-*' 2>/dev/null |
  sed 's|.*/codex-||' | sort -V | tail -1)
[[ -n $snapshot_version ]] || die "no snapshots under $snapshot_root; run with --refresh to create them"
snapshot_dir="$snapshot_root/codex-$snapshot_version"

printf 'snapshot:  %s (%s)\n\n' "$snapshot_version" "${snapshot_dir#"$repo_root"/}"

live_dir="$work_dir/live"
capture_help "$live_dir" || die "could not capture help output from codex"

: >"$work_dir/hunks"
for entry in "${HELP_COMMANDS[@]}"; do
  cmd=${entry%%:*}
  base=${entry##*:}
  snap="$snapshot_dir/$base.txt"
  if [[ ! -f $snap ]]; then
    printf 'codex %s: NO SNAPSHOT at %s\n' "$cmd" "${snap#"$repo_root"/}"
    drift=1
    continue
  fi
  if diff -u "$snap" "$live_dir/$base.txt" >"$work_dir/diff.$base" 2>/dev/null; then
    printf 'codex %s: no drift\n' "$cmd"
  else
    printf 'codex %s: DRIFT\n' "$cmd"
    sed -e "s|^--- .*|--- snapshot $snapshot_version: $base.txt|" \
        -e "s|^+++ .*|+++ live $installed_version: $base.txt|" "$work_dir/diff.$base"
    printf '\n'
    grep -E '^[+-]' "$work_dir/diff.$base" | grep -Ev '^(\+\+\+|---)' >>"$work_dir/hunks"
    drift=1
  fi
done

# --- release notes -----------------------------------------------------------

heading "Release notes after $snapshot_version"

if ! command -v gh >/dev/null 2>&1; then
  printf 'skipped: gh is not installed, so release notes could not be fetched.\n'
elif ! gh api "repos/openai/codex/releases?per_page=50" \
       --jq '.[] | select(.prerelease == false) | select(.tag_name | startswith("rust-v")) | [.tag_name, .name] | @tsv' \
       >"$work_dir/releases" 2>/dev/null; then
  printf 'skipped: the GitHub releases API is unreachable (offline, or gh is not authenticated).\n'
else
  : >"$work_dir/newer"
  while IFS=$'\t' read -r tag name; do
    [[ -n $tag ]] || continue
    v=${tag#rust-v}; v=${v#v}
    # Keep it only if it sorts strictly after the snapshot version.
    [[ $v == "$snapshot_version" ]] && continue
    newest=$(printf '%s\n%s\n' "$v" "$snapshot_version" | sort -V | tail -1)
    [[ $newest == "$v" ]] || continue
    printf '%s\t%s\t%s\n' "$v" "$tag" "$name" >>"$work_dir/newer"
  done <"$work_dir/releases"

  if [[ ! -s $work_dir/newer ]]; then
    printf 'none: %s is the newest published release.\n' "$snapshot_version"
  else
    count=$(wc -l <"$work_dir/newer" | tr -d ' ')
    sort -V "$work_dir/newer" | tail -"$RELEASE_NOTES_LIMIT" | sort -Vr |
      while IFS=$'\t' read -r v tag name; do
        printf -- '--- %s  (tag %s)\n' "${name:-$v}" "$tag"
        gh api "repos/openai/codex/releases/tags/$tag" --jq '.body' 2>/dev/null |
          sed -e 's/^/    /' -e 's/[[:space:]]*$//'
        printf '\n'
      done
    if ((count > RELEASE_NOTES_LIMIT)); then
      printf '(%s releases are newer than %s; showing the %s newest. Prereleases are skipped.)\n' \
        "$count" "$snapshot_version" "$RELEASE_NOTES_LIMIT"
    fi
    drift=1
  fi
fi

# --- wrapper references ------------------------------------------------------

heading "Wrapper lines touching changed flags and config keys"

if [[ ! -s $work_dir/hunks ]]; then
  printf 'nothing to check: no help drift.\n'
else
  # Every long flag, every dotted config path, and the bare config keys the wrapper sets.
  {
    grep -oE -- '--[a-z0-9][a-z0-9-]*' "$work_dir/hunks"
    grep -oE -- '[a-z_]+\.[a-z_.]+[a-z_]' "$work_dir/hunks"
    grep -oE -- '(model_reasoning_effort|web_search|sandbox_mode)' "$work_dir/hunks"
  } 2>/dev/null | sort -u >"$work_dir/tokens"

  hits=0
  : >"$work_dir/unreferenced"
  while IFS= read -r token; do
    [[ -n $token ]] || continue
    if grep -n -F -- "$token" "$wrapper" >"$work_dir/grep.out" 2>/dev/null; then
      printf '%s\n' "$token"
      sed "s|^|    ${wrapper#"$repo_root"/}:|" "$work_dir/grep.out"
      printf '\n'
      hits=1
    else
      printf '%s ' "$token" >>"$work_dir/unreferenced"
    fi
  done <"$work_dir/tokens"

  ((hits)) || printf 'none: nothing that changed is referenced by the wrapper.\n'
  if [[ -s $work_dir/unreferenced ]]; then
    printf 'changed but not referenced by the wrapper: %s\n' "$(cat "$work_dir/unreferenced")"
  fi
fi

# --- verdict -----------------------------------------------------------------

heading "Verdict"

if ((drift)); then
  printf 'Action needed. Decide what in the wrapper must change, edit it by hand, then re-run\n'
  printf 'with --refresh and bump the plugin version. This script edits nothing.\n'
  exit 1
fi

printf 'No drift. The wrapper still matches codex-cli %s.\n' "$installed_version"
exit 0
