#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
skills_root="$repo_root/skills"
target_root="${AGENT_SKILLS_HOME:-$HOME/.agents/skills}"

usage() {
  printf 'Usage: %s <skill-name>|--all\n' "$0" >&2
  printf 'Installs skills into AGENT_SKILLS_HOME, defaulting to ~/.agents/skills.\n' >&2
}

install_skill() {
  local skill_name="$1"
  local source_dir="$skills_root/$skill_name"
  local target_dir="$target_root/$skill_name"

  if [[ ! -f "$source_dir/SKILL.md" ]]; then
    printf 'error: skill not found or missing SKILL.md: %s\n' "$skill_name" >&2
    return 1
  fi

  mkdir -p "$target_dir"
  rsync -a --delete "$source_dir/" "$target_dir/"
  printf 'installed %s -> %s\n' "$skill_name" "$target_dir"
}

if [[ $# -ne 1 ]]; then
  usage
  exit 2
fi

case "$1" in
  --all)
    shopt -s nullglob
    skill_dirs=("$skills_root"/*)
    if [[ ${#skill_dirs[@]} -eq 0 ]]; then
      printf 'error: no skills found under %s\n' "$skills_root" >&2
      exit 1
    fi
    for skill_dir in "${skill_dirs[@]}"; do
      [[ -d "$skill_dir" ]] || continue
      install_skill "$(basename "$skill_dir")"
    done
    ;;
  -h|--help)
    usage
    ;;
  *)
    install_skill "$1"
    ;;
esac
