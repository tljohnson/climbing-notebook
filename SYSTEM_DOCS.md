# System Documentation

Updated: 2026-10-28

## Start Here

- [Approved implementation plan](Cragfolio-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md): scope, architecture, contracts and approval gates. Section 21 limits this assignment to M0/M1.
- [README](README.md): actual local setup and verification commands.
- [.kilo/AGENTS.md](.kilo/AGENTS.md): repository workflow and preservation rules.

## Implementation Boundaries

The foundation is being rebuilt after an owner-confirmed intentional deletion of the previous scaffold. The approved architecture is a native iOS 17+ SwiftUI app with app-private SwiftData persistence and managed originals. The share extension must never write the library database. Backup, generation recovery and URL-copy protections require measured feasibility evidence before dependent features proceed.

This index does not establish completed product functionality. Consult source and test results, not the planned file map, for implemented behavior. No backend, account, OCR, synchronization or automatic extraction is authorized.

## Foundation Routing

- `Cragfolio/App/`: minimal foundation launch interface.
- `Cragfolio/Models/`: versioned persistence schema.
- `Cragfolio/Services/Persistence/`: explicit on-disk store operations.
- `CragfolioShare/`: extension entry point; receiving remains unavailable until the mailbox is implemented.
- `CragfolioTests/` and `CragfolioUITests/`: synthetic foundation verification.
- `Scripts/test-ios.sh`, `Scripts/check-coverage.sh`, `Scripts/CoverageGate.swift`: local native tests and combined first-party coverage gate.
- `.github/workflows/ios-ci.yml`: prepared simulator CI; hosted execution is unrun.

Release-only identity, signing, license and distribution decisions remain unresolved. Simulator namespaces are provisional. No publication or signing changes are authorized.
