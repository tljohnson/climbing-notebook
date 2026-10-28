# Climbing Notebook

Updated: 2026-10-28

Climbing Notebook is planned as a native, offline-first personal climbing notebook for iPhone and iPad. The approved product and integrity requirements are in [the architecture and implementation plan](ClimbingNotebook-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md).

This repository is at the M0/M1 foundation stage. The initial Xcode app, share-extension target, persistence proof, and tests are engineering foundation only; route editing, import review, share delivery, backup/restore, and other product flows are not yet implemented. Do not use this foundation as a finished notebook or store personal climbing data in it.

## Prerequisites

- macOS with Xcode and an iOS Simulator runtime.
- Git and network access for the approved Swift Package Manager ZIPFoundation dependency.
- No account, backend, database service, or secrets are required for local development.

The approved deployment target is iOS 17. Local simulator verification requires an installed iOS runtime. The oldest supported runtime and physical-device behavior must be tested before release.

## Build and Test

Open `ClimbingNotebook.xcodeproj` in Xcode, or run the signing-free simulator checks:

```sh
SIMULATOR_ID="installed-simulator-UUID" bash Scripts/test-ios.sh
```

Resolve the reviewed package dependency with native Xcode tooling:

```sh
xcodebuild -resolvePackageDependencies -project ClimbingNotebook.xcodeproj -scheme ClimbingNotebook
```

Set `SIMULATOR_ID` to an installed simulator UUID from `xcrun simctl list devices available`. The script runs the shared scheme's unit and UI tests into a uniquely named `.xcresult`, using the active simulator architecture consistently for package and app targets. Run `bash Scripts/check-coverage.sh <result.xcresult>` to enforce 70% combined app/extension Swift line coverage; dependencies, test targets and generated sources are excluded. The extension is included even though its entry point is not exercised.

The extension is deliberately hidden from the share sheet until durable receiving exists. It never acknowledges an import as successful.

The local repository folder is `climbing-notebook`; project, scheme, module, and source names use `ClimbingNotebook`. The project-level `DEVELOPMENT_DISPLAY_NAME` build setting is the entry point for future display branding. It supplies the generated app `CFBundleDisplayName` and the extension's display name; the app reads `CFBundleDisplayName` for its title. Keep technical identifiers independent of future marketing names. Development bundle identifiers rooted at `com.climbingnotebook.foundation` are provisional pending permanent registration, not registered release identities.

## Architecture and Data

The approved plan defines the intended local SwiftUI/SwiftData architecture, managed-file ownership, share inbox boundary, and portable backup contract. The current implementation contains a two-entity versioned SwiftData proof, explicit saves, and a generation descriptor/journal feasibility harness. Tests cover on-disk reopen, synthetic migration, interrupted descriptor switching and fallback. This is not the full product schema, a production restore service or a user library. The app launch screen does not open a store; persistence is exercised by tests only. The share extension does not accept or persist deliveries.

No hosted HTTP API, account, telemetry, analytics, OCR, or cloud synchronization is part of the approved v1 scope. Foundation checks use synthetic data only. User data is not sent to a service.

## Dependencies

ZIPFoundation 0.9.20 is resolved at `22787ffb59de99e5dc1fbfe80b19c97a904ad48d` in the shared Xcode `Package.resolved` and linked only to the unit-test target. Its MIT notice is in `THIRD_PARTY_NOTICES`. Tests exercise bounded chunk round trips, CRC/SHA-256, cancellation, traversal/link rejection and a streaming inflated-byte limit. A >4 GiB ZIP64 test, independent-tool interoperability, full hostile-header inspection and production manifest validation remain unrun/unimplemented. Native Xcode/SPM resolution and a committed resolution file are explicit project exceptions. Review updates monthly and before release, with archive regression testing.

## CI and Distribution

GitHub Actions is configured for pull requests/main using a standard `macos-15` runner, read-only permissions, a verified immutable checkout Action, cancellation of superseded runs, a 30-minute timeout and no uploaded artifacts/caches. It uses the runner's default Xcode and an installed iPhone simulator, printing the actual environment. Hosted CI has not been run from this local setup. No signing credentials, automatic publishing, paid services, or repository-setting changes are required or authorized.

## Feasibility Status

The current development-identity check passes all 11 unit/UI tests on iPhone 16 Pro / iOS 27.0, including the working navigation title, from the `climbing-notebook` checkout folder. Evidence: ignored `.build/DevelopmentIdentityFinal.xcresult`. Combined app/extension coverage is 153/185 lines (82.70%); generated display names are `Climbing Notebook` and `Climbing Notebook Inbox`. Script syntax and the coverage rejection self-test pass.

The local 11-test suite passed with zero failures/skips on Xcode 27.1 (27A9275) on both iPhone 17 Pro Max / iOS 26.4 (`AF2E99D6-1023-4682-9759-0D7CF4591CB8`) and iPhone 16 Pro / iOS 27.0 (`F914FD59-C008-4E73-B265-46380A22EA22`). Evidence is in ignored `.build/Feasibility-fixed-20261028.xcresult` and `.build/Current-20261028.xcresult`. Both report app coverage 153/162 and extension 0/22, combined 153/184 (83.15%). The coverage checker rejects a 6/11-line sample. Deployment remains iOS 17, but that runtime and physical-device checks are unavailable here; installed iOS 27.1 and iPad runtimes have not been exercised. Simulator reopen tests do not prove process-kill durability or production restore readiness. Xcode emitted SDK build-number parsing/debugger-version warnings, but the result bundles report passing tests.

The test-only WebKit harness loads explicit synthetic HTML into a nonpersistent session, captures generic text and serves a synthetic image without external network access. It observes an image subresource request without a navigation-delegate decision. A top-level delegate therefore does not establish the required private-subresource/DNS/redirect/size protections. Selected-media transfer and bounded public-network rendering are not proven. Production URL copying is blocked pending an owner-reviewed enforceable design, such as the bounded public-HTML alternative in the approved plan; this does not remove URL copying from v1 scope.

M1 is incomplete: the full schema/sample persistence UI, broader migration/fault matrix, ZIP64/interoperability and URL-policy gates, newest-installed-runtime and minimum-OS/device verification remain. Generation tests inject thrown interruptions within one process, not actual termination, and do not prove power-loss/fsync durability. A synthetic migration proves API feasibility, not released-schema compatibility. No M2 feature work has started. The next independent work is CF-04's complete generation/migration matrix and CF-05's ZIP64/interoperability evidence; CF-20A needs review of an enforceable networking design before production URL intake.

The owner approved MIT as the starting first-party code license, superseding the earlier GPLv3 selection. Confirm the copyright holder before finalizing the repository's license notice; signing/release ownership and builder attribution do not independently establish copyright ownership. Preserve ZIPFoundation's MIT notice. The code license does not license user-imported content.

Leif Johnson owns signing, releases, support and privacy URLs. New app pages are planned on owner-controlled leifdigital.com without additional hosting costs; no final page URLs are live or verified yet. Final app/bundle/App Group identities and Apple team registration remain pending. The owner confirmed iPhone-primary/minimal-iPad support, English-first UI with Unicode user content, and retention of originals/raw text until explicit deletion. The owner reports downloading the iOS 17 Simulator; installation and test success have not yet been verified.

## Contributing

Read `.kilo/AGENTS.md`, `SYSTEM_DOCS.md`, and the approved plan before making changes. Use synthetic fixtures; do not add personal route libraries or copyrighted guidebook content. Preserve user/agent changes and report unrun minimum-OS, device, ZIP64, WebKit-policy, and hosted-CI checks accurately.
