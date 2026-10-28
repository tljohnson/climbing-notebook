# Cragfolio System Documentation Index

Updated: 2026-10-28

## Reading Workflow

Read this index first, then task-relevant references and cross-cutting contracts below. Follow [.kilo/AGENTS.md](.kilo/AGENTS.md) for repository workflow and preservation rules. Inspect actual source, configuration and test evidence before planning or editing; documentation is not a substitute for source verification. Do not recursively load every linked reference.

## Architecture Overview

Cragfolio is an offline-first personal climbing notebook, iPhone-primary with minimal iPad support, targeting iOS 17+ with SwiftUI. The approved architecture routes presentation through feature coordinators to app-private SwiftData persistence and managed-file services. The main app alone owns library mutations and managed originals; the share extension delivers only to an App Group mailbox for main-app intake and draft review. Portable backup uses explicit data-transfer models plus originals, not a raw database copy. These are approved architectural contracts, not claims that all components exist. See [architecture](Cragfolio-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md#5-architecture-and-technology-decisions).

The implementation is foundation-only: the launch UI does not open a library, persistence and recovery have feasibility harnesses, and the extension does not receive deliveries. Product editing, intake and backup/restore flows are not implemented. Consult source and the [current feasibility evidence and gaps](README.md#feasibility-status), not the plan's proposed file map, for implemented behavior.

## Cross-Cutting Invariants

- The main app alone mutates the library database. The extension must use the [mailbox contract](Cragfolio-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md#72-share-extension-mailbox-contract), never direct library access.
- Never report saved/local success before originals and metadata are durably acknowledged. Preserve explicit save/recovery and file-ownership rules in the [data-integrity contract](Cragfolio-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md#8-media-storage-and-data-integrity).
- Backup, generation recovery and URL-copy protections require measured feasibility evidence before dependent features proceed. Do not weaken guarantees or treat a harness as production readiness; follow the [handoff gates](Cragfolio-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md#21-implementation-handoff).
- No backend, account, OCR, synchronization, analytics, LLM calls or automatic route-field extraction is authorized by the current implementation scope. Use synthetic fixtures, not personal route libraries or copyrighted guidebooks; see [scope and guardrails](Cragfolio-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md#212-permissions-and-guardrails).
- Use an English-first UI while preserving Unicode user content. Retain originals/raw text until explicit deletion; ready deliveries and saved drafts do not automatically expire. These owner-confirmed defaults are recorded in the [owner decisions](Cragfolio-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md#21-confirmed-owner-decisions).

## Owner Decision Reference

The [plan's confirmed owner decisions](Cragfolio-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md#21-confirmed-owner-decisions) remain canonical. Key licensing and release constraints for subsequent work:

- MIT is the approved starting first-party code license, superseding the earlier GPLv3 selection. Preserve third-party notices; the code license does not license imported user content. Confirm copyright ownership before finalizing the license notice.
- Leif Johnson owns signing, releases, support and privacy URLs. App pages are planned on owner-controlled `leifdigital.com` without additional hosting costs; pages and final URLs still need to be established.
- Permanent bundle, backup-type and App Group identifiers remain undecided; simulator identifiers are provisional. Suggested `com.leifdigital.cragfolio` identifiers are recommendations, not owner-approved or registered identities.

See [open release decisions](Cragfolio-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md#18-open-owner-decisions) before changing licensing, signing or distribution. Owner-reported simulator downloads are not proof of installed-runtime coverage; consult the [verification evidence](README.md#feasibility-status) for checks actually executed.

## Task Routing

Plan links below define approved requirements and contracts, not completed functionality. Read the affected contracts before changing their boundaries.

| Task | Read first |
|---|---|
| UI / navigation / editing | [screen specifications](Cragfolio-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md#4-screen-and-interaction-specifications), [architecture](Cragfolio-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md#5-architecture-and-technology-decisions) |
| Persistence / schema / migrations / managed files | [architecture](Cragfolio-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md#5-architecture-and-technology-decisions), [data model](Cragfolio-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md#6-logical-data-model), [service contracts](Cragfolio-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md#7-contracts-and-api-boundaries), [data integrity](Cragfolio-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md#8-media-storage-and-data-integrity) |
| Archives / backup / replace-restore / generation recovery | [data integrity](Cragfolio-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md#8-media-storage-and-data-integrity), [backup and restore contract](Cragfolio-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md#9-complete-backup-and-replace-restore-contract), [feasibility evidence](README.md#feasibility-status) |
| Intake / share extension / URL copying | [intake and review](Cragfolio-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md#46-intake-inbox-and-review), [mailbox contract](Cragfolio-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md#72-share-extension-mailbox-contract), [privacy and safety](Cragfolio-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md#11-privacy-accessibility-and-safety), [URL-policy findings](README.md#feasibility-status) |
| Build / tests / coverage / CI | [local commands](README.md#build-and-test), [test strategy](Cragfolio-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md#13-test-strategy-and-release-acceptance), [native policy exceptions](Cragfolio-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md#161-applicable-standards-and-exceptions), [CI configuration and limits](README.md#ci-and-distribution) |
| Work scope / approval / milestone gates | [implementation handoff](Cragfolio-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md#21-implementation-handoff), [current evidence and remaining gaps](README.md#feasibility-status) |
| Licensing / ownership / signing / release prerequisites | [owner decisions](Cragfolio-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md#2-decisions-assumptions-and-approval), [policy and distribution](Cragfolio-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md#16-policy-costs-ci-and-distribution), [open release decisions](Cragfolio-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md#18-open-owner-decisions) |

## Source Navigation

- `Cragfolio/App/`: minimal foundation launch interface.
- `Cragfolio/Models/`: versioned persistence schema.
- `Cragfolio/Services/Persistence/`: explicit on-disk store operations.
- `CragfolioShare/`: extension entry point.
- `CragfolioTests/` and `CragfolioUITests/`: synthetic foundation verification.
- `Scripts/test-ios.sh`, `Scripts/check-coverage.sh`, `Scripts/CoverageGate.swift`: local native tests and combined first-party coverage gate.
- `.github/workflows/ios-ci.yml`: simulator CI configuration.

Discover current files with search rather than expanding this index into an exhaustive repository tree.

## Documentation Authority

The [approved plan](Cragfolio-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md) owns delivery contracts, owner decisions and approval scope; its [section 21 handoff](Cragfolio-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md#21-implementation-handoff) defines the bounded M0/M1 assignment and gates for later work. This index does not expand that authorization. Plan approval does not authorize commits, pushes, publication, website deployment, signing changes or developer-portal registration.

The [README](README.md) owns actual setup and verification commands; its [feasibility status](README.md#feasibility-status) is the current home for milestone status, evidence and remaining gaps. Source and test results establish implemented behavior. Implementation references must describe what exists, not present planned features as live.

Update this index only for navigation, architecture or cross-cutting invariants. Keep implementation detail in canonical references, extracting focused leaf documents when implemented subsystems warrant them rather than duplicating the plan. Keep task status out of this index and approval decisions out of status reports. Release history belongs in `CHANGELOG.md` and Git, not an accumulating index history; maintain one updated date.
