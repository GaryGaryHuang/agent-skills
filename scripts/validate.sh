#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
skills_root="$repo_root/skills"
failures=0

report_failure() {
  printf 'error: %s\n' "$1" >&2
  failures=$((failures + 1))
}

validate_skill() {
  local skill_dir="$1"
  local skill_name
  local skill_md

  skill_name="$(basename "$skill_dir")"
  skill_md="$skill_dir/SKILL.md"

  if [[ ! -f "$skill_md" ]]; then
    report_failure "$skill_name is missing SKILL.md"
    return
  fi

  if [[ "$(sed -n '1p' "$skill_md")" != "---" ]]; then
    report_failure "$skill_name SKILL.md must start with YAML frontmatter"
  fi

  if ! grep -q '^name: ' "$skill_md"; then
    report_failure "$skill_name SKILL.md is missing frontmatter name"
  fi

  if ! grep -q '^description: ' "$skill_md"; then
    report_failure "$skill_name SKILL.md is missing frontmatter description"
  fi

  while IFS= read -r reference_path; do
    [[ -n "$reference_path" ]] || continue
    if [[ ! -f "$skill_dir/$reference_path" ]]; then
      report_failure "$skill_name references missing file: $reference_path"
    fi
  done < <(grep -Eo 'references/[A-Za-z0-9._/-]+\.md' "$skill_md" | sort -u)

  if [[ -d "$skill_dir/agents" && ! -f "$skill_dir/agents/openai.yaml" ]]; then
    report_failure "$skill_name agents directory exists without agents/openai.yaml"
  fi
}

if [[ ! -d "$skills_root" ]]; then
  report_failure "missing skills directory: $skills_root"
else
  shopt -s nullglob
  skill_dirs=("$skills_root"/*)
  if [[ ${#skill_dirs[@]} -eq 0 ]]; then
    report_failure "no skills found under $skills_root"
  fi

  for skill_dir in "${skill_dirs[@]}"; do
    [[ -d "$skill_dir" ]] || continue
    validate_skill "$skill_dir"
  done
fi

if [[ "$failures" -gt 0 ]]; then
  exit 1
fi

printf 'validated %s skill repository\n' "$repo_root"
