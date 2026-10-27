# Cragfolio

Cragfolio is planned as a native, offline-first personal climbing notebook for iPhone and iPad. The approved product and integrity requirements are in [the architecture and implementation plan](Cragfolio-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md).

This repository is at the M0/M1 foundation stage. The initial Xcode app, share-extension target, persistence proof, and tests are engineering foundation only; route editing, import review, share delivery, backup/restore, and other product flows are not yet implemented. Do not use this foundation as a finished notebook or store personal climbing data in it.

## Prerequisites

- macOS with Xcode and an iOS Simulator runtime.
- Git and network access for the approved Swift Package Manager ZIPFoundation dependency.
- No account, backend, database service, or secrets are required for local development.

The approved deployment target is iOS 17. Local simulator verification requires an installed iOS runtime. The oldest supported runtime and physical-device behavior must be tested before release.

## Build and Test

Open `Cragfolio.xcodeproj` in Xcode, or run the signing-free simulator checks:

```sh
Scripts/test-ios.sh
```

Resolve the reviewed package dependency with native Xcode tooling:

```sh
xcodebuild -resolvePackageDependencies -project Cragfolio.xcodeproj -scheme Cragfolio
```

The test script selects an installed iPhone simulator and runs the shared scheme's unit and UI tests. It prints a uniquely named `.xcresult` output path. The 70% coverage gate counts first-party app Swift files only; the share extension remains an explicit, nonfunctional foundation stub and is reported separately until actual intake code is implemented.

```sh
Scripts/check-coverage.sh .build/TestResults-YYYYMMDD-HHMMSS.xcresult
```

## Architecture and Data

The approved plan defines the intended local SwiftUI/SwiftData architecture, managed-file ownership, share inbox boundary, and portable backup contract. At this foundation stage only a versioned on-disk SwiftData proof exists; no user library, complete import workflow, or backup format implementation is available yet. The share extension does not yet accept or persist deliveries.

No hosted HTTP API, account, telemetry, analytics, OCR, or cloud synchronization is part of the approved v1 scope. Foundation checks use synthetic data only. User data is not sent to a service.

## Dependencies

ZIPFoundation is the only approved third-party package and is used in local archive feasibility tests. Its resolved revision is recorded in `Cragfolio.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`. Review security updates and rerun archive tests before changing it. Native Xcode/SPM resolution is an explicit project exception for macOS development and hosted macOS CI.

## CI and Distribution

GitHub Actions is configured to build and test pull requests and pushes to `main` on a standard hosted macOS runner. Hosted CI has not been run from this local setup. No signing credentials, automatic publishing, paid services, or repository-setting changes are required or authorized by the foundation.

The final app name, bundle/App Group identities, license, signer, release owner, support/privacy URLs, and store distribution remain release decisions. No license has yet been selected for this repository.

## Contributing

Read `.kilo/AGENTS.md`, `SYSTEM_DOCS.md`, and the approved plan before making changes. Use synthetic fixtures; do not add personal route libraries or copyrighted guidebook content. Preserve user/agent changes and report unrun minimum-OS, device, ZIP64, WebKit-policy, and hosted-CI checks accurately.
