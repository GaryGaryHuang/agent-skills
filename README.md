# Agent Skills

Reusable `SKILL.md`-based agent skills for Codex, GitHub Copilot, and compatible coding agents.

## Skills

- `copilot-sdk`: Guidance for building production Node.js/TypeScript apps with GitHub Copilot SDK v1.0+ using official GA docs and installed SDK types.

## Install

Clone this repository, then install one skill into your local agent skills directory:

```bash
./scripts/install.sh copilot-sdk
```

By default, the installer writes to `~/.agents/skills`. To install into a different skills directory:

```bash
AGENT_SKILLS_HOME="$HOME/.codex/skills" ./scripts/install.sh copilot-sdk
```

Install every skill in this repository:

```bash
./scripts/install.sh --all
```

## Validate

Run the repository validation script before committing skill changes:

```bash
./scripts/validate.sh
```

The validator checks that each skill has a `SKILL.md`, required frontmatter fields, and no broken direct `references/*.md` links from `SKILL.md`.
