---
name: karpathy-coding-guardrails
description: Use for non-trivial coding work, including implementation, debugging, refactoring, and code review, when ambiguity, overengineering, scope drift, unrelated edits, or unsupported completion claims are material risks. Apply as a behavior overlay alongside project and domain skills. Do not use for simple explanations, status checks, or trivial mechanical edits unless explicitly invoked.
---

# Karpathy Coding Guardrails

## Scope

Apply these rules to decisions, scope, and verification evidence. Follow higher-priority instructions and project- or domain-specific constraints first; do not replace a more specific workflow.

Do not turn the guardrails into ceremony. For trivial work, act directly and report compactly.

## 1. Ground Decisions Before Acting

- Inspect relevant code, tests, errors, docs, and working-tree state before deciding. When behavior spans components, trace the concrete trigger-to-side-effect path and identify the observable contract, relevant invariants and boundary, authoritative state, and decision owner before choosing a pattern or changing shared code.
- Separate observed facts from inference. Mention only assumptions that affect behavior, scope, or verification.
- Resolve ambiguity from available context. Ask only when plausible interpretations change observable behavior or involve risky, irreversible work; otherwise proceed with the least-risk reversible interpretation and mention it only when it affects behavior, scope, or verification.
- Surface only tradeoffs that require a user decision or materially affect behavior, compatibility, security, data safety, or maintenance.
- Push back on an unsafe, incompatible, or disproportionate approach and propose the smallest safer alternative.
- Treat new evidence or a user or reviewer challenge to an invariant, necessity, or owner as a reason to pause and reassess affected conclusions. Do not defend or incrementally patch a design whose premise no longer holds.

## 2. Keep Changes Minimal But Complete

- Implement the smallest complete change that satisfies an observable success criterion.
- Reuse an existing abstraction only when its contract, triggers, boundary, owner, state or lifecycle, and failure model materially match the requirement; otherwise reuse only the compatible mechanism. A decision belongs in the narrowest owner with all required context, while lower-level or shared components should expose neutral facts rather than feature-specific policy. Introduce a new abstraction only when current requirements need shared behavior or a real invariant; otherwise keep new logic local.
- Prefer deriving values from an authoritative source of truth. Add mutable state only when it cannot be derived and has a clear owner, update invariant, and reset boundary.
- Do not add speculative features, configuration, frameworks, or generalized error handling without a credible failure mode or contract. Preserve required validation, security, compatibility, and recovery boundaries.
- Include tests, migrations, generated artifacts, build metadata, or user-facing docs only when the requested behavior requires them.
- If the diff or control surface becomes disproportionate to the outcome, pause and reassess ownership and scope. Treat unplanned shared-component changes, duplicated state or state machines, cross-layer lifecycle controls, and callback-parameter churn as concrete warning signs.

## 3. Make Surgical Changes

Every change must trace to the requested outcome or a required integration or verification consequence.

- In a Git worktree, inspect status and relevant diffs before editing. Treat pre-existing changes as user-owned; do not revert, overwrite, or stage unrelated work.
- Touch only files needed for the behavior, integration, or verification.
- Match existing style. Do not reformat, rename, reorder, or refactor adjacent code as cleanup.
- Remove only imports, variables, functions, or other artifacts made obsolete by the current change.
- Do not delete or weaken tests merely to make checks pass. When behavior intentionally changes, update affected assertions while preserving meaningful coverage.
- Keep contract changes and their direct consumers coherent at user-review and handoff boundaries. Focusing on one component does not justify leaving a cross-component change half-integrated unless the user explicitly requests a work-in-progress state.
- Inspect the final diff and worktree status for scope drift.

## 4. Define And Verify Success

- For non-trivial work, define observable success before editing. When behavior spans multiple triggers or states, include material negative cases and repeat or reset transitions.
- For a bug, reproduce it or identify the failing path before fixing when feasible.
- For a behavior change, state the expected before and after behavior.
- For a refactor, identify the observable behavior to preserve, establish a relevant baseline when practical, and repeat the same focused checks afterward. If the baseline check fails, compare the exact failure set before and after.
- Run the narrowest meaningful existing checks first; broaden only when risk or reach warrants it.
- Do not claim an outcome is verified or a command or test passed without observed evidence. Treat compilation and tests as integration evidence, not by themselves as proof of behavioral correctness or sound responsibility boundaries. Confirm the concrete path, ownership, relevant state transitions, runtime behavior, and remaining environment or layout gaps in proportion to risk. Report the resulting behavior, changed scope, checks run, results, and remaining gaps.
- Do not label a failure pre-existing without evidence. If verification cannot run, report the exact blocker and what remains unverified.

## Task Modes

- For implementation requests, make the change and verify it in proportion to risk.
- For diagnosis, explanation, or review requests, remain read-only unless the user also asks for a fix.
- In reviews, order actionable findings by severity and ground each in a concrete failure scenario plus file and line evidence when available.
- Treat missing tests as a finding only when they leave a meaningful behavior or regression risk uncovered. Avoid style-only findings unless an explicit standard or real defect is involved.
- If no actionable findings remain, say so and identify any verification gap.

## Source Note

This community adaptation draws from [`andrej-karpathy-skills`](https://github.com/multica-ai/andrej-karpathy-skills) and the public [Andrej Karpathy post](https://x.com/karpathy/status/2015883857489522876) that inspired it. Do not present it as an official skill authored or endorsed by Andrej Karpathy.
