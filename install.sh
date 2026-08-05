#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

link_path() {
  local source_file="$1"
  local target_file="$2"

  if [[ ! -e "$source_file" ]]; then
    echo "missing source file: $source_file" >&2
    exit 1
  fi

  mkdir -p "$(dirname "$target_file")"

  if [[ -e "$target_file" && ! -L "$target_file" ]]; then
    echo "refusing to overwrite non-symlink: $target_file" >&2
    exit 1
  fi

  if [[ -L "$target_file" && "$(readlink "$target_file")" == "$source_file" ]]; then
    echo "already linked: $target_file"
    return 0
  fi

  ln -sfn "$source_file" "$target_file"
  echo "linked $target_file -> $source_file"
}

link_pairs=(
  "$repo_root/.agents/AGENTS.md" "$HOME/.copilot/copilot-instructions.md"
  "$repo_root/.agents" "$HOME/.agents"
  "$repo_root/tuicr" "$HOME/.config/tuicr"
  "$repo_root/nvim" "$HOME/.config/nvim"
)

for ((i = 0; i < ${#link_pairs[@]}; i += 2)); do
  link_path "${link_pairs[i]}" "${link_pairs[i + 1]}"
done
