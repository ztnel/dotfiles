#!/usr/bin/env bash
set -e -u -o pipefail

# Configuration - override via environment variables
TUICR_PANE_POSITION="${TUICR_PANE_POSITION:-top}"    # top or bottom
TUICR_PANE_SIZE="${TUICR_PANE_SIZE:-80}"              # percentage of screen
TUICR_BASE_REF="${TUICR_BASE_REF:-}"
TUICR_HEAD_REF="${TUICR_HEAD_REF:-HEAD}"
TUICR_WATCH_INTERVAL_SECONDS="0.25"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
  echo -e "${GREEN}[tuicr]${NC} $*"
}

log_warn() {
  echo -e "${YELLOW}[tuicr]${NC} $*"
}

log_error() {
  echo -e "${RED}[tuicr]${NC} $*"
}

usage() {
  cat << EOF
Usage: $(basename "$0") [directory]

Launch tuicr in a tmux window to review git changes.

Arguments:
  directory    Git repository directory to review (default: current directory)

Environment variables:
  TUICR_BASE_REF        Optional base ref for commit-range review
  TUICR_HEAD_REF        Head ref for commit-range review (default: HEAD)

Examples:
  $(basename "$0")                                   # Review working tree in current directory
  TUICR_HEAD_REF=origin/@ewan/optimize-sdfm-readings $(basename "$0")
  TUICR_BASE_REF=origin/develop TUICR_HEAD_REF=origin/@ewan/optimize-sdfm-readings $(basename "$0") ~/project
EOF
}

check_tmux() {
  if [[ -z "${TMUX:-}" ]]; then
    return 1
  fi
  return 0
}

check_tuicr() {
  if ! command -v tuicr &> /dev/null; then
    log_error "tuicr not found. Install it first."
    return 1
  fi
  return 0
}

check_git_repo() {
  local dir="$1"
  if ! git -C "$dir" rev-parse --git-dir &> /dev/null; then
    log_error "Not a git repository: $dir"
    return 1
  fi
  return 0
}

check_tuicr_running() {
  # Check if tuicr is already running in any tmux pane
  if tmux list-panes -a -F '#{pane_current_command}' 2>/dev/null | grep -q '^tuicr$'; then
    return 0  # tuicr is running
  fi
  return 1
}

has_working_tree_changes() {
  local dir="$1"
  [[ -n "$(git -C "$dir" status --short --untracked-files=all 2>/dev/null)" ]]
}

revset_exists() {
  local dir="$1"
  local rev="$2"
  git -C "$dir" rev-parse --verify "${rev}^{commit}" &> /dev/null
}

get_active_session_info() {
  local target_dir="$1"
  local sessions_json

  if ! sessions_json=$(tuicr review list --repo "$target_dir" 2>/dev/null); then
    return 1
  fi

  python3 -c '
import json
import sys

try:
    sessions = json.load(sys.stdin)
except json.JSONDecodeError:
    sys.exit(1)

active = [
    session for session in sessions
    if session.get("active") and session.get("slug") and session.get("path")
]
if len(active) == 1:
    session = active[0]
    print("{}\t{}".format(session["slug"], session["path"]))
' <<< "$sessions_json"
}

list_human_comment_ids() {
  local session_path="$1"

  if [[ ! -f "$session_path" ]]; then
    return 1
  fi

  python3 - "$session_path" <<'PY'
import json
import sys

try:
    with open(sys.argv[1], "r", encoding="utf-8") as handle:
        session = json.load(handle)
except (OSError, json.JSONDecodeError):
    sys.exit(1)

def is_human(comment: object) -> bool:
    if not isinstance(comment, dict):
        return False

    username = str(comment.get("username") or "").strip()
    if username:
        return False

    author = str(comment.get("author") or "").strip()
    return not author or author == "user"

ids = set()

for comment in session.get("review_comments", []):
    if is_human(comment) and comment.get("id") is not None:
        ids.add(str(comment["id"]))

for file_data in session.get("files", {}).values():
    if not isinstance(file_data, dict):
        continue

    for comment in file_data.get("file_comments", []):
        if is_human(comment) and comment.get("id") is not None:
            ids.add(str(comment["id"]))

    for line_comments in file_data.get("line_comments", {}).values():
        if not isinstance(line_comments, list):
            continue
        for comment in line_comments:
            if is_human(comment) and comment.get("id") is not None:
                ids.add(str(comment["id"]))

if ids:
    print("\n".join(sorted(ids)))
PY
}

