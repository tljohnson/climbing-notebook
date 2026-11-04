## Deliver the MVP

This is a pre-production app with no users. Prefer the smallest correct feature implementation over speculative hardening, new abstractions or diagnostic infrastructure. The owner-approved [MVP delivery policy](../ClimbingNotebook-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md#2168-mvp-delivery-and-verification-policy) supersedes older completion/audit gates. It changes verification scope, not product features, saved-data contracts or security rules.

## Workflow

1. Read `SYSTEM_DOCS.md`, then only the source and contract relevant to the requested change. Do not recursively load plans or historical verification logs. For UI work, load `native-interface-design` and read `DESIGN.md`.
2. Implement the smallest coherent change. Reuse existing native patterns; preserve unrelated work, exact authored text, explicit Save/Cancel behavior and saved content.
3. Build and run focused tests of changed core behavior. Expand testing only for shared-code impact, a concrete regression or an explicit qualification task. Documentation-only changes need link/content and diff checks, not simulator suites.
4. Report what changed, actual check results and material limits. Update the canonical document only when its guidance, behavior or conclusion changed; do not append a session log.

## Verification and Stop Rules

- The MVP gate covers compilation and current user functionality: CRUD, notes, ordering, validation, cancel/discard, truthful save/error behavior, source isolation and saved content after relaunch. A passing suite reduces risk; it does not prove absence of all code errors.
- Preserve meaningful assertions and existing research. Future migration/archive/recovery feasibility and exploratory accessibility audits are separate from the core gate, not mandatory prerequisites for unrelated features. Actual data loss, crashes in ordinary use or inaccessible core actions remain defects.
- Do not chase an audit flag without evidence of a product defect. Retain the finding as non-gating MVP evidence; do not suppress it or call it passed. The owner has approved this classification, so do not repeatedly request an audit waiver.
- Before diagnosing a known failure, read its current conclusion. Reuse existing evidence. At most one confirmation and one materially different experiment per unresolved hypothesis; if neither produces actionable evidence, record the limit and return to feature work. Stop sooner for unsupported or out-of-scope work.
- Do not add diagnostic variants, broad device matrices, repeated full-suite runs or independent review cycles by default. Escalate only a concrete core defect or a consequential decision. Missing specialist review is not an MVP blocker.
- Discover commands in README/scripts, inspect exit status and run `git diff --check`. Distinguish core results from broader suite results; never describe a failed historical/full suite as green. Runner/CI selection must match the stated gate before claiming that gate passed.
- Retain the existing coverage requirement for applicable quality runs; do not reduce it or inflate coverage to avoid functional checks. Coverage alone proves neither correctness nor completion.

## Scope and Safety

- Approved plans authorize routine implementation decisions; do not reopen settled choices. Ask before material feature, architecture, schema, runtime-floor or destructive changes. No commits, pushes, publication, spending, signing, credential access or settings changes without authorization.
- Inspect source before claiming behavior. Preserve user/peer edits. Do not reset/reseed saved stores or normalize authored text to make tests pass. Persisted-format changes require explicit compatibility planning, even before production.
- The public-release roadmap and data-safety limitations remain valid. MVP acceptance does not establish backup/recovery, accessibility compliance or safety as the only copy of valuable notes.
- Keep scope/owner decisions in the plan, status in `docs/WIP_KANBAN.md`, design in `DESIGN.md`, commands in README and decisive results in existing verification topics. No new approval packets, parallel plans or per-run reports for routine work.
