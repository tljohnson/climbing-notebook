# System Documentation Index

**Updated:** 2026-10-27

## Current Project State

This repository now has the M0/M1 native build and feasibility foundation, not the planned climbing notebook. Its SwiftUI launch view, versioned SwiftData sample, share-extension target, and test-only WKWebView harness are real but do not implement the user's library, share mailbox, or production URL-copy protections. Do not infer unimplemented behavior from the approved design below.

## Canonical References

- [Approved architecture and implementation plan](Cragfolio-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md): approved product scope, proposed architecture/data contracts, integrity requirements, milestones, and the M0/M1 implementing-agent handoff. Treat prospective files and contracts as plans until source code verifies them.
- [.kilo/AGENTS.md](.kilo/AGENTS.md): repository workflow, approval, preservation, and verification rules.
- [README](README.md): actual foundation prerequisites, build/test commands, and current limitations.
- [Third-party notices](THIRD_PARTY_NOTICES): resolved ZIPFoundation license notice.

## Routing

- For implementation scope, platform choices, data model, intake, backup/restore, privacy, tests, and milestone boundaries, consult the approved plan's relevant sections before changing code.
- `Cragfolio/Models/LibrarySchema.swift` and `Cragfolio/Services/LibraryStore.swift` describe only the implemented synthetic V1/V2 schema and disk-store helper. The full approved domain schema is not implemented.
- `Cragfolio.xcodeproj` is the canonical app/share/test target and shared-scheme definition; `.github/workflows/ios-ci.yml` is the planned local-verifiable hosted CI workflow. Hosted execution remains unverified.
- M1 evidence is currently local under ignored `.build/` result bundles. The recorded feasible results are migration/reopen, generation-directory switching, ZIP64 >4 GiB, and synthetic WebKit text/image selection. Production WebKit destination/subresource/DNS protections remain an unresolved gate; no real-site requests were made.
