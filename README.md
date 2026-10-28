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

### CF-04B Migration Safety: Blocked

The uncommitted CF-04B spike adds test-only related synthetic schemas, byte-exact Unicode/stable-ID checks, explicit post-migration save/reopen assertions, deterministic custom migration rejection, and whole-generation preservation/recovery/retry assertions. **These are not passing closed-generation evidence.** The fail-closed lifetime barrier reproducibly fails after an autorelease pool, `processPendingChanges()`, and a condition-driven one-second async release window. iOS 17 retains a `ModelContainer`; iOS 27.1 retains contexts (including the rejected migration's context). Later copy/reopen/move operations are aborted when the barrier fails, and temporary directories are retained with paths attached to the result bundle. A weak-reference check is not itself proof that underlying SQLite connections closed.

Initial exploratory runs continued after lifetime assertions and emitted SQLite `vnode unlinked while in use` warnings during cleanup. The final tests instead throw on barrier failure and do not remove the affected generation. Initial migration data assertions did not report identity/text/relationship loss, but operations performed without proven closure cannot establish snapshot or independent-reopen safety. The final runs stop at the release barrier; recovery/retry remains unproven. The custom error is surfaced directly on iOS 17 and wrapped as `SwiftDataError` on iOS 27.1. Synthetic schemas are not released formats, and no production schema, migration manager, persistence framework, or dependency was changed.

Verified environment: Xcode 27.1 (`27A9275`); iPhone 15 Pro / iOS 17.0 (`21A328`, `A1A7DBEF-BA07-4904-9CE9-3C6B1F5A3492`), and newest installed runtime iPhone Duo / iOS 27.1 (`24A94425`, `AD5A310D-DBEB-497C-8921-1A49BC52C3C6`). The prior iPhone 16 Pro / iOS 27.0 destination (`F914FD59-C008-4E73-B265-46380A22EA22`) was also reverified installed, not rerun in CF-04B.

Exact final commands (repository root):

```sh
SIMULATOR_ID=A1A7DBEF-BA07-4904-9CE9-3C6B1F5A3492 RESULT_BUNDLE_PATH=.build/MigrationSafetyFinal-iOS17-20261028.xcresult bash Scripts/test-ios.sh -quiet -test-timeouts-enabled YES -maximum-test-execution-time-allowance 120 -collect-test-diagnostics never
SIMULATOR_ID=AD5A310D-DBEB-497C-8921-1A49BC52C3C6 RESULT_BUNDLE_PATH=.build/MigrationSafetyFinal-iOS27_1-20261028.xcresult bash Scripts/test-ios.sh -quiet -test-timeouts-enabled YES -maximum-test-execution-time-allowance 120 -collect-test-diagnostics never
bash Scripts/check-coverage.sh .build/MigrationSafetyFinal-iOS17-20261028.xcresult
bash Scripts/check-coverage.sh .build/MigrationSafetyFinal-iOS27_1-20261028.xcresult
bash Scripts/check-coverage.sh --self-test
git diff --check
```

Both full unit/UI runs **failed**: 20 tests each, 18 passed, 2 failed, 0 skipped. The failures are `testFailedMigrationRecoversAndRetriesFromIndependentClosedGeneration` and `testOnDiskSyntheticMigrationPreservesRelationshipsAndSavedChangesAfterReopen`. Both coverage commands passed: app 167/172, extension 0/22, combined 167/194 (86.08%), excluding dependencies/tests/generated sources. Coverage is not behavioral acceptance. The rejection self-test passed (6/11, 54.55%, rejected); whitespace validation passed. Result summaries were inspected with `xcrun xcresulttool get test-results summary --path <bundle above>`. Earlier evidence remains in `.build/MigrationSafety-iOS27_1-20261028.xcresult`, `.build/MigrationSafetyDiagnose-iOS17-20261028.xcresult`, and `.build/MigrationSafetyDrain-iOS{17,27_1}-20261028.xcresult`. Two initial iOS 17 attempts were stopped while Xcode collected stalled simulator diagnostics; disabling verbose diagnostic collection resolved the apparent hang without disabling tests/assertions. SDK build-number/debugger warnings remain.

Dependent persistence/recovery implementation is stopped for owner review under plan §§6.4/9.5/21.2. The smallest proposed next investigation is a test-only, sequential-process fixture handoff with confirmed process exit before whole-generation copying, plus retention-path inspection; this is not implemented or approval to change production architecture. If deterministic in-process closure remains unavailable, review an explicit-close Core Data fallback before production migration/restore work. Do not silently switch frameworks. Process-termination recovery, power-loss/fsync durability, production restore, and released-schema compatibility remain unproven. The smallest independent ready packet is CF-05 ZIP64/interoperability evidence, still within M1.

### Committed CF-04A Baseline

The current CF-04A generation-recovery suite passes all 19 unit/UI tests with zero failures/skips on Xcode 27.1 (27A9275), using iPhone 15 Pro / iOS 17.0 (`A1A7DBEF-BA07-4904-9CE9-3C6B1F5A3492`) and iPhone 16 Pro / iOS 27.0 (`F914FD59-C008-4E73-B265-46380A22EA22`). Evidence: ignored `.build/GenerationRecoveryFinal-iOS17-20261028.xcresult` and `.build/GenerationRecoveryFinal-iOS27-20261028.xcresult`. Both report app coverage 167/172 and extension 0/22, combined 167/194 (86.08%); dependencies, tests and generated sources are excluded. The coverage checker also rejects its 6/11-line sample. Generated display names remain `Climbing Notebook` and `Climbing Notebook Inbox`.

Run the verified checks with `SIMULATOR_ID=<UUID above> RESULT_BUNDLE_PATH=<new .xcresult path> bash Scripts/test-ios.sh -quiet`, then `bash Scripts/check-coverage.sh <result.xcresult>` and `bash Scripts/check-coverage.sh --self-test`. The recovery harness rejects new initialization/replacement while a journal is pending and rejects same-generation journals. Tests cover all three interruption checkpoints (prepared, descriptor switched before journal update, switched), corrupt/missing stores, invalid metadata, repeated recovery, and preservation of failed-recovery evidence followed by successful retry after fixture repair. The journal's serialized phases remain `prepared`/`switched`; checkpoints are test injection points, not a format change. Deployment remains iOS 17, now verified in Simulator; physical-device, installed iOS 27.1 and iPad checks remain unrun. Xcode emitted SDK build-number parsing/debugger-version warnings, but the commands exited successfully and result bundles report passing tests.

The test-only WebKit harness loads explicit synthetic HTML into a nonpersistent session, captures generic text and serves a synthetic image without external network access. It observes an image subresource request without a navigation-delegate decision. A top-level delegate therefore does not establish the required private-subresource/DNS/redirect/size protections. Selected-media transfer and bounded public-network rendering are not proven. Production URL copying is blocked pending an owner-reviewed enforceable design, such as the bounded public-HTML alternative in the approved plan; this does not remove URL copying from v1 scope.

M1 is incomplete: the full schema/sample persistence UI, closed-generation migration/fault matrix, ZIP64/interoperability and URL-policy gates, and physical-device/iPad verification remain. The newest installed runtime has now executed the failing CF-04B suite above, not passed M1 acceptance. Generation tests inject thrown interruptions within one process, not actual termination, and do not prove power-loss/fsync durability or production restore readiness. A synthetic migration proves API feasibility, not released-schema compatibility. No M2 feature work has started. CF-04 dependent work needs teardown/recovery owner review; CF-05's ZIP64/interoperability evidence is independent, and CF-20A needs review of an enforceable networking design before production URL intake.

The owner approved MIT as the starting first-party code license, superseding the earlier GPLv3 selection. Confirm the copyright holder before finalizing the repository's license notice; signing/release ownership and builder attribution do not independently establish copyright ownership. Preserve ZIPFoundation's MIT notice. The code license does not license user-imported content.

Leif Johnson owns signing, releases, support and privacy URLs. New app pages are planned on owner-controlled leifdigital.com without additional hosting costs; no final page URLs are live or verified yet. Final app/bundle/App Group identities and Apple team registration remain pending. The owner confirmed iPhone-primary/minimal-iPad support, English-first UI with Unicode user content, and retention of originals/raw text until explicit deletion. iOS 17.0 Simulator installation and the current foundation suite are now verified as described above; device behavior remains unverified.

## Contributing

Read `.kilo/AGENTS.md`, `SYSTEM_DOCS.md`, and the approved plan before making changes. Use synthetic fixtures; do not add personal route libraries or copyrighted guidebook content. Preserve user/agent changes and report unrun minimum-OS, device, ZIP64, WebKit-policy, and hosted-CI checks accurately.