send_wake_notification() {
  local origin_pane_id="$1"
  local origin_session_id="$2"
  local session_slug="$3"
  local new_ids_file="$4"
  local current_window_id=""
  local current_pane_id=""
  local origin_window_id=""
  local wake_buffer_name=""
  local wake_message=""
  local comment_count
  local comment_label="comments"

  comment_count=$(wc -l < "$new_ids_file" | tr -d '[:space:]')
  if [[ "$comment_count" == "1" ]]; then
    comment_label="comment"
  fi

  tmux set-option -t "$origin_session_id" focus-events on >/dev/null 2>&1 || true
  current_window_id=$(tmux display-message -p '#{window_id}' 2>/dev/null || true)
  current_pane_id=$(tmux display-message -p '#{pane_id}' 2>/dev/null || true)
  origin_window_id=$(tmux display-message -p -t "$origin_pane_id" '#{window_id}' 2>/dev/null || true)

  if [[ -n "$origin_window_id" ]]; then
    tmux select-window -t "$origin_window_id" >/dev/null 2>&1 || true
  fi
  tmux select-pane -t "$origin_pane_id" >/dev/null 2>&1 || true
  sleep 0.1

  wake_buffer_name="tuicr-wake-${origin_pane_id#%}-$$"
  wake_message=$(printf 'New human tuicr %s landed in session %s. Read the session for new comments.' "$comment_label" "$session_slug")
  tmux display-message -t "$origin_pane_id" "tuicr: $comment_count new human $comment_label in $session_slug" || true
  tmux set-buffer -b "$wake_buffer_name" -- "$wake_message" >/dev/null 2>&1 || true
  tmux paste-buffer -d -b "$wake_buffer_name" -t "$origin_pane_id" >/dev/null 2>&1 || true
  sleep 0.05
  tmux send-keys -t "$origin_pane_id" C-m || true

  if [[ -n "$current_window_id" ]]; then
    tmux select-window -t "$current_window_id" >/dev/null 2>&1 || true
  fi
  if [[ -n "$current_pane_id" ]]; then
    tmux select-pane -t "$current_pane_id" >/dev/null 2>&1 || true
  fi
}

watch_session_comments() {
  local target_dir="$1"
  local origin_pane_id="$2"
  local origin_session_id="$3"
  local seen_ids_file
  local current_ids_file
  local new_ids_file
  local session_slug=""
  local session_path=""
  local session_info=""

  seen_ids_file=$(mktemp /tmp/tuicr-watch-seen.XXXXXX)
  current_ids_file=$(mktemp /tmp/tuicr-watch-current.XXXXXX)
  new_ids_file=$(mktemp /tmp/tuicr-watch-new.XXXXXX)
  : > "$seen_ids_file"

  cleanup_watch() {
    rm -f "$seen_ids_file" "$current_ids_file" "$new_ids_file"
  }

  trap 'cleanup_watch; exit 0' EXIT TERM INT

  while true; do
    if [[ -z "$session_slug" ]]; then
      session_info=$(get_active_session_info "$target_dir" || true)
      if [[ -n "$session_info" ]]; then
        IFS=$'\t' read -r session_slug session_path <<< "$session_info"
      fi
      if [[ -n "$session_slug" && -n "$session_path" ]]; then
        if ! list_human_comment_ids "$session_path" > "$seen_ids_file"; then
          : > "$seen_ids_file"
        fi
        log_info "Live watch attached to tuicr session $session_slug"
      fi
      sleep "$TUICR_WATCH_INTERVAL_SECONDS"
      continue
    fi

    if list_human_comment_ids "$session_path" > "$current_ids_file"; then
      comm -13 "$seen_ids_file" "$current_ids_file" > "$new_ids_file" || true
      if [[ -s "$new_ids_file" ]]; then
        send_wake_notification "$origin_pane_id" "$origin_session_id" "$session_slug" "$new_ids_file"
        cat "$current_ids_file" > "$seen_ids_file"
      fi
    fi

    sleep "$TUICR_WATCH_INTERVAL_SECONDS"
  done
}

