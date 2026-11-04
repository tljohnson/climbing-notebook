# Climbing Notebook System Documentation Index

Updated: 2026-11-04

## Reading Workflow

Read the shared [agent workflow](.kilo/AGENTS.md), then use this index to select only the task-relevant source and contract. Do not recursively load linked plans or historical evidence. Inspect source before claiming behavior.

**Current MVP authority:** [plan §21.6.8](ClimbingNotebook-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md#2168-mvp-delivery-and-verification-policy) supersedes historical exhaustive test matrices, audit blockers and repeated diagnostic/review instructions. Deliver features with focused core/data-integrity checks. Preserve research evidence without restarting it. The test runner/CI still require a separate explicit core-cohort configuration change; do not claim their default full suite is green.

## Architecture Overview

Climbing Notebook is an offline-first personal climbing notebook, iPhone-primary with minimal iPad support, targeting iOS 17.5+ with SwiftUI (owner-approved floor change, 2026-11-01). The approved architecture routes presentation through feature coordinators to app-private SwiftData persistence and managed-file services. The main app alone owns library mutations and managed originals; the share extension delivers only to an App Group mailbox for main-app intake and draft review. Portable backup uses explicit data-transfer models plus originals, not a raw database copy. These are approved architectural contracts, not claims that all components exist. See [architecture](ClimbingNotebook-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md#5-architecture-and-technology-decisions).

Historical CF-07A/B fixture baseline: browsing is read-only and note/order editing uses explicit workflows. CF-07B adds an isolated versioned SwiftData fixture store and buffered explicit save/relaunch for route notes, pitch notes and whole pitch order. It is not the full product schema. The separate diagnostic LibraryStore/generation harnesses remain unchanged; intake, migration/replacement acceptance and backup/restore remain incomplete. Consult source, [current capabilities](README.md#current-capabilities) and task-relevant evidence below, not the plan's prospective file map.

The implemented [text notebook](ClimbingNotebook-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md#216-consolidated-text-notebook-milestone-approved) opens an initially empty `TextNotebook` format with hierarchy CRUD, notes, persisted sibling order and explicit Save/Cancel. Examples and unchanged-format retained content are separate sources; source-bound drafts prevent retargeting and retained reading cannot initialize an absent root. Owner light/dark regular/maximum-text workflows passed; VoiceOver remains untested. [Recorded results](docs/verification/NotebookPrototype.md#consolidated-final-disposition) distinguish passing core evidence from failed historical full suites and separate research/audit findings. Full17.5 suites ran and failed; their coverage passed. A named MVP gate has not yet been configured/run, and formal milestone acceptance remains separate. Ordinary debugging needs no new approval; consequential runtime-floor/schema/architecture changes do.

## Cross-Cutting Invariants

- The main app alone mutates the library database. The extension must use the [mailbox contract](ClimbingNotebook-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md#72-share-extension-mailbox-contract), never direct library access.
- Never report saved/local success before originals and metadata are durably acknowledged. Preserve explicit save/recovery and file-ownership rules in the [data-integrity contract](ClimbingNotebook-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md#8-media-storage-and-data-integrity).
- Backup, generation recovery and URL-copy protections apply when implementing those dependent features, not as prerequisites for ordinary notebook work. Do not treat research harnesses as production readiness or restart paused investigations under an unrelated task.
- The owner-approved [prototype-first exception](ClimbingNotebook-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md#2144-owner-approved-prototype-first-reset) permits a disposable synthetic notebook UI before M1 acceptance. Archive research is paused; its capability gaps gate restore, not the prototype. This does not authorize durable storage claims or relax release requirements.
- Leif approved the bounded [durable fixture slice](ClimbingNotebook-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md#2145-cf-07b-approved-ordinary-durable-saverelaunch-slice), including explicit completion saves instead of eventual autosave, isolated schema/store adoption, and retained incomplete initialization without automatic repair. Unacknowledged edits may be lost; only successful explicit saves are presented as saved. Valuable data remains out of scope. Its acceptance is separate from CF-07A and M1.
- The owner-approved [CF-07D creation slice](ClimbingNotebook-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md#2151-cf-07d-approved-first-core-notebook-creation-slice) extends this same store for name-only Add/Cancel route drafts in existing areas, not complete-library adoption. Preserve fixture checks and saved content; no migration, reseeding, personal data or autosave is authorized. CF-07C acceptance does not accept CF-07B or CF-07D.
- No backend, account, OCR, synchronization, analytics, LLM calls or automatic route-field extraction is authorized by the current implementation scope. Use synthetic fixtures, not personal route libraries or copyrighted guidebooks; see [scope and guardrails](ClimbingNotebook-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md#212-permissions-and-guardrails).
- Use an English-first UI while preserving Unicode user content. Retain originals/raw text until explicit deletion; ready deliveries and saved drafts do not automatically expire. These owner-confirmed defaults are recorded in the [owner decisions](ClimbingNotebook-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md#21-confirmed-owner-decisions).

## Owner Decision Reference

The [plan's confirmed owner decisions](ClimbingNotebook-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md#21-confirmed-owner-decisions) remain canonical. Key licensing and release constraints for subsequent work:

- MIT is the approved starting first-party code license, superseding the earlier GPLv3 selection. Preserve third-party notices; the code license does not license imported user content. Confirm copyright ownership before finalizing the license notice.
- Leif Johnson owns signing, releases, support and privacy URLs. App pages are planned on owner-controlled `leifdigital.com` without additional hosting costs; pages and final URLs still need to be established.
- Development bundle identifiers rooted at `com.climbingnotebook.foundation` are provisional pending permanent registration. Permanent bundle, backup-type and App Group identifiers remain undecided; technical identities stay independent of future marketing names. Use the project-level `DEVELOPMENT_DISPLAY_NAME` setting for future display branding; the app title reads the generated `CFBundleDisplayName`.

See [open release decisions](ClimbingNotebook-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md#18-open-owner-decisions) before changing licensing, signing or distribution. Owner-reported simulator downloads are not proof of installed-runtime coverage; consult the [verification references](README.md#verification-references) for checks actually executed.

## Task Routing

Plan links below define approved requirements and contracts, not completed functionality. Read the affected contracts before changing their boundaries.

| Task | Read first |
|---|---|
| UI / navigation / editing | [screen specifications](ClimbingNotebook-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md#4-screen-and-interaction-specifications), [prototype scope](ClimbingNotebook-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md#2144-owner-approved-prototype-first-reset), [prototype evidence](docs/verification/NotebookPrototype.md) |
| UI design / layout / controls / copy / review | Load [native-interface-design](.kilo/skills/native-interface-design/SKILL.md), then [product design rules and visual references](DESIGN.md) and the assigned plan section; read the skill file directly if not tool-discovered. Design guidance does not change functional/save/data contracts. |
| Persistence / schema / migrations / managed files | [architecture](ClimbingNotebook-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md#5-architecture-and-technology-decisions), [data model](ClimbingNotebook-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md#6-logical-data-model), [service contracts](ClimbingNotebook-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md#7-contracts-and-api-boundaries), [data integrity](ClimbingNotebook-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md#8-media-storage-and-data-integrity) |
| Archives / backup / replace-restore / generation recovery | [data integrity](ClimbingNotebook-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md#8-media-storage-and-data-integrity), [backup and restore contract](ClimbingNotebook-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md#9-complete-backup-and-replace-restore-contract), [archive evidence](docs/verification/Archives.md), [persistence evidence](docs/verification/Persistence.md) |
| Intake / share extension / URL copying | [intake and review](ClimbingNotebook-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md#46-intake-inbox-and-review), [mailbox contract](ClimbingNotebook-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md#72-share-extension-mailbox-contract), [privacy and safety](ClimbingNotebook-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md#11-privacy-accessibility-and-safety), [URL-policy finding](docs/verification/Persistence.md#url-policy-finding) |
| Build / tests / coverage / CI | [local commands](README.md#build-and-test), [test strategy](ClimbingNotebook-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md#13-test-strategy-and-release-acceptance), [native policy exceptions](ClimbingNotebook-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md#161-applicable-standards-and-exceptions), [CI configuration and limits](README.md#ci-and-distribution) |
| Work scope / approval / milestone gates | [implementation handoff](ClimbingNotebook-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md#21-implementation-handoff), [Kanban](docs/WIP_KANBAN.md), [verification references](README.md#verification-references) |
| Licensing / ownership / signing / release prerequisites | [owner decisions](ClimbingNotebook-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md#2-decisions-assumptions-and-approval), [policy and distribution](ClimbingNotebook-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md#16-policy-costs-ci-and-distribution), [open release decisions](ClimbingNotebook-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md#18-open-owner-decisions) |

## Source Navigation

- `ClimbingNotebook/App/` and `Features/NotebookPrototype/`: shared snapshot state, buffered editors and native notebook UI.
- `ClimbingNotebook/Models/`: versioned persistence schema.
- `ClimbingNotebook/Services/Persistence/`: explicit on-disk store operations.
- `ClimbingNotebookShare/`: extension entry point.
- `ClimbingNotebookTests/` and `ClimbingNotebookUITests/`: synthetic foundation verification.
- `Scripts/test-ios.sh`, `Scripts/check-coverage.sh`, `Scripts/CoverageGate.swift`: local native tests and combined first-party coverage gate.
- `.github/workflows/ios-ci.yml`: simulator CI configuration.

Discover current files with search rather than expanding this index into an exhaustive repository tree.

## Documentation Authority

The [approved plan](ClimbingNotebook-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md) owns delivery contracts, owner decisions and approval scope; its [section 21 handoff](ClimbingNotebook-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md#21-implementation-handoff) defines the bounded M0/M1 assignment and gates for later work. This index does not expand that authorization. Plan approval does not authorize commits, pushes, publication, website deployment, signing changes or developer-portal registration.

The [README](README.md) owns current capabilities, setup and reusable verification commands. [Kanban](docs/WIP_KANBAN.md) owns task status. Topic references under `docs/verification/` own consolidated conclusions, decisive measurements, reproducible checks and remaining limits; read only the relevant topic. Source and test results establish implemented behavior, not planned features presented as live. Raw ignored `.build/` artifacts are local diagnostics, not required context for every task.

Update this index only for navigation, architecture or cross-cutting invariants. Update topic documents in place; retain earlier failures only when they explain a current limitation or decision. Do not append per-turn worklogs, repeated test tables, superseded instructions or transient worktree observations to README, plans or this index. Do not create one report per agent/packet when an existing topic fits. Keep contracts/owner decisions in plans and release history in `CHANGELOG.md`/Git; maintain one updated date.