launch_tuicr_pane() {
  local target_dir="$1"
  local origin_pane_id
  local origin_session_id
  local watcher_pid=""
  local review_target="working tree"
  local tuicr_cmd="tuicr tui --no-update-check -w"
  local window_name="tuicr-unstaged"

  origin_pane_id=$(tmux display-message -p '#{pane_id}')
  origin_session_id=$(tmux display-message -p '#{session_id}')

  if [[ -n "$TUICR_BASE_REF" ]]; then
    local revset="${TUICR_BASE_REF}...${TUICR_HEAD_REF}"
    if ! revset_exists "$target_dir" "$TUICR_BASE_REF"; then
      log_error "Base ref not found: $TUICR_BASE_REF"
      return 1
    fi
    if ! revset_exists "$target_dir" "$TUICR_HEAD_REF"; then
      log_error "Head ref not found: $TUICR_HEAD_REF"
      return 1
    fi
    tuicr_cmd="tuicr tui --no-update-check -r '$revset'"
    review_target="$revset"
    if has_working_tree_changes "$target_dir"; then
      tuicr_cmd="$tuicr_cmd -w"
      review_target="$review_target + working tree"
      window_name="tuicr-unstaged"
    else
      window_name="tuicr-$revset"
    fi
  elif ! has_working_tree_changes "$target_dir"; then
    log_error "No working tree changes found. Set TUICR_BASE_REF to review a commit range."
    return 1
  fi

  log_info "Launching tuicr in a new tmux window"
  log_info "Directory: $target_dir"
  log_info "Review target: $review_target"
  log_info "Window name: $window_name"

  # Create unique channel for wait-for
  local wait_channel="tuicr-$$"

  # Create the new window with tuicr, signal when done
  local new_window_id
  local new_pane_id
  read -r new_window_id new_pane_id <<< "$(tmux new-window -d -P -F '#{window_id} #{pane_id}' \
    -t "$origin_session_id:" -n "$window_name" -c "$target_dir" \
    "cd '$target_dir' && $tuicr_cmd; tmux wait-for -S '$wait_channel'")"

  tmux set-option -t "$origin_session_id" focus-events on >/dev/null 2>&1 || true
  watch_session_comments "$target_dir" "$origin_pane_id" "$origin_session_id" &
  watcher_pid=$!
  log_info "Live watch will wake pane $origin_pane_id when new human comments land"

  # Switch focus to the new tuicr window
  tmux select-window -t "$new_window_id"

  log_info "Target tmux session: $origin_session_id"
  log_info "tuicr is running in window $new_window_id pane $new_pane_id"
  log_info "Waiting for tuicr to exit..."

  # Block until tuicr exits
  tmux wait-for "$wait_channel"

  if [[ -n "$watcher_pid" ]]; then
    kill "$watcher_pid" 2>/dev/null || true
    wait "$watcher_pid" 2>/dev/null || true
  fi

  log_info "tuicr finished"
  log_info "If you exported instructions, they are in your clipboard - paste them here"
}

main() {
  # Handle help
  if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
  fi

  # Check for tuicr
  if ! check_tuicr; then
    exit 1
  fi

  # Determine target directory
  local target_dir="${1:-.}"
  target_dir=$(cd "$target_dir" && pwd)  # Get absolute path

  # Verify it's a git repo
  if ! check_git_repo "$target_dir"; then
    exit 1
  fi

  # Check if we're in tmux
  if ! check_tmux; then
    log_error "Not running inside tmux!"
    echo ""
    echo "To use tuicr with your coding agent, run that agent inside tmux."
    echo ""
    echo "1. Exit the current agent session."
    echo ""
    echo "2. Restart the agent inside tmux."
    echo ""
    echo "3. Then run /tuicr again."
    exit 1
  fi

  # Check if tuicr is already running
  if check_tuicr_running; then
    log_warn "tuicr is already running in another pane"
    log_info "Switch to it with Ctrl-b + arrow keys"
    exit 0
  fi

  # Launch tuicr in a split pane
  launch_tuicr_pane "$target_dir"
}

main "$@"
