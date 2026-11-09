# Climbing Notebook Offline iOS Notebook: Architecture and Implementation Feature Plan

**Status:** Owner-approved implementation plan, including the consolidated text-notebook milestone in §21.6 (2026-10-31).
**Prepared:** 2026-10-27
**Updated:** 2026-11-09
**Inputs:** `handoff.md` and the owner's clarification answers in this session.
**Deliverable boundary:** Approved implementation specification. The repository now contains a partial M0/M1 foundation and an accepted disposable notebook prototype; prospective files and contracts below are not claims of implemented features. Measured evidence and remaining gaps live in [notebook prototype verification](docs/verification/NotebookPrototype.md), [persistence verification](docs/verification/Persistence.md) and [archive verification](docs/verification/Archives.md). Task status lives in [WIP Kanban](docs/WIP_KANBAN.md); this plan retains approval scope and milestone gates. README owns setup and build/test entry points, not the evidence ledger.

## 1. Executive Summary

**Active MVP instruction:** owner-approved [§21.6.8](#2168-mvp-delivery-and-verification-policy) supersedes earlier mandatory full-suite matrices, audit blockers, independent-review cycles and research prerequisites for current MVP delivery. Read that policy before applying historical gates below. The roadmap, explicit-save/data contracts, security and release boundaries remain intact. Dated diagnostic narratives below are reference history, not assignments to repeat.

**Read by task, not front to back.** [SYSTEM_DOCS.md](SYSTEM_DOCS.md) routes work; [DESIGN.md](DESIGN.md) owns product intent, navigation and screen composition; [README](README.md) owns capabilities and reusable commands; [Kanban](docs/WIP_KANBAN.md) owns current status. Use §21.6.2-§21.6.4 for current notebook data/operations, §21.8 and the [image contract](Image-Supported-Notebooks-FeaturePlan.md) for images, and §21.6.8 for verification. §§3, 5-12 and applicable §13 scenarios describe complete-product engineering, not implemented features. §21.7 export is deferred. §§21.1-21.5 and dated §21.6 narratives retain history only, not current assignments. The deployment floor is **iOS 17.5** and non-destructive editors use **Save**, not autosave/Done. DESIGN owns newer composition, including written-sections-first Route Details. Archive/migration safeguards remain feature-specific requirements, not unrelated MVP blockers.

Climbing Notebook is a native, offline-first personal climbing notebook, not a guidebook service or a social network. A climber owns the local library, can consult all saved originals without connectivity, needs no account, and can export and replace-restore the library without a subscription.

The first public release includes the full core notebook, images and PDF originals, plain-text and pasted-text intake, user-initiated single-page URL copying, a receiving share extension, editable import review, source attribution, and verified complete backup/restore. **OCR and automatic structured extraction are deferred.** An image or scanned PDF is useful as a viewable original in v1, without invented route fields. Digital PDF text may be offered as unstructured selectable text when PDFKit exposes it; it is not a requirement to recognize scanned text.

Use SwiftUI, Swift, SwiftData with explicit persistence operations, app-managed original files, PDFKit/ImageIO, PhotosPicker, Foundation file APIs, and a small share-extension inbox as scoped below. The owner-approved minimum is iOS 17.5; verify affected minimum/current OS behavior under §21.6.8. Build with a currently accepted Xcode/SDK, independently of the deployment target.

The largest risks are data loss at database/file boundaries, destructive restore, share-extension interruptions, unfunded macOS automation, hostile URL content, and copyright assumptions. Address these early through persistence/restore and URL-policy spikes, fault injection, portable archive contracts, an inbox that never writes to the library database, and explicitly initiated single-page capture rather than unattended source-site crawling.

## 2. Decisions, Assumptions, and Approval

### 2.1 Confirmed Owner Decisions

| Topic | Confirmed direction |
| --- | --- |
| Product platform | Native local Swift/SwiftUI app. Service-specific Go, PostgreSQL, OIDC, Docker, health/metrics/OpenAPI requirements do not apply. |
| First-release intake | Images, PDFs, and text are required. Postpone OCR. |
| Share workflow | A receiving share extension is essential for v1, not a future enhancement. |
| Organization | Flat areas in v1; no nested-area UI or hierarchy field needed yet. |
| Pitch count | Derive from actual pitch records, not a separately editable route count. |
| Length | Optional explicitly entered route total, independent of individual pitch lengths. |
| Grades/styles | Free-text grades; small extensible style vocabulary. |
| Restore | Replace-only, with validation and rollback. No merge. |
| Source handling | Owner follow-up requires copying from a user-supplied URL after an explicit user action, not reference-only handling. Preserve selected originals and received/extracted text until explicit deletion. Camera deferred. |
| Funding | Assume Apple developer membership exists. No other recurring costs. |
| Deployment target | iOS 17.5 minimum approved; latest iPhone/iOS is the primary development target, with affected/manual minimum-support checks under §21.6.8. |
| Staffing/development | One volunteer developer using an existing MacBook Pro, VS Code, and GitHub. Weekly availability is not specified. |
| Repository/CI | GitHub Free, public repository confirmed by owner. Use standard hosted macOS GitHub Actions; no GitLab pipeline or runner-tag requirement. |
| Approval and execution | Owner approved the plan after the dependency recommendation and confirmed public GitHub publication. |
| Dependency exceptions | Approved plan includes native Xcode/SPM resolution on local/hosted Macs, reviewed stable ZIPFoundation resolution with committed Package.resolved, and immutable third-party Action references with deliberate updates. |
| Integrity limits/restore | Initial intake/archive/library limits and generation-based replace/revert behavior approved as measurable targets, subject to the stated validation spikes. |
| Platform presentation | Owner confirmed iPhone as primary target with minimal iPad support. |
| Code license | Owner approved starting with MIT after discussing GPLv3 distribution concerns; MIT supersedes the earlier GPLv3 selection for first-party code. Preserve third-party notices. |
| Release ownership | Leif Johnson owns signing, releases, support and privacy URLs. Owner-controlled leifdigital.com will host new app pages without additional hosting costs; pages are not yet built. |
| Language and retention | English-first UI with Unicode user content confirmed; retain originals/raw text until explicit deletion, without automatic expiry of ready deliveries or saved drafts. |
| Minimum-runtime availability | Historical 2026-10-28 foundation evidence: 19 tests passed on iPhone 15 Pro/iOS 17.0 and on iOS 27.0. This does not qualify the current iOS 17.5 floor or physical devices; reverify destinations before execution. |

The owner's explicit answers supersede handoff scope ambiguities. In particular, the handoff's OCR acceptance item becomes a later-release criterion, while non-OCR intake and share receiving become v1 requirements.

### 2.2 Engineering Defaults and Approval Boundaries

- Schedule illustrations use 10 hours/week, not an owner-specified commitment. Staffing is confirmed as one volunteer; do not assume additional reviewers are available.
- Owner-confirmed presentation: iPhone-first native UI with minimal adaptive iPad support and no iPad-exclusive features. Verify basic iPad functionality.
- Foundation/SwiftData APIs must remain within the approved iOS 17.5 deployment target. Do not use newer SwiftData inheritance or custom-store APIs for v1.
- SwiftData is the implemented persistence direction. The original migration/snapshot/generation-switch selection gate and Core Data fallback are historical rationale, not permission to restart research or switch frameworks. Unresolved migration/recovery capabilities gate dependent features; framework changes require separate owner approval. Do not maintain parallel implementations.
- Minimal structured import: review manually, optionally copy unstructured text into selected sections. No heuristic name/grade/pitch extraction until the post-v1 import phase.
- Owner approved MIT as the starting first-party code license on 2026-10-28, superseding the earlier GPLv3 selection. Code licensing never licenses user-imported material. Preserve dependency notices and confirm the copyright holder before finalizing the license notice; release ownership and builder attribution do not independently establish copyright ownership.
- Approved dependency direction: ZIPFoundation through Swift Package Manager with reviewed stable-release updates and committed Package.resolved for reproducibility. Native resolution and the narrow reproducibility exceptions are included in the owner's subsequent plan approval. No dependency installation occurs in this planning session.

### 2.3 Approval Gates

Approval of this plan authorizes only the subsequently agreed implementation scope, including user-initiated single-page copying as requested by the owner. It does not authorize payments, publishing, signing changes, unattended crawling, access-control bypasses, or uploading user data. Resolve the policy and infrastructure gates in section 16 before dependent work begins. Any failed spike that changes persistence, backup format, or deployment target requires a documented owner decision before proceeding.

## 3. Goals, Users, and Scope

### 3.1 Personas and Jobs

| Persona | Primary job | Success signal |
| --- | --- | --- |
| Multipitch trad climber | Prepare approach, pitch, belay, gear, and descent notes | Can reach relevant beta quickly in Airplane Mode |
| Screenshot collector | Organize screenshots, topos, PDFs, and text | Shares material into a reviewable inbox without transcription being mandatory |
| Privacy-conscious notebook owner | Keep and recover personal information | No app account or developer data collection; portable complete backup |
| Volunteer maintainer | Make safe incremental changes | Small project, clear contracts, meaningful tests, documented release ownership |

### 3.2 Committed V1 Requirements

| ID | Requirement | Verification |
| --- | --- | --- |
| R01 | Area and route create/edit/delete, flat organization, route moves between areas | Model and UI tests |
| R02 | Route name, area, grade, styles, optional total length, description, sources | Validation and persistence round trip |
| R03 | Pitch create/edit/reorder/delete with grade, length, description, protection, and belay notes | Five-pitch acceptance scenario |
| R04 | Approach, descent, gear, general, and custom route note sections | Empty/custom/reorder tests |
| R05 | Multiple images/PDFs associated with route, pitch, or note; captions, tags, ordering | Attachment ownership and viewer tests |
| R06 | Local area/route name search; browse with grade/style/pitch summary | Offline search tests |
| R07 | Explicit acknowledged Save/Cancel, clear pending/error states, retained failure buffers and honest interruption limits | Save-failure, discard and termination tests |
| R08 | Image/PDF/plain-text/pasted-text intake, explicit user-initiated URL copying, and share extension with manual review before commit | Intake/URL matrix and inbox recovery tests |
| R09 | Complete versioned backup and validated replace restore, preserving IDs, sources, drafts, and media | Semantic and byte-level round trip |
| R10 | Safe deletion, shared-file protection, orphan reconciliation | Reference-count and fault-injection tests |
| R11 | Dynamic Type, VoiceOver, readable contrast, alternative pitch reorder actions | Manual accessibility and UI tests |
| R12 | Honest offline/local status and external-link warnings | Airplane Mode and missing-file tests |

### 3.3 Deferred or Excluded

P1 after v1: Vision OCR, explainable field extraction, uncertainty indicators and language/layout handling, grade/style filters, optional favorites, direct camera capture.

P2 only after separate planning: CloudKit synchronization, conflict resolution, annotation, GPX/offline maps, selective sharing/collaboration, public data. Stable IDs and provenance are preparation, not a promise of CloudKit compatibility.

Excluded: backend, authentication, subscriptions, ads, paid APIs, analytics SDKs, LLM calls, background/bulk source downloads, recursive crawling, private endpoints, access-control circumvention, navigation/weather services, and public redistribution of imported copyrighted material. Explicit user-initiated copying of one supplied page is included; it is not a claim that all sites permit copying.

## 4. Screen and Interaction Specifications

[DESIGN.md](DESIGN.md) owns approved screen composition. This section supplies complete-product functional requirements, not competing layouts or proof of implementation. Unresolved screen details are listed in DESIGN; do not infer them from older mockups.

### 4.1 Navigation

Use a native library navigation stack, route detail as the primary workspace, and toolbar access to Import Inbox and Settings. On wider screens, a split presentation may reuse the same views. Avoid adding a tab solely for empty future features.

### 4.2 Library and Areas

- Library displays flat areas plus local search across areas/routes. Route rows show name, free-text grade, style summary, and entered pitch count.
- A new route requires a nonblank name and an area; create an area inline if necessary. Duplicate names are allowed and distinguished by area and metadata.
- Search is case/diacritic-insensitive substring matching of normalized names; literal user input is never executable predicate syntax. Empty search returns the current browse context. Use deterministic name/UUID tie-breaking and bounded paged fetches.
- Area deletion is blocked while routes remain. Offer moving routes to another area first; do not hide cascade deletion behind an area action. Bulk destructive route deletion is not required.
- Empty library, no search results, unreadable store, and unavailable protected files have distinct states. Store failure must never silently open a new empty library.

### 4.3 Route Detail and Editing

Use DESIGN's General, Approach, Pitches, Descent, Gear, References, Sources composition and readable section jumps. Do not show routine saved/loaded badges on reading screens. Pitch access takes one tap from the visible list or a section jump plus a tap from a long route. Future sections are not permission to split existing General prose.

Use plain text, not HTML or an embedded rich-text engine. Common empty sections show an Add action without requiring content. Custom sections can have arbitrary titles and order. Reordering sections does not alter their kind. One common section of each predefined kind per route; multiple custom sections are allowed.

All non-destructive editors use source-bound buffers and explicit Save/Cancel. Focus loss, navigation, keyboard dismissal and scene transitions do not commit. Save closes only after acknowledged success; failures retain exact input with actionable retry/review. Saving prevents duplicate submission and conflicting dismissal. Stale revisions never silently overwrite saved content.

Changed Cancel requires Discard Changes/Keep Editing; unchanged dismissal does not invent a save. Cancel never rolls back unrelated saved edits. Unacknowledged work can be lost on termination; editor draft recovery is not promised. Intake's persisted drafts remain governed separately by §§7-8. The former debounce/autosave and Done/Back direction is retired, not a future default.

Route deletion confirms the route name and counts of affected pitches, notes, and attachments. Committed deletion is durable before file reclamation begins. It does not delete unrelated drafts or files referenced by other routes.

### 4.4 Pitch Editor

Sequence is contiguous, zero-based internally; show 1-based position. Optional display name is separate from sequence and is never renumbered as authored text. Expose Move Up/Down for accessibility as well as drag reorder. Reorder commits the whole sibling sequence in one database save. A stale editor revision causes a reload/review conflict, not a last-write-wins overwrite.

Length accepts positive finite decimal values plus meters/feet; no implicit unit or silent conversion. Unknown grade/length stays blank. Route count displays `0 pitches entered` when none exist, not a claim that the route has no pitches. Users can write an expected total in overview/general notes; there is no second count field in v1. Route total and entered-pitch sum may differ; a computed sum, if shown, is labeled and never updates the route total.

### 4.5 Media and PDF Viewer

Use generated thumbnails for grids, ImageIO downsampling for display, zoom/pan for images, and PDFKit for offline multipage PDF viewing. Preserve the received original bytes; Photos providers may supply a compatible representation rather than the camera's archival original, so do not claim recovery of an unavailable original. No recompression on backup.

Show caption, tags, source, association, and original file type. A PDF can be attached directly to any supported owner and opened without rasterizing all pages. Corrupt or unsupported originals yield an explicit error without deleting the file. Missing files show an incomplete-local-content state, not an offline-ready badge. Dynamic Type applies to surrounding controls; image captions provide VoiceOver context but do not claim to make topo geometry accessible.

### 4.6 Intake, Inbox, and Review

1. Intake via PhotosPicker, Files, user-triggered Paste, user-supplied URL with explicit Copy Page action, or Share with Climbing Notebook. Receiving/pasting a URL alone saves a reference draft and does not make a network request.
2. Copy provider-owned files into durable managed intake storage before acknowledging receipt; original provider URLs are temporary, not persistent references.
3. Display an Inbox draft with file list, previews, optional source URL/title/attribution, and any available raw text. Images and scanned PDFs explicitly say `Text recognition is not included in this version`.
4. User selects New Route or Add to Existing Route. For New Route, manually enter name/area and optional fields. For Existing Route, default to adding attachments or a new imported/custom note, never replacing existing prose.
5. User selects route/pitch/note attachment targets and may copy text into chosen sections. No structured inference in v1. Any explicit replacement of existing text requires a preview and confirmation.
6. Commit validates all targets and files, persists provenance and record changes, and marks the draft consumed in the same database save. On failure keep the draft reviewable. Discard deletes only draft-owned references after confirmation.

V1 accepts JPEG, PNG, HEIC, PDF, UTF-8 plain-text files (optional UTF-8 BOM), pasted plain text, and HTTP(S) URLs for references or explicit page copying. Reject other text-file encodings with an actionable conversion message rather than replacement-character decoding. Unsupported formats, videos/Live Photo motion, folders, rich text, and encrypted/password-required PDFs are not silently flattened or downloaded. For a Live Photo, offer only an image representation if the provider supplies one.

Digital PDF text may be shown as an unstructured convenience; preserve page boundaries and warn that column reading order is unverified. No automatic pitch grouping. Keep raw received text separate from user-edited text. URLs inside received prose are not fetched. A shared URL and image/text can belong to the same draft; do not assume the host supplies the full webpage.

#### User-Initiated URL Copy Flow

From a typed/pasted/shared URL draft, offer `Keep Link Only` and `Copy Page`. Explain before loading that copying needs network access, contacts the source site, and requires the user to have applicable rights. The Copy Page tap initiates one page load, followed by preview/review; nothing is written into a saved route automatically. Allow retry, cancellation, and a link-only fallback.

Proposed implementation: an isolated, nonpersistent WKWebView preview with no app credentials, custom cookies, or privileged script bridge. Loading can execute ordinary site scripts and request subresources; disclose that this is browsing, not offline viewing. After load, let the user explicitly capture page text and select individual page images/topos to copy. Preserve received text before edits, requested/final URLs, title, capture time, and user-supplied attribution. Generic rendered-page text extraction is not automatic route/grade/pitch parsing. Show the captured text and image candidates for selection before durable draft commit; do not silently import navigation/ads as climbing beta or download every image on the site.

Copy the page's readable text as the proposed payload and selected image representations into managed storage. Capture is not a full webpage archive: no executable HTML/scripts, embedded trackers, linked pages, or live remote image references are stored as offline beta. Save selected PDF links only after a separate explicit document-copy action through the same limits/validation. Scanned images/PDFs remain viewable without OCR. If generic capture fails, offer user selection/paste, browser sharing, or manual file intake; no source integration is required for those fallbacks.

Never recurse, follow route lists, prefetch linked routes, refresh captures in the background, solve CAPTCHAs, bypass logins/paywalls/DRM, reuse another app's cookies, or access private endpoints. Public availability and a user tap do not establish legal permission; show source-specific restrictions where known and obtain appropriate review before shipping site-tailored extraction. The generic URL-copy capability is committed v1 scope, not deferred merely because a source lacks an API.

### 4.7 Settings and Data Management

Provide Export Complete Backup, Restore/Replace Library, backup history (creation/export handoff time, not a guarantee of external durability), approximate storage by originals/drafts/cache, pending inbox count, privacy/local storage explanation, source rights guidance, version, licenses, and project information.

Restore displays archive version/date/counts, validation outcome, current-library counts, an optional export-current-library action, and an explicit Replace confirmation. A restore never starts from merely opening a file. No Merge button. Warn that replacements remove all current saved records and drafts; unprocessed share deliveries remain queued and are identified as pending afterward.

## 5. Architecture and Technology Decisions

### 5.1 Boundaries

Presentation -> feature coordinators -> library persistence and managed-file services. Intake -> draft review -> the same library mutation path. Backup uses portable DTOs, not UI state or a raw database copy. The share extension writes only an App Group inbox; the main app alone owns and mutates its SwiftData library.

Use a single Xcode project with app, share-extension, unit/integration-test, and UI-test targets. Small shared source files for inbox contracts and safe file transfer can have membership in both app and extension targets; no package split is necessary. Shared files must use extension-safe APIs only. Avoid a generic repository-per-entity hierarchy, dependency injection framework, networking stack, or hypothetical sync engine.

Use `ClimbingNotebook` for project, scheme, module and source names, and `climbing-notebook` for the repository slug. The project-level `DEVELOPMENT_DISPLAY_NAME` build setting is the entry point for future display branding: it supplies the generated app `CFBundleDisplayName` and the extension display name, while the app reads `CFBundleDisplayName` for its title. Keep technical identifiers independent of future marketing names. Development bundle identifiers rooted at `com.climbingnotebook.foundation` are provisional pending permanent registration, not registered release identities. Artwork and colors remain placeholders until separately designed.

### 5.2 Framework Choices

| Concern | Choice and rationale | Constraint/spike |
| --- | --- | --- |
| UI/navigation | SwiftUI with small UIKit bridges for share receiving/PDFKit | Native accessibility and editor recovery tests |
| Persistence | SwiftData, versioned schema from first build, explicit save and rollback | Migration/reopen/delete/recovery spike; Core Data fallback only by decision |
| File storage | Foundation FileManager/FileHandle, Application Support originals, Caches thumbnails | File-first/database-second discipline and integrity journal |
| Image intake | PhotosPicker and UTType; file picker security-scoped access | No broad photo-library or camera permission required for picker-only scope |
| Image rendering | ImageIO downsampling, bounded thumbnail work | Do not decode full-resolution images for grid cells |
| PDF/text | PDFKit, Foundation strict UTF-8 decoding | Page limits, malformed PDF handling, no OCR requirement |
| User-initiated URL copy | WebKit preview, generic rendered-text capture, explicit selected-asset copying | Nonpersistent browsing session; no crawling or access-control bypass; resource and navigation policy tests |
| Receiving share | UIKit extension controller, NSItemProvider, App Group mailbox | No direct database access, no assumed main-app launch |
| Hashes | CryptoKit SHA-256, incrementally | Integrity, not authenticity or encryption |
| Archive | ZIP manifest + originals, approved ZIPFoundation direction | Verify license, stable release, ZIP64 and untrusted archive limits in M1 |
| Future OCR | Vision text recognition, separate later service | On-device, explicit uncertainty; never required for saved content |
| Testing | XCTest/XCUITest with real temporary on-disk stores | In-memory tests alone cannot validate migrations or recovery |

### 5.3 Concurrency and Persistence

A single LibraryCoordinator serializes library mutations and owns contexts on their required executor. UI consumes stable-ID snapshots or main-actor reads and submits typed commands; do not transfer live persistent models across actors. File hashing/copying and thumbnails run off the main actor with bounded concurrency and cancellation. No unbounded task per image or background indexing of the entire library at launch.

Use a library-level operation gate for restore, export snapshot capture, and migration. Editing is paused during destructive replacement. Route-scoped revisions detect stale editors; persistence commands return the updated revision. Two views must not independently save conflicting copies without detection. Mutation rollback refreshes affected presentation snapshots.

CloudKit is explicitly disabled and no iCloud entitlement is added. Configure the SwiftData store URL inside the active library generation. Do not share that store with the extension or infer that future sync will fit its constraints without migration work.

### 5.4 Deployment Recommendation

The owner-approved minimum is iOS 17.5. SwiftData's ModelContainer and VersionedSchema are documented from iOS 17 [S1-S2]; availability alone does not prove app-specific reliability. App Groups and NSItemProvider predate that target [S3-S4]. Preserve the floor unless separately approved based on concrete evidence.

Use current development and affected/manual minimum-runtime checks under §21.6.8; do not provision or substitute destinations silently. Xcode/SDK upload requirements are separate: Apple's dated notice requires Xcode 26+ and iOS 26 SDK+ since April 28, 2026 [S5]; recheck live submission rules before each release.

## 6. Logical Data Model

### 6.1 Conventions and Relationships

All durable IDs are UUID strings in portable output. Use UTC RFC 3339 timestamps with milliseconds in exports. Names need not be globally unique. Optional values are null/absent, never fabricated zeroes. Lengths are decimal value plus unit enum `m` or `ft`; export decimals as decimal strings to avoid binary rounding drift. Created/updated times are informational, not conflict-resolution clocks.

Relationships are UUID-based in portable DTOs and explicit inverse relationships in persistence where useful. One area has many routes; a route owns pitches, note sections, source references, and attachment links. Attachment links point to reusable immutable MediaAssets. Import drafts have separate asset links. No names/array indices or absolute sandbox paths serve as identity.

| Entity | Fields and purpose |
| --- | --- |
| Area | id, name, optional regionText and notes, createdAt, updatedAt, revision. No parentID in v1. |
| Route | id, areaID, name, optional grade string, styleLabels, optional length value/unit, description, createdAt, updatedAt, revision. Pitch count is derived. |
| Pitch | id, routeID, order, optional displayName/grade/length value/unit, description, protectionNotes, belayNotes, createdAt, updatedAt. |
| NoteSection | id, routeID, kind (`approach`, `descent`, `gear`, `general`, `custom`), title, body, order, updatedAt. Route-scoped only in v1; pitch-specific prose uses Pitch fields. |
| MediaAsset | id, managed storage key, original display filename, UTType, byteCount, SHA-256, optional pixel dimensions/pageCount, createdAt. Immutable original bytes; no blob embedded in the model. |
| MediaAttachment | id, routeID, optional pitchID, optional noteSectionID, assetID, caption, tags, order, optional sourceReferenceID, createdAt, updatedAt. One owning context: route, pitch, or note. |
| SourceReference | id, routeID, optional requestedURL/finalURL, sourceName/title, attribution, method (`manual`, `photos`, `files`, `paste`, `share`, `urlCopy`), importedAt/capturedAt, optional rawText, retainedAssetIDs through SourceAsset links. |
| SourceAsset | id, sourceReferenceID, assetID. Keeps source originals alive independently of visible gallery placement. |
| ContentOrigin | id, routeID, targetEntityID/type, fieldKey, sourceReferenceID, status (`imported`, `editedFromImport`). Marks specific prose/metadata fields created from a source without conflating all route text. |
| ImportDraft | id, state (`review`, `committed` receipt), receivedAt, optional source URL/title/attribution, immutable rawText, editable proposed fields, optional targetRouteID, validation warnings, revision. No saved route exists until confirmation. |
| DraftAsset | id, draftID, assetID, order, suggested caption/target. Original retention before route commit. |
| InboxReceipt | deliveryID, acceptedAt, optional draftID, outcome. Prevents re-ingestion after process interruption; generation-local. |

MediaAsset is the one justified addition to the handoff's entities: it separates original bytes from contextual attachment metadata. Reuse is explicit when attaching an already managed asset. Do not implement cross-file content deduplication in v1; equal hashes do not require shared asset identity.

### 6.2 Invariants

- Route area exists; pitch/note belongs to exactly one route. No cycles because areas are flat.
- Attachment route is mandatory; pitchID and noteSectionID are mutually exclusive. If set, the referenced owner belongs to that route. Gallery-only attachments have both null. Source references and origins must belong to the same route as the target.
- Asset references must resolve and originals must exist before a record is reported saved/available. Assets referenced only by retained sources or drafts are still live.
- Pitch and sibling note/attachment orders are unique contiguous nonnegative integers within their owning context. Reordering renormalizes one group atomically. Original display names are not order keys.
- Name/title validation trims only for emptiness; preserve meaningful user text. Proposed limits: 500 characters for names/titles, 1 MiB UTF-8 per prose/raw-text field, 32 tags per attachment, 100 characters per tag, 100 pitches per route. Errors are explicit; never truncate.
- Initial styles: Trad, Sport, Aid, Mixed, Ice, Alpine, Boulder, Other, plus user-entered labels. Multiple styles allowed; trim/deduplicate case-insensitively while preserving display spelling. No semantic grade ordering or grade normalization.
- Any text edit derived from an imported field retains its source link and changes the origin marker to editedFromImport. Raw received text stays immutable. Provenance is field-level lineage, not an audit log or verification claim. Explicit replacement from another source shows the old provenance before confirmation.
- Deleting a source must warn if content-origin markers or retained originals depend on it. Offer removing the link while keeping notes, or cancel; no cascading deletion of authored content.

### 6.3 Deletion and File Lifetime

Deleting a route removes its pitches, sections, attachment links, content origins, and source links in one persistent operation. Assets are not cascade-deleted by route relationships. Recompute reachability across MediaAttachment, SourceAsset, DraftAsset, and active operations before reclamation. Deleting a pitch/note removes its contextual links; the confirmation states this and offers moving attachments to route level first.

A post-commit sweeper marks unreferenced assets for cleanup, with a proposed 24-hour grace period and a fresh reference check before removal. Failed file removal is retryable and does not roll back a committed route deletion. This grace is not user-visible Undo. Journal and startup reconciliation distinguish abandoned file copies from live assets; never sweep active staging, rollback generations, or ready mailbox deliveries. A shared-asset test across two routes is mandatory even though automatic deduplication is deferred.

### 6.4 Schema Evolution

Begin with a versioned local schema and a migration plan. Local schema version, backup format version, and share-envelope version are independent. Archive v1 is never a serialized SwiftData object graph. Preserve migration fixtures from every released schema; require upgrade and export-after-upgrade tests. If migration fails, keep old files, do not recreate the store, and offer recovery/export guidance. Preserve a consistent closed-store generation before destructive migrations, including database sidecars; do not copy an open database file and assume it is complete.

## 7. Contracts and API Boundaries

There is **no hosted HTTP API**, OpenAPI document, authentication callback, or metrics endpoint in v1. Networking is limited to explicit URL-copy browsing/selected downloads and user-directed external actions. The public contracts are application operations, a receiving share mailbox, supported documents, and the backup format. The following are specifications, not Swift code.

### 7.1 Application Service Contracts

| Operation | Input | Success | Errors / guarantees |
| --- | --- | --- | --- |
| Browse/search library | area scope, literal query, page cursor | Deterministically ordered area/route summaries | Invalid/stale cursor resets page; no network |
| Create/update route or area | Validated values; UUID and expected revision for updates | Saved snapshot and revision | validation, staleRevision, unavailableStore, diskFull; no partial related update |
| Mutate/reorder pitches/notes | routeID, expected revision, full sibling ID ordering for reorder | Saved route revision | Reject duplicate/missing/foreign IDs; all-or-nothing sequence |
| Stage intake | Supported provider/file/text input, cancellation token | Durable draftID with raw input and warnings | unsupportedType, unavailableProvider, deniedAccess, limitExceeded, cancelled; no route mutation |
| Copy supplied URL | draftID, explicit Copy Page consent, validated HTTP(S) URL; later explicit text/image selections | Reviewable local draft, raw text, selected copied assets, requested/final URL and timestamp | offline, blockedSource, redirectedOrigin, timeout, unsupportedType, limitExceeded, cancelled; no route write, crawl, or implicit retry |
| Commit import | draftID/revision, destination, reviewed field mappings and replacement approvals | routeID, revision, committed draft receipt | staleTarget, missingAsset, validation, persistenceFailure; one metadata commit; retry does not duplicate |
| Attach original | owner IDs, copied validated asset, caption/tags | AttachmentID and saved state | File publication precedes metadata; recover orphan on interruption |
| Delete/detach | entityID and expected revision | Durable deletion receipt | File reclamation deferred; unrelated references preserved |
| Export complete backup | active generation, destination handoff request | Verified temporary archive URL, counts, hash, creation time | Flush/snapshot failure blocks export; no incomplete archive advertised as complete |
| Validate restore | archive URL, supported-version policy | Immutable validation token, summary, warnings | No current-library writes; token binds archive hash and current library revision |
| Replace library | validation token, explicit confirmation | New active generation ID and summary | Reject changed archive/library; retain prior generation until successful reopen |

All long operations expose phase, completed/total bytes or items when known, cancellation, and actionable typed failures. Cancellation is allowed before the restore switch; after switching, finish recovery to a coherent generation rather than leaving half a replacement. No operation reports success merely because an async task was started.

### 7.2 Share Extension Mailbox Contract

Use a registered App Group shared by the app and extension. The app's main library stays in its private container; the App Group holds only intake envelopes and their payloads.

Each delivery has `envelopeVersion`, UUID `deliveryID`, receivedAt, optional host-supplied title and HTTP(S) URL, optional UTF-8 text, and ordered items containing local item UUID, detected UTType, sanitized display filename, payload-relative key, byteCount, and SHA-256. Host bundle identity is optional and not inferred through private APIs.

Lifecycle: create `staging/<deliveryID>` -> stream/copy every supported selected payload -> write envelope -> atomically rename within the same container to `ready/<deliveryID>` -> report `Saved to Climbing Notebook Inbox. Open Climbing Notebook to review.` Never report `Route saved`. Never rely on launching the app from the extension. Failed or cancelled deliveries stay unpublished and show an error; mixed supported/unsupported items require an explicit supported-items-only choice rather than silent omission.

The main app reads only ready envelopes, validates sizes/hashes/paths, copies into its managed draft store, persists InboxReceipt and draft in one save, then removes the shared delivery. If interrupted after save but before removal, receipt lookup prevents duplicate drafts. Retrying a share with a new deliveryID intentionally creates a new draft; no name-based deduplication. An atomic ready publication plus per-delivery file coordination prevents app/extension races; an actor alone cannot synchronize processes.

Proposed envelope limit: 20 items, 50 MiB per image, 200 MiB per PDF, 1 MiB text, 250 MiB aggregate per delivery. Stream file representations, avoid in-memory loading of whole PDF/image collections, and reject oversized payloads with Files-import guidance. Extension memory/time budgets are not fixed contractual numbers; test on device. Copy provider temporary URLs before their callback lifetime ends, or use an API with a documented lifetime. Reclaim only clearly abandoned unpublished staging older than 24 hours under coordination; ready deliveries are user data and never silently expire.

## 8. Media Storage and Data Integrity

### 8.1 Storage Layout

| Location | Contents | Backup policy |
| --- | --- | --- |
| App Application Support/LibraryState | Atomic active-generation descriptor and recovery journal | Included in OS device backup |
| App Application Support/Libraries/<generationID> | SwiftData store/sidecars, immutable assets, persisted drafts and receipts | Included; required for app library |
| App Application Support/Operations | Interrupted-operation metadata and bounded staging | Recoverable staging excluded where safely reproducible |
| App Caches/Thumbnails | Regenerable previews keyed by asset/hash/size | Excluded from portable and OS backups |
| App temporary export staging | Snapshot manifest and archive | Excluded; delete after handoff lifetime or startup cleanup |
| App Group Inbox | Staging and ready envelopes/payloads | Ready user content included where platform backup behavior permits; app backup warns about unprocessed deliveries |

Do not store originals in Caches or tmp. Relative asset keys are generated from asset UUIDs, never filenames supplied by a document or archive. Apply suitable iOS file protection, proposed completeUntilFirstUserAuthentication to support ordinary post-unlock offline viewing and extension intake; fail visibly before first unlock rather than weakening protection. Verify actual app/extension backup and protection behavior on device.

### 8.2 Write and Recovery Protocol

For attachment intake: copy to managed staging, check byte limits and actual decoder type, compute hash, publish immutable asset in the current generation, then persist asset/link/draft metadata. A failed database save leaves a recoverable orphan, not a broken saved attachment. A journal identifies the operation and intended asset IDs. On restart reconcile metadata against files; report missing live assets and quarantine unexpected files rather than automatically guessing ownership.

For editing text: persistence failure must preserve editor/draft text and show retry. The app does not claim every keystroke survives a sudden kill. For large file operations: stream and update progress, preflight free space, recheck as writing progresses, and preserve the prior library on ENOSPC or protection errors.

Thumbnails may fail independently of original preservation. Bound decode size and concurrency; apply PDF page/pixel budgets before preview generation. Proposed PDF intake limit is 500 pages and image decoded dimension limit is 100 megapixels, subject to the foundation measurement gate. No original is discarded because preview generation fails.

## 9. Complete Backup and Replace-Restore Contract

### 9.1 Portable Format

Proposed extension: `.climbing-notebook-backup`, declared as an exported UTType conforming to ZIP. A user may rename it to `.zip` to inspect it with standard desktop tools. Use standard ZIP entries with stored/deflate methods; do not call Apple Archive or raw Compression streams ZIP [S6]. No password/encryption support in archive v1. Warn that archive contents, EXIF location data, sources, and personal notes are readable to anyone with the file.

Archive root contains exactly:

- `manifest.json`: UTF-8, format identifier `com.climbingnotebook.backup` (provisional namespace), integer formatVersion `1`, minReaderVersion, backupID, libraryID, createdAt, app version/build, entity counts, and portable entity arrays.
- `media/<assetUUID>/original.<validatedExtension>`: every referenced original, including draft-only/source-only assets. The manifest maps asset ID to path, byteCount, UTType, and SHA-256.

Manifest arrays: areas, routes, pitches, noteSections, mediaAssets, mediaAttachments, sourceReferences, sourceAssets, contentOrigins, importDrafts, draftAssets. Each array uses stable IDs and explicit relationships per section 6. InboxReceipt is operational state and is not exported. Transient committed draft receipts are not content and can be omitted once their delivery cleanup finishes. Reviewed but uncommitted drafts and originals are included. Device preferences, thumbnails, caches, logs, operation journals, obsolete generations, and absolute paths are excluded.

Before export, main app ingests ready mailbox deliveries present at capture time. Export pauses final snapshot capture briefly, flushes acknowledged changes, freezes a consistent DTO/asset-ID snapshot, and pins those immutable assets against deletion until archive completion. New share deliveries after that boundary remain queued and are explicitly not part of that backup. Show a pending-inbox warning if any delivery could not be ingested; do not silently describe such an export as complete.

Contract examples, described without an implementation scaffold: a route record references `areaID`, has no stored pitchCount, and may have `length = {value: "350", unit: "m"}`. An attachment record points to assetID and its routeID, plus at most one pitchID/noteSectionID. Schema documentation later must include complete examples for each entity and nullability/enum rules.

### 9.2 Version and Compatibility Rules

For v1, accept only formatVersion 1 and minReaderVersion <= 1. Unknown additive optional fields may be ignored; unknown required entity kinds/enums or incompatible semantics reject the archive. Future version readers must have explicit converters and fixtures; do not assume major/minor compatibility. Preserve UUIDs and original createdAt/updatedAt values when replacing. Duplicate UUIDs in any entity collection are invalid, not a merge opportunity.

Use deterministic ID ordering for exported entity arrays; preserve user-visible order via order fields. CRC plus SHA-256 verifies accidental corruption, not trusted origin. A manifest cannot safely authenticate itself, so do not claim tamper-proof backups.

### 9.3 Export Algorithm

1. Reconcile pending intake, show unsaved editor state, and refuse a supposedly complete export while acknowledged library assets are missing.
2. Acquire mutation gate for flush and snapshot capture, create a manifest from portable DTOs, and pin snapshot assets. Then allow ordinary edits to resume while building from the immutable snapshot.
3. Preflight estimated media plus JSON/archive workspace. Stream originals and hashes into a temporary archive with cancellation/progress; never assemble the whole archive in RAM.
4. Reopen the finished archive, validate entry list/manifest/hashes/counts against the snapshot, and only then offer Files/share export. Failure removes only temporary output.
5. Keep export output valid for the document/share provider's required access lifetime. Record `Archive created`/`Export handed off`, not `Safely backed up` unless external durability can actually be verified. Clean old temporary exports on next launch after their access lifetime ends.

Proposed supported performance envelope: 2,000 routes, 10,000 pitches, 5,000 original assets, and 5 GiB total originals. JSON is capped at 64 MiB and archive entries at 25,000. These are explicit resource ceilings to validate, not a claim of already measured performance. Libraries approaching limits need warnings before accepting more content; never let intake create a library the exporter refuses without warning. Validate ZIP64 behavior for >4 GiB archives in the foundation spike before promising the 5 GiB envelope.

### 9.4 Validation of Untrusted Backups

Copy or hold coordinated security-scoped access to the selected file and bind validation to its SHA-256 so a provider cannot swap contents between validation and application. Validate before current-library mutation:

- Parse bounded UTF-8 JSON; check format, versions, required fields, counts, data types, string/collection limits, finite positive lengths, valid units, UUID uniqueness, dates, and ordering invariants.
- Verify all foreign keys, owner consistency, source/origin targets, and draft/asset relationships. Reject dangling references and extra unexpected payload files.
- Reject absolute paths, traversal (`..`), backslashes/alternate separators, path aliases after normalization, duplicate/case-colliding entries, symlinks, hard links, encrypted entries, unsupported methods, and directories/files outside the exact expected namespace. Generate output paths from validated IDs rather than trusting archive paths.
- Enforce total inflated-byte, per-file, manifest, entry-count, image/PDF safety, and available-disk limits during streaming as well as before extraction. Do not trust header sizes alone. Stop over-expansion even when a ZIP is internally valid; do not blindly extract with a convenience unzip API.
- Verify bytes and SHA-256 for every asset and decode eligibility for viewable types. Report specific corruption, unsupported-version, insufficient-space, or invalid-relationship failures. Current library remains untouched.

The supported envelope and per-asset limits are the same as ordinary intake so a valid exported archive restores. Hash validation never substitutes for resource/type checks.

URL-copy output uses the same original/asset and text limits as other intake. Proposed network controls: HTTPS by default; HTTP requires a visible insecure-source warning and narrowly reviewed transport policy, never a blanket App Transport Security disablement. Block non-HTTP(S) navigation, embedded credentials, loopback/link-local/private-network targets, automatic download popups, and redirects into those targets. Confirm cross-origin top-level redirects, cap redirect attempts at five, and use a proposed 30-second top-level load timeout with cancellation. Allow ordinary public CDN subresources for rendering; do not describe one page load as one HTTP request. Apply the same destination policy to selected image/PDF transfers and redirects. The M1/M4 WebKit spike must prove enforceable navigation/subresource policy, bounded rendering behavior, and safe text extraction before shipping; if WebKit cannot meet the agreed constraints, return for an alternate bounded public-HTML intake design rather than claiming protections it cannot enforce. Rate-limit retries, keep only one active preview, and validate actual transfer bytes even when Content-Length is absent or false. Never log credential-bearing/query-sensitive URLs.

### 9.5 Replace, Crash Recovery, and Rollback

Do not delete and repopulate the active store in place. Use generation directories with a tiny atomically replaced active-generation descriptor in the same filesystem.

1. Acquire the library mutation gate, flush edits, and verify the validation token still matches archive bytes and active revision. Warn if editing since validation requires another review. Share deliveries may continue to queue but are not ingested during replacement.
2. Build an isolated new generation: extract originals into generated paths, create a new store from DTOs, preserve IDs, and validate record counts/references/hashes. Existing library remains active and unchanged while staging.
3. Close all contexts/references to the old generation and ensure no file workers still use it. Persist an operation journal naming old/new generations and phase. Atomically replace the active descriptor only after the new store has been closed and successfully reopened/validated in the spike-proven sequence.
4. Rebuild presentation/services against the new generation and perform post-switch checks. If reopening fails, restore the prior descriptor and reopen the old generation; never display an empty replacement as success.
5. On startup, resolve any interrupted phase deterministically: before switch, old generation; after switch, validate new then finalize or fall back. Never infer success from a directory existing. Keep the old generation until at least a subsequent successful launch and explicit cleanup; offer a temporary Revert Previous Library action, warning that it discards edits since replacement.
6. Mark completion only after reopen checks. Resume normal edits and intake. Ready share envelopes stay queued across restore and appear as new pending drafts afterward; receipts from the replaced library cannot suppress them.

Atomic filesystem rename does not make database, memory state, and separate files one transaction. The journal/reopen protocol and fault tests supply recovery semantics. Test interruptions at every phase on actual on-disk stores. Free-space preflight includes the old generation, complete new generation, archive copy if needed, and working overhead; keep old data rather than weaken rollback to fit storage. If context release/rebind cannot be proven reliable with SwiftData, stop and review the Core Data fallback.

## 10. Source Integrations and Later OCR

### 10.1 Current Assessment (2026-10-27)

| Source | Verified evidence | V1 decision |
| --- | --- | --- |
| Mountain Project | Official Data API page says public use was deprecated in late 2020 and new requests continue to be declined [S7]. Published Adventure Projects terms, revised August 4, 2023, restrict copying/use and prohibit automated spiders/crawlers/scrapers in section 8(g); section 12 imposes additional API restrictions [S8]. | Include the generic explicit single-page URL-copy workflow, with known restrictions disclosed. No API adapter, background/bulk access, private endpoints or site-tailored extraction without permission review. A user tap is not evidence these terms permit programmatic copying; resolve that risk before advertising Mountain Project compatibility. |
| SuperTopo | Official FAQ describes printed guides and downloadable eBooks [S9]. Direct retrieval of `https://www.supertopo.com/terms.html` failed during research; no current official supported public API or general reuse grant was verified. | Include generic user-initiated URL copying where technically accessible; API/permission status remains **unverified**. No access-control bypass or site-tailored adapter without review. User-selected documents require rights assessment; purchase/free availability does not itself grant redistribution rights. |
| Generic Files/Photos/text/share | Platform intake copies only explicitly supplied representations. | Useful independent of any site's integration. Capture source/attribution, preserve originals, and never claim personal copying is automatically lawful. |

This is a technical/permission assessment, not legal advice. Before adding a source adapter, record written authorization or applicable license, content scope, redistribution limits, attribution, rate limits, endpoint stability, offline rights, and revocation handling. Generic intake must remain functional if permission is absent or withdrawn. No bundled copyrighted fixtures or screenshots without permission; use synthetic or contributor-owned material.

### 10.2 Later OCR Milestone

Add Vision extraction only after v1 integrity gates. Rasterize selected PDF pages with bounded memory; preserve page positions and original text/images. Keep OCR output, parser rule/version, candidates and alternatives separate from confirmed records. Heuristics may suggest grade/length/headings but must surface ambiguity (feet versus meters, pitch number versus grade, columns, mixed languages). Unknown values remain blank. Review is mandatory; updates are opt-in and never silently overwrite notes. Provide raw-text fallback when structured extraction fails, cancellation/resumption for large inputs, and on-device-only operation. No LLM/API is needed.

## 11. Privacy, Accessibility, and Safety

- No app account, network telemetry, crash SDK, advertising identifiers, location permission, or developer-operated server collection. Explicit URL previews/copies contact third-party sites, which may receive IP addresses, user-agent data and subresource requests; a nonpersistent WebKit session reduces retained cookies but does not make browsing anonymous. Opening source links or exporting through a cloud-backed Files provider is also user-directed external activity and may require connectivity.
- PhotosPicker avoids broad photo-library permission for selected media. Files access uses scoped access and coordinated copy with balanced release. Handle unavailable iCloud-backed originals, provider cancellation, protected files, and denied access without pretending content is already local.
- Keep clipboard access user-triggered through system paste controls. Do not poll clipboard or upload pasted beta. Only HTTP(S) source links can be previewed/opened; reject active/file/javascript schemes. No requests merely from saving/displaying a URL. Web content executes only inside the explicitly initiated isolated preview, never in saved note/media views; copied output is inert text and validated originals.
- Originals can retain EXIF location and other metadata. Preserve them to honor the byte-preservation promise, explain this in export warnings, and defer metadata-stripped sharing as a separate feature. Do not log beta text, URLs containing tokens, filenames, or user identifiers.
- Use platform file protection and OS sandbox. Portable backups are not encrypted; system device backup is user-controlled and can involve iCloud storage. Do not call OS backup guaranteed or confuse it with app synchronization. Uninstall/device loss can destroy the only copy; surface unobtrusive backup reminders based on local state only.
- Audit required-reason APIs and provide privacy manifests for each applicable target; declare accurate reasons rather than copying generic reasons. App Store privacy answers must match the shipped app and any library actually selected [S10].
- Support Dynamic Type through accessibility sizes, labeled controls/images, logical VoiceOver focus, 44-point minimum touch targets, sufficient contrast in light/dark appearances, Reduce Motion, keyboard-safe editors, non-color-only save/uncertainty states, and button alternatives to drag gestures. Test long names and localization expansion; v1 UI may be English while all user notes remain Unicode.
- State that beta is user-supplied, not verified/current navigation or safety advice. Do not label gear/anchors/descent safe or authoritative. Offline status indicates local bytes, not accuracy. Avoid a disclaimer that blocks every pitch lookup outdoors.

## 12. Planned Repository Files

The repository now contains a partial M0/M1 Xcode foundation, disposable notebook prototype, feasibility tests, scripts and CI configuration. Paths below remain the planned map, not an inventory of completed features; inspect source and the [topic verification documents](docs/verification/NotebookPrototype.md) linked at the delivery boundary for actual implementation evidence. Preserve any existing handoff material unchanged. Combine tiny files where practical rather than treating the map as a mandate for one class per file.

| Planned path | Action / responsibility | Phase |
| --- | --- | --- |
| `ClimbingNotebook.xcodeproj/project.pbxproj` and shared schemes | Create app, share, unit, UI targets; deployment/build settings and target membership | M0-M1 |
| `ClimbingNotebook/App/ClimbingNotebookApp.swift`, `AppDependencies.swift` | Compose views/services, recovery boot, active library binding | M1 |
| `ClimbingNotebook/Models/LibrarySchemaV1.swift`, `LibraryMigrationPlan.swift` | Persistent entities/inverses and schema versions | M1 |
| `ClimbingNotebook/Models/LibraryDTOs.swift`, `Validation.swift` | Portable value records, field/relationship constraints, revisions | M1 |
| `ClimbingNotebook/Features/Library/LibraryView.swift`, `AreaEditor.swift` | Browse, local search, area editing and moves | M2 |
| `ClimbingNotebook/Features/RouteDetail/RouteDetailView.swift`, `RouteEditor.swift`, `NoteSectionEditor.swift` | Route workspace and recoverable note editing | M2 |
| `ClimbingNotebook/Features/Pitches/PitchEditor.swift` | Pitch CRUD, protected drafts and reorder | M2 |
| `ClimbingNotebook/Features/Media/MediaGallery.swift`, `ImageViewer.swift`, `PDFViewer.swift` | Thumbnails, image zoom, offline PDF bridge | M3 |
| `ClimbingNotebook/Features/Import/ImportInboxView.swift`, `ImportReviewView.swift`, `IntakePicker.swift` | Manual draft review, destination and provenance controls | M4 |
| `ClimbingNotebook/Features/Import/URLCopyPreview.swift`, `ClimbingNotebook/Services/Import/URLCopyService.swift` | Explicit WebKit page-copy flow, navigation/download limits, selected-asset capture and raw-text provenance | M1 spike/M4 |
| `ClimbingNotebook/Features/Settings/DataManagementView.swift`, `RestoreReviewView.swift` | Export/restore progress, warnings, privacy and storage | M3-M5 |
| `ClimbingNotebook/Services/Persistence/LibraryCoordinator.swift`, `LibraryGenerationManager.swift` | Serialized commands, revisions, generation switch and recovery | M1-M3 |
| `ClimbingNotebook/Services/Media/MediaStore.swift`, `ThumbnailService.swift`, `AssetReconciler.swift` | Immutable original writes, preview cache, safe GC | M3 |
| `ClimbingNotebook/Services/Import/IntakeService.swift`, `ImportCommitService.swift` | Decode/copy, drafts and idempotent commit | M4 |
| `ClimbingNotebook/Services/Backup/BackupManifest.swift`, `BackupService.swift`, `RestoreValidator.swift` | Versioned ZIP/JSON contract, bounded validation and export | M3 |
| `SharedIntake/ShareEnvelope.swift`, `SharedIntake/InboxFileStore.swift`, `SharedIntake/IntakeLimits.swift` | Extension-safe versioned mailbox and coordinated file operations | M1/M4 |
| `ClimbingNotebookShare/ShareViewController.swift`, `Info.plist`, `ClimbingNotebookShare.entitlements` | Provider intake UI, exact activation types/counts, App Group capability | M4 |
| `ClimbingNotebook/Resources/Assets.xcassets`, `Localizable.xcstrings`, `PrivacyInfo.xcprivacy` | Branding placeholder, strings, audited privacy declarations | M1-M6 |
| `ClimbingNotebook/Info.plist`, `ClimbingNotebook/ClimbingNotebook.entitlements`, extension privacy manifest if needed | UTTypes/document handling, attribution, App Group, no CloudKit | M1/M4 |
| `ClimbingNotebookTests/ModelTests.swift`, `PersistenceRecoveryTests.swift`, `MigrationTests.swift` | Invariants, on-disk save/reopen and upgrade safety | Each phase |
| `ClimbingNotebookTests/MediaTests.swift`, `IntakeTests.swift`, `ShareInboxTests.swift`, `BackupRestoreTests.swift` | File lifetime, inbox crashes, corruption and round trips | M3-M5 |
| `ClimbingNotebookTests/Fixtures/` | Synthetic old-schema stores, safe/malicious archives, text/PDF/images | Each phase |
| `ClimbingNotebookUITests/NotebookFlows.swift`, `ImportFlows.swift`, `AccessibilityFlows.swift` | Core scenario, review confirmation and accessible actions | M2-M5 |
| `Scripts/test-ios.sh`, `Scripts/check-coverage.sh` | Named test-suite entry and optional xcresult coverage diagnostics; no percentage gate | M1 |
| `.github/workflows/ios-ci.yml` | Pull-request/main build, meaningful units and short UI smoke; manual extended suites, bounded artifacts, no coverage threshold | §21.6.8; verify runner/toolchain availability |
| Xcode project's shared SwiftPM `Package.resolved` | Commit reviewed dependency resolution for reproducible local/CI builds, only if exception approved | M1; ZIP policy gate |
| `.gitignore`, `kilo.json` | Exclude/deny secrets, signing material, generated output and caches; no broad permission weakening | M0 |
| `README.md`, `LICENSE`, `CONTRIBUTING.md` | Owner-approved license, setup/testing, architecture, release and governance | M0/M6 |
| `Documentation/BackupFormat.md`, `Privacy.md`, `ReleaseChecklist.md` | Exact v1 schema/examples, privacy policy, signing/release ownership | M3/M6 |

Future only: `Services/Import/OCRService.swift`, `HeuristicParser.swift`, their fixtures/tests, and an updated review UI. Do not create OCR stubs, CloudKit adapters, or empty future feature directories in v1.

No `.env` or server `config.yaml` is needed for this local app. If signing automation later uses credentials, document placeholder CI variable names, keep actual values outside the repository and agent access, and add `.env.example` only if an environment file genuinely becomes part of setup. Include `Built by Leif Digital.` in supported app/extension manifest description metadata and About/license information; this attribution does not decide trademark or App Store seller ownership.

## 13. Test Strategy and Release Acceptance

### 13.1 Coverage and Environments

Require meaningful functional/data-integrity assertions under §21.6.8, not a coverage percentage. Optional coverage diagnostics are not release or pipeline gates; do not add merging infrastructure or lengthen tests for a metric. Preserve fault-injection, exact-content and ownership assertions. Report platform-only checks honestly; no skipped or always-passing substitutes for real tests.

Use temporary on-disk stores and real files for persistence/integrity tests. Test the deployment minimum and a current simulator/runtime, plus a real older device for memory, share-host behavior, file protection, Photos, Files, and airplane-mode checks. Simulator tests cannot fully establish OS termination, data protection, or extension budgets. Run tests after every migration/dependency/SDK update and on every pull request/push to main via GitHub Actions. Use the existing MBP for minimum-runtime/device checks when hosted images lack the iOS 17 runtime; CI must not claim baseline coverage it did not execute.

### 13.2 Test Matrix

| Category | Required cases |
| --- | --- |
| Model | Duplicate names, blank name, valid/invalid decimals/units, free grades/styles, owner mismatch, no dangling origins, pitch/section order |
| Editing | Explicit Save acknowledgment, cancel/discard, navigation without saving, stale revisions, keyboard, disk full/save error and retained drafts |
| Media | HEIC/JPEG/PNG orientation, large dimensions, PDF pages, broken decoder, missing original, thumbnail eviction, shared asset references |
| Intake | Strict text decoding/BOM, empty input, huge text, unsupported types, locked PDFs, denied/unavailable provider, partial copy, cancellation |
| URL copy | No request before user action, ordinary public page, rendered text, selected image/PDF, relative URLs, cross-origin redirect, login/paywall/CAPTCHA fallback, unsafe destinations/schemes, timeouts, cancellation, false sizes, broken capture and malicious page scripts without native privileges |
| Share | Safari URL, Photos image, Files PDF/text, mixed items, multiple sequential deliveries, app not running, extension termination before/after ready publication, app crash before/after receipt |
| Backup | Full semantic round trip including provenance/drafts, byte/hash identity, same UUID preservation, large/ZIP64 archive, cancellation, full disk |
| Malicious/corrupt restore | Missing media, wrong hash, malformed JSON, unknown format, duplicate IDs/paths, traversal/symlinks, oversized inflated data, foreign owner, invalid order |
| Recovery | Terminate at each file publication/database commit/export/restore journal/descriptor step; current or new complete generation only |
| Migration | Fixtures from every released schema; failure leaves old library available; export/restore after upgrade |
| Accessibility | Largest Dynamic Type, VoiceOver route/pitch/media/source flows, Move Up/Down, non-color save/errors, light/dark contrast |
| Offline/privacy | Airplane Mode after force-quit, no app-origin network requests during core operations, explicit external links, unavailable provider content never marked local |

### 13.3 V1 Acceptance Scenarios

1. Create an area and route with five pitches, arbitrary grades, explicit meter/feet lengths, protection/belay notes, approach/descent/gear/general/custom sections. Reorder pitches and confirm displayed numbering changes without changing their names/IDs.
2. Attach images to the route and two pitches, a PDF to a note section, captions/tags, and at least one retained source original. Wait for acknowledged saved states, force-quit, enable Airplane Mode, reopen, and compare every field and view original media/PDF pages.
3. Receive an image from Photos, a PDF/text file from Files, pasted text, and a URL through Share. Confirm each appears as a draft, not a saved route. Images/scanned PDFs require no OCR. Correct/manual-enter route data, commit, and verify sources/raw text and originals remain distinguishable from personal edits.
4. Cancel/discard a nonempty draft after confirmation; verify existing notes are unchanged. Kill the extension before ready publication and after publication; only complete deliveries can be acknowledged and ingested. Kill the app after draft save before mailbox removal; no duplicate draft results.
5. Export a complete library including an uncommitted draft. Restore into a clean installation with no network. Compare UUID sets, area/route/pitch/note/attachment/asset/source/draft counts, values, order, source lineage, and all original byte hashes.
6. Replace a nonempty library only after validation and explicit confirmation. Inject interruption at every phase. Restart into the entire old or entire new generation; demonstrate recovery/revert before cleaning old files.
7. Present corrupt/unsupported/traversal/over-expanding archives and simulate insufficient storage. Existing library and originals remain unchanged, with actionable failure messages.
8. Share one MediaAsset between two routes; delete one route, run reclamation after its grace period, and confirm the other route/source/draft retains its file. Delete final references and confirm eventual cleanup. Thumbnail deletion must not affect originals.
9. With maximum Dynamic Type and VoiceOver, create/edit a route, reorder pitches without dragging, open an attachment, read a source, export, and navigate restore confirmation. No essential control is clipped or unlabeled.
10. A supplied/shared URL makes no request until Copy Page/Open is tapped. Copy a public test page's text and selected image through preview/review, preserve source/final URL and capture time, save, then view both in Airplane Mode. The uncopied source link remains visibly external, not offline content. A blocked/unavailable source offers link-only/paste/file fallback without bypassing restrictions. Missing originals prevent a misleading complete-local-content indication.
11. Exercise the agreed large-library envelope with measured memory/progress/cancellation on the minimum device. Proposed targets: warm route list/search under 500 ms for 2,000 routes and route detail interactive under 1 second excluding original decode; adjust only through a recorded owner review after measurement.

Post-v1 OCR acceptance: representative permitted images/PDFs yield editable candidates, ambiguity is visible, raw OCR remains available on parsing failure, and nothing is committed or overwritten without confirmation. This does not block v1.

## 14. Milestones, Dependencies, and Estimates

Estimates are focused contributor effort for the confirmed single volunteer, not elapsed calendar promises. At an illustrative 10 hours/week, 300-475 hours is approximately 30-48 weeks before contingency; with 20-30% contingency, allow roughly 9-15 months. Weekly availability is not specified, so do not treat that calendar range as a commitment. The existing MBP is the local build/device-testing environment; VS Code can be the editor, but Xcode, its command-line tools, and simulator runtimes are still required for native builds, signing, previews, and device debugging. No parallel team capacity is assumed.

| Milestone | Dependencies | Deliverables and exit criteria | Estimate |
| --- | --- | --- | --- |
| M0: Decisions/governance | Approved plan | Record approved scope/target/limits, dependency exceptions and public single-developer GitHub workflow; identify release-only license/signing decisions without blocking simulator foundation | 10-15 h |
| M1: Integrity foundation | M0 | Single Xcode project; versioned persistence; app/extension identifiers; on-disk migration/reopen, generation switch, ZIP64/limits evidence; CI build/unit/smoke proof; sample area/route survives relaunch. Unresolved research gates dependent features, not unrelated MVP delivery | 40-60 h |
| M2: Core notebook | M1 accepted | Library/search, route/notes/pitches/edit drafts, revisions and save state, accessible reorder; five-pitch offline text scenario passes | 50-75 h |
| M3: Media and recovery | M1 contracts; M2 model | Originals/thumbnails/PDF viewer, safe deletion, DTO backup, archive validator, full replace recovery; byte-identical round trip and injected restore failures pass | 70-110 h |
| M4: Intake/share/URL review | M1 mailbox and URL policy spike; M2/M3 | Picker/paste/share intake, explicit one-page URL text/selected-image copy, App Group ready inbox, manual draft review/provenance, idempotent commit; host/URL matrix and interruption tests pass | 75-120 h |
| M5: Reliability beta | M2-M4 | Migration/corruption/large-library/offline/accessibility and minimum-device evidence; applicable v1 acceptance cases pass, no known critical data-loss bug; exhaustive pre-major-release checks under §21.6.8, no coverage gate | 35-60 h |
| M6: Community release | M5; owner distribution decisions | Complete docs/privacy/license/support URLs, TestFlight feedback, manifest attribution, App Store review checklist, reproducible release archive | 20-35 h |

Owner-approved sequencing exception (2026-10-28): the disposable native notebook prototype in §21.4.4 may precede M1 acceptance. Archive/replace-restore/URL-copy capability gaps gate those features, not this prototype. This exception does not declare M1 complete or authorize durable M2 product implementation; durable notebook work follows a reviewed ordinary save/relaunch packet. All release integrity requirements remain in force.

Total: **300-475 hours**, plus 20-30% contingency for platform defects, URL-copy behavior, volunteer availability, and App Review. Dependencies, not estimates, are release gates. If schedule must shrink, reconsider scope with the owner; do not silently drop required share/URL intake, backup, or accessibility. OCR is already deferred and receives a separate estimate after v1, provisionally 50-90 hours for Vision, parsing, review, and fixtures.

## 15. Prioritized Implementation Backlog

Each row can become a GitHub issue in the confirmed GitHub repository. GitHub pull requests and Actions checks are the delivery workflow; no GitLab mirror or pipeline is required. Acceptance references sections 7-13.

| ID | Priority / phase | Issue and acceptance | Depends on |
| --- | --- | --- | --- |
| CF-01 | P0 / M0 | Approve scope, iOS baseline, exception decisions and contributor availability; record decisions | Plan review |
| CF-02 | P0 / M0 | Choose license/release owner and register bundle/App Group identities without credentials in repo | CF-01 |
| CF-03 | P0 / M1 | Establish Xcode targets, shared scheme, secret exclusions, attribution and versioned model | CF-01/02 |
| CF-04 | P0 / M1 | Prove SwiftData migration, explicit save/reopen, context teardown and generation recovery on disk | CF-03 |
| CF-05 | P0 / M1 | Prove standard ZIP streaming, ZIP64, bounded entry inspection, cancellation, and interoperable extraction | Approved ZIP policy; CF-03 |
| CF-06 | P0 / M1 | GitHub Actions standard hosted macOS build/unit/smoke checks, manual extended suites and bounded storage under §21.6.8; no percentage gate | Confirmed public GitHub repository, CF-03; status in Kanban |
| CF-07 | P0 / M2 | Implement area/route validation, edits, route moves, blocked nonempty-area deletion | CF-04 |
| CF-08 | P0 / M2 | Implement route workspace and explicit Save/Cancel, recoverable error/revision behavior | CF-07 |
| CF-09 | P0 / M2 | Implement pitch CRUD and accessible atomic reorder; five-pitch test passes | CF-08 |
| CF-10 | P0 / M2 | Implement common/custom sections and field-origin display semantics | CF-08 |
| CF-11 | P0 / M2 | Implement paged local name search and truthful saved/local indicators | CF-07/08 |
| CF-12 | P0 / M3 | Implement staged original store, hashes/journal and startup reconciliation | CF-04 |
| CF-13 | P0 / M3 | Implement image/PDF views, captions/tags/targets, bounded previews | CF-12 |
| CF-14 | P0 / M3 | Implement reference-safe delete/reclamation, source/draft reference checks | CF-12/13 |
| CF-15 | P0 / M3 | Specify archive DTOs/schema examples and export immutable snapshot with media pins | CF-05/12 |
| CF-16 | P0 / M3 | Validate hostile/corrupt/versioned backups with no active-library writes | CF-15 |
| CF-17 | P0 / M3 | Implement staged replace/rollback/revert and every-phase interruption tests | CF-04/16 |
| CF-18 | P0 / M4 | Implement supported Files/Photos/paste intake and raw source retention | CF-12/13 |
| CF-19 | P0 / M4 | Implement receiving share extension, atomic mailbox and no-loss receipts | CF-02/18 |
| CF-20 | P0 / M4 | Implement manual import review/destination mapping and idempotent commit, no OCR | CF-08/10/18/19 |
| CF-20A | P0 / M1-M4 | Prove isolated URL preview policies, implement explicit page text/selected-image/PDF copying with provenance, no automatic fetch/crawl, and unsafe/blocked/offline-source fallbacks | CF-12/18/20; URL policy spike |
| CF-21 | P0 / M4 | Include drafts/inbox boundary in complete export and test restore with pending shares | CF-15/17/20 |
| CF-22 | P0 / M5 | Execute offline, protection/permissions, URL-copy, oldest-device and large-library matrix | CF-07 through CF-21 including CF-20A |
| CF-23 | P0 / M5 | Complete accessibility audit and core-flow XCUITests, remediate failures | CF-09/13/20 |
| CF-24 | P0 / M6 | Write final setup/backup/privacy/contribution/release docs, support ownership and license notices | CF-02/22/23 |
| CF-25 | P0 / M6 | Conduct TestFlight beta and App Store submission review with accepted SDK and no new recurring service | CF-06/24 |
| CF-26 | P1 / later | Plan and add on-device OCR with bounded PDF rasterization and raw-text recovery | Stable v1 |
| CF-27 | P1 / later | Add explainable parser candidates and uncertainty review, never silent replacement | CF-26 |
| CF-28 | P1 / later | Evaluate grade/style filters, favorites and camera against real user feedback | Stable v1 |
| CF-29 | P2 / separate plan | Assess CloudKit identity, schema/asset migration, deletion/conflicts and costs; no implementation commitment | Stable portable backups |

## 16. Policy, Costs, CI, and Distribution

### 16.1 Applicable Standards and Exceptions

The owner approved a native local app instead of a service. Do not add Go, PostgreSQL, OIDC, Docker, HTTP endpoints or API docs merely to satisfy unrelated service defaults. Apply secret protection, unit coverage, provenance, documentation, manifest attribution, and explicit review gates.

**Dependency direction, approved with the plan:** use ZIPFoundation [S11], a free MIT-licensed Swift library, through Swift Package Manager. Select a reviewed stable release rather than a moving development branch; commit the Xcode project's shared Package.resolved and make CI honor that resolution without silently updating it. The owner approved the plan after receiving this recommendation, including its narrow exceptions permitting native Xcode/SPM resolution on the MBP and GitHub macOS runners and reproducible dependency versions/lockfiles for this app. Docker cannot supply the native iOS SDK build environment. These exceptions do not authorize unrelated dependency installations.

Rationale: portable backup is a launch-critical data recovery feature; a mature ZIP implementation is less maintenance and risk for one volunteer than implementing ZIP parsing. Reproducible dependency resolution makes failures and shipped versions traceable. Pinning is not a substitute for patching: review stable/security updates at least monthly and before releases, update via a dedicated pull request, and run archive corruption, ZIP64, cancellation and round-trip tests before merging. Record the resolved revision/license in release evidence. Keep the dependency out of the share extension unless needed. If the exception is declined, revisit a no-dependency document-package format instead of hand-writing a general ZIP parser. Foundation's ZIP upload snapshot [S12] alone does not solve bounded hostile ZIP restore.

**CI decision, approved:** GitHub Free replaces GitLab and its `shared` runner tag. Use `.github/workflows/ios-ci.yml` on pull requests and pushes to main with standard GitHub-hosted macOS runners. Do not set up GitLab or install a persistent runner on the personal MBP.

**Confirmed repository posture:** the owner reports the GitHub branch/repository is public. Verify current repository metadata before relying on it; the requested repository slug is `climbing-notebook`, not a verified remote destination. Standard hosted runners, including macOS, are free for public repositories [S13-S14], subject to platform usage limits. No paid/larger runner is permitted. Audit generated changes for secrets/content before any separately authorized publication. Do not change repository visibility.

Private-repository allowances are not the selected CI model. If live metadata contradicts the owner's public-repository report, stop the hosted-CI assumption and report the discrepancy; do not change visibility or billing. Public free runner time does not authorize larger runners, excessive artifact/cache usage, or paid storage. Keep artifacts short-lived and bounded. A prepared workflow is not an executed CI result: until separately authorized changes are published, validate locally and report hosted execution as not yet run.

### 16.2 Cost and Ownership Budget

| Item | Planned recurring cost | Caveat |
| --- | --- | --- |
| Backend/database/OCR/AI/sync | $0 | None used; OCR later stays on device |
| Apple membership | Already provided by owner | Confirm team access, signing, extension/App Group ownership and release continuity |
| Build/test hardware | No new recurring spend | Existing MBP confirmed; verify Xcode compatibility, storage and test-device access |
| CI hosting | $0 additional | Standard macOS Actions runners free for public repo; private repo limited to included allowance, with paid usage blocked |
| Repository/docs/privacy/support page | Free existing hosting | Static repository pages are acceptable if available; no custom domain/server required |
| ZIP dependency | $0 license fee | License notice and maintenance/security work; narrow resolution policy exception approved |
| User backups | No app charge | User-selected cloud provider/device storage may have independent limits/costs; local Files/computer backup remains an option |

CI builds and runs meaningful unit tests plus short UI smoke on pushes/PRs under §21.6.8, with manual extended suites. Coverage is optional information, never a threshold. Use standard hosted macOS and a verified toolchain, cancel superseded runs and bound duration/storage. The workflow owns current job layout and retention values; do not duplicate them here. Never upload personal library data or full large-library fixtures. Run affected extended/device checks and exhaustive pre-major-release qualification as warranted.

Use read-only workflow permissions, no signing secrets, and simulator signing-free builds. Test untrusted contributions with the pull_request event, never pull_request_target executing contributed code with privileges. Use GitHub-hosted ephemeral runners rather than exposing the MBP to public-fork code. Use immutable commit-SHA references for third-party Actions, with reviewed updates, under the approved reproducibility/security exception; verify their real upstream revisions rather than inventing SHAs. Signed distribution remains a deliberate local Xcode operation by the owner; automatic App Store publishing is not required. Document recommended required checks where supported, but changing GitHub repository protection/settings requires separate authorization.

README requirements adapt to a native app: overview, architecture, prerequisites/Xcode, local build and test instructions, document/service contracts instead of HTTP reference, privacy/data storage, environment/signing variables if any, deployment/distribution, and contributing. Explain that Docker commands and service endpoints are intentionally not applicable.

App Store release requires a maintainable signing/release owner, support and privacy URLs, app name availability, icon/screenshots, truthful offline/privacy descriptions, age-rating answers, export-compliance answers for actual cryptography, and tested restore on the release build. Recheck current SDK/review/privacy rules at release rather than treating this plan's dated research as permanent.

## 17. Risk Register

| Risk | Impact / likelihood | Mitigation and release gate |
| --- | --- | --- |
| Database/file split commits lose attachments | Critical / medium | File-first publication, journals, reachability sweeper and fault injection |
| Replace restore destroys current library | Critical / medium | Validate first, separate generation, atomic descriptor, reopen/rollback and interruption matrix |
| SwiftData teardown/migration unsuitable | High / medium | M1 empirical gate; Core Data fallback decision before UI investment |
| Share extension killed or acknowledges incomplete payload | High / high | Stream and atomically publish ready envelope, tight limits, truthful Inbox acknowledgement, host-device tests |
| Archive traversal/expansion exploits | Critical / medium | Generated paths, bounded per-entry streaming, strict whitelist, negative fixtures, library review |
| User thinks saved link/photo reference is offline content | High / medium | Copy originals locally before saved state; separate external-source and missing-file statuses |
| User mistakes imported beta for verified safety information | High / medium | Visible lineage and notebook positioning; no accuracy/current-condition claims |
| Copyright/terms violation | High / medium | Explicit one-page user action rather than crawling; disclose that initiation does not settle permission; no bundled third-party beta; review site-specific support claims/adapters before release |
| URL preview contacts trackers or hostile content | High / medium | Explicit network disclosure, nonpersistent isolated WebKit, no privileged bridge, enforceable destination/resource controls, inert saved output, safe fallbacks |
| Hosted runtime unavailable or artifact use exceeds free limits | High / medium | Public standard hosted macOS only; bound jobs/storage, local MBP baseline tests, explicit unavailable-check reporting, no paid fallback |
| Dependency/action becomes vulnerable or update regresses recovery | High / medium | Approved reviewed stable resolution/lockfile and immutable Action references; monthly/security updates, archive regression tests and release revision evidence |
| Device loss before external export | Critical / medium | Launch backup core, clear reminders and OS-backup limitations; test clean-install recovery |
| Disk-full/large-image memory termination | High / high | Preflight and enforced resource budgets, streaming/downsampling, oldest-device tests |
| Volunteer/App Store owner disappears | High / medium | Document signing/release/support ownership, backup maintainer, portable source/data and reproducible instructions |
| CloudKit later requires major schema changes | Medium / high | Explicitly defer, stable IDs and portable schema; no claim of drop-in sync |
| Sensitive EXIF/prose leaked through backup | High / medium | No app uploads, explicit readable-backup warnings and safe temporary-file cleanup |

## 18. Open Owner Decisions

### Implementation Decisions Resolved

1. **Approved:** iOS 17.5 minimum; use affected/manual minimum-support checks under §21.6.8. Further floor changes require owner approval, not inference from historical iOS 17.0 results.
2. **Confirmed:** one volunteer developer, existing MBP, VS Code and GitHub. OCR remains postponed; manual intake/review is v1 scope. Weekly hours remain unspecified; calendar estimates are illustrative.
3. **Approved with the plan:** ZIPFoundation via native Swift Package Manager, reviewed stable-release resolution, committed Package.resolved, and deliberate tested updates. Narrow local/hosted-macOS dependency and reproducibility exceptions apply; so do immutable third-party Action references. No blanket dependency-policy waiver.
4. **Confirmed:** public GitHub repository on GitHub Free, not GitLab. Use standard hosted macOS GitHub Actions with bounded artifacts/cache. Do not change visibility, billing or repository settings without authorization.
5. **Approved:** proposed intake/archive/library limits and generation-based replace/revert behavior, with measurement/fault-injection verification as specified.

The owner subsequently stated, `Plan is approved. GitHub branch has been published as public.` That resolves implementation authorization and item 3. Do not treat this instruction document as permission to commit, push or publish.

### Before Public Release

6. Permanent registration of bundle/UTType/App Group identities, final display branding, and App Store seller attribution placement. Development identifiers rooted at `com.climbingnotebook.foundation` remain provisional; future marketing names should not drive technical-identifier changes.
7. MIT is selected as the starting code license. Confirm copyright ownership and finalize license text/notices, contributor agreement/DCO if desired, issue/code review governance, and backup maintainer. The earlier GPLv3-only versus GPLv3-or-later question no longer applies.
8. Leif Johnson is the confirmed signing/release/support/privacy owner. Confirm Apple team authority, review cadence and long-term membership continuity. Build support/privacy pages on owner-controlled leifdigital.com; final page URLs are not yet selected or live.
9. Retention until explicit deletion is confirmed, with no automatic expiry of ready deliveries or saved drafts. Validate the detailed retention UX and user-visible warnings before release.
10. English-first UI with Unicode content and iPhone-primary/minimal-iPad scope are confirmed. No inferred map/location/grade-system requirements.

Generic user-initiated URL copying is included in v1 per owner direction. Site-tailored automation/support claims, sync, nested areas, merge restore, and OCR need separate review later. User initiation changes the interaction boundary, not the site's license or technical access controls.

## 19. Research References and Confidence

Consulted 2026-10-27. Official framework availability and dated submission rules are evidence; architecture recommendations are engineering judgments. Search snippets can be stale or describe future requirements, so the dated April 2026 notice below was checked directly. Revalidate all live requirements before implementation/release.

| Ref | Source | What it supports / limitations |
| --- | --- | --- |
| S1 | [Apple ModelContainer](https://developer.apple.com/documentation/swiftdata/modelcontainer.md) | iOS 17 availability, explicit configuration, migration plan, main context. Does not prove app-specific recovery safety. |
| S2 | [Apple VersionedSchema](https://developer.apple.com/documentation/swiftdata/versionedschema) and [migration discussion](https://developer.apple.com/videos/play/wwdc2025/291/) | Versioned schema/migration support. Newer features must not leak into minimum-target code. |
| S3 | [Apple App Groups](https://developer.apple.com/documentation/xcode/configuring-app-groups.md) | Registered shared containers for app/extension. Does not provide automatic transactions. |
| S4 | [Apple extension common scenarios](https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/ExtensionScenarios.html), [lifecycle](https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/ExtensionOverview.html), [NSItemProvider](https://developer.apple.com/documentation/foundation/nsitemprovider) | Inbox architecture and provider lifetimes; archived guide is older guidance, current behavior requires device verification. |
| S5 | [Apple SDK requirements, April 28, 2026](https://developer.apple.com/news/upcoming-requirements/?id=04282026a), [Xcode requirements](https://developer.apple.com/xcode/system-requirements), [submission guidance](https://developer.apple.com/app-store/submitting/) | Build SDK requirement is distinct from app deployment target; future changes remain possible. |
| S6 | [Apple Archive](https://developer.apple.com/documentation/applearchive), [Apple ZIP/Compression explanation](https://developer.apple.com/forums/thread/694893) | Compression algorithms/Apple Archive do not by themselves implement interoperable ZIP restore. |
| S7 | [Mountain Project official Data API](https://www.mountainproject.com/data) | Public access deprecated; new requests declined. Direct page verified. |
| S8 | [Adventure Projects Terms of Use](https://www.adventureprojects.net/ap-terms) | Current retrieved page dated August 4, 2023; sections 3, 7, 8(g), and 12 constrain use. Not a legal authorization for Climbing Notebook. |
| S9 | [SuperTopo FAQ](https://www.supertopo.com/faq.html) | Search-indexed official material describes guides/eBooks. HTTPS terms retrieval failed; API and reuse permissions unverified. |
| S10 | [Apple privacy details](https://developer.apple.com/app-store/app-privacy-details), [SDK requirements](https://developer.apple.com/support/third-party-SDK-requirements) | Review privacy disclosures and actual SDK inventory before submission. |
| S11 | [ZIPFoundation project](https://github.com/weichsel/ZIPFoundation), [reviewed README](https://raw.githubusercontent.com/weichsel/ZIPFoundation/development/README.md) | Free MIT library, file/stream access, progress/cancellation; project claims are not proof of our security/ZIP64/performance requirements. |
| S12 | [Foundation forUploading](https://developer.apple.com/documentation/foundation/nsfilecoordinator/readingoptions/foruploading) | Directory snapshot can be ZIP; temporary URL lifetime matters. Not a complete safe restore API. |
| S13 | [GitHub Actions billing](https://docs.github.com/billing/concepts/product-billing/github-actions) | Standard hosted runners free for public repos; GitHub Free private-repo allowance currently 2,000 minutes/month, 500 MB artifact storage. Verify billing/account-specific consumption before use. |
| S14 | [GitHub-hosted runners reference](https://docs.github.com/actions/reference/runners/github-hosted-runners) | Standard macOS runner options for public/private repositories; image/runtime availability and usage policies still apply. |

## 20. Plan Review Exit

Plan approval is recorded; the original M0/M1 handoff is historical, not the next assignment. Use the current owner request and Kanban, within the applicable feature contract. Plan approval alone authorizes no commits, pushes, signing changes or publication.

## 21. Implementation Handoff

### 21.1 Assignment and Scope

**Historical handoffs, not active assignments.** Use [SYSTEM_DOCS](SYSTEM_DOCS.md), current [Kanban](docs/WIP_KANBAN.md), DESIGN and the assigned feature contract; §21.6.8 owns verification. Inspect actual source/environment, preserve user/agent changes, and do not reopen resolved decisions or paused research. No automatic Agent Manager session/worktree creation is authorized.

The complete pre-condensation §§21.1-21.5, including original packet designs, acceptance matrices and measurements not repeated in topic evidence, remain in the [saved Git baseline `dfc7ed7034ab437d3854381bef8d3708eec11664`](https://github.com/tljohnson/climbing-notebook/blob/dfc7ed7034ab437d3854381bef8d3708eec11664/ClimbingNotebook-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md#211-assignment-and-scope). Consult that historical source only for relevant provenance/detail; it does not restore superseded assignments, cadence or approval gates.

### 21.2 Permissions and Guardrails

- Follow the current native architecture/runtime floor (iOS 17.5), owner decisions and [.kilo/AGENTS.md](.kilo/AGENTS.md), not the original iOS 17 floor or unresolved-license wording. Swift/SwiftUI, one Xcode project, local persistence/files and no account/backend remain the scope; native SPM on macOS and committed resolution are approved. VS Code is preferred; Xcode supplies native build/test tools. No unrelated generators/package managers or dependency workarounds.
- No OCR, sync, nested areas, merge restore, weather/maps, paid services, analytics, LLM calls or automatic route-field extraction. URL copying remains explicit one-page user action, not reference-only or unattended crawling; its policy finding is in [Persistence](docs/verification/Persistence.md#url-policy-finding).
- Separate authorization is required for commits/pushes/PRs, publication, repository visibility/billing/protection changes, signing credentials, developer-portal registration and real-site scraping probes. Use signing-free simulator builds and clearly provisional identities. Preserve required third-party notices and unresolved release-ownership boundaries.
- Use synthetic/generated fixtures and permitted originals, not personal route libraries or copyrighted guidebooks. Report only actual toolchain/destination/results/provenance; never invent successful checks or saved/local acknowledgment. No placeholder success, disabled assertions, in-memory-only integrity proof, generic sync layer or permissive ZIP convenience fallback.
- A disproven foundation capability requires precise evidence and a bounded owner decision before dependent work: no silent Core Data switch, reduced backup guarantees/limits, removed URL-copy capability or weakened destination policy. Independent safe work may continue.

### 21.3 First Work Packet: Foundation, WIP Limit One

The original F0-F5 packet covered environment reconciliation, native scaffolding, persistence/generation, ZIP/ZIP64, URL-policy feasibility and CI. It is not a request to rebuild scaffolding, recreate CF issues or repeat research. The [WIP archive](docs/WIP_KANBAN_ARCHIVE_2026-11-05.md) records disposition; [Persistence](docs/verification/Persistence.md) and [Archives](docs/verification/Archives.md) retain findings and reproduction.

Feasibility never authorized full restore or production URL import. Keep diagnostic generations isolated; missing/corrupt stores must not become empty-library success, and an open database file is not a movable backup. Real >4 GiB measurements cannot be replaced by tiny fixtures. Harness-only loopback and top-level WebKit checks do not prove public-destination/subresource/DNS safety. Local results do not prove hosted CI execution; preserve read-only CI permissions, verified Action references and bounded free-runner use.

### 21.4 M1 Definition of Done and Return Format

Historical M1 remains incomplete, not the current delivery gate. [Archives](docs/verification/Archives.md) preserves CF-05A/CF-05B exact boundaries, hostile/crash counterexamples and unresolved production acceptance; [Persistence](docs/verification/Persistence.md) preserves CF-04A recovery and CF-04B migration/lifetime failures. Stored host fixtures prove >4 GiB archive/offset boundaries; deflated fixtures prove only the uncompressed-entry boundary. Neither visible entries/symlink rejection nor ordinary save/reopen establishes whole-archive, migration or restore safety.

Keep every migration assertion and diagnostic store: a failed lifetime barrier forbids unsafe copy/move/delete, and scope exit or weak-reference release is not SQLite closure proof. Closed-generation snapshot, independent migrated reopen/recovery/retry, actual termination/power-loss/fsync and released-schema compatibility remain unproven. Sequential-process diagnostics and a Core Data fallback were not implemented or authorized. These findings do not establish ordinary-save data loss.

The former milestone return template, coverage thresholds and qualification cadence are retired. Use §21.6.8 and existing topic evidence; distinguish implemented behavior, failed/unrun dependent gates and release limits without manufactured passes or renewed research assignments.

#### 21.4.1 CF-05C Preflight Design and CF-05D Test-Only Spike

**Historical approval (2026-10-28):** the owner authorized CF-05D's bounded test-target structural-preflight spike, not a production parser/validator, fork or dependency change. [Archives](docs/verification/Archives.md#structural-probe-limits) retains the probe, hostile/valid controls, compressed-suffix counterexample and measured limits; the §21.1 baseline retains earlier per-packet totals. Research remains paused, not accepted.

Security-sensitive preflight requires explicit owner approval, separate review and demonstrated capability before production use. Its output is structural metadata only, never extraction/restore permission. Preserve bounded random-access reads, checked UInt64 ranges/conversions and preallocation/metadata budgets; no whole-file loading, partial success, cached-package edits, reflection or private API bypass.

Complete inspection must reconcile one unambiguous EOCD/ZIP64 interpretation, full directory extent/count, every local reference/span, raw headers, framed extras and descriptors; reject hidden tails, duplicate references, overlaps, encryption, malformed required ZIP64 fields and unresolved ambiguity. Bind returned entries by inspected ordinal/effective metadata, not visible path. Valid local placeholders, signed/unsigned descriptors, stored/deflate/UTF-8 and independent producer controls must remain supported. Optional records, prefixes/gaps, unknown extras and general link semantics require explicit compatibility review; no blanket extra rejection, descriptor ban, research cap or reject-all shortcut becomes the product format.

Unreconciled library metadata or missing consumed-input evidence stops dependent extraction; no arbitrary-offset extraction/new decoder workaround. Structural success does not replace §§9.1-9.4 namespace/collision, manifest/foreign-key/type, streaming inflated-byte, CRC/SHA-256 and resource checks. Closed synthetic test input does not prove provider ownership: production needs reviewed immutable/coordinated staging bound across inspection/extraction; hash-before/after, pathname or modification time alone is insufficient. Device/full-envelope/cancellation/disk-failure evidence remains feature-specific and unproven.

#### 21.4.2 CF-05E Strict Extraction Boundary Review

CF-05E reviewed CF-05D `39c3829` without authorizing a fork, second decoder, new dependency, production linkage or format restriction. [Archives](docs/verification/Archives.md#decisive-counterexamples) retains ZIP64 offset-zero/descriptor mismatches and proof that completed progress/provider read-ahead cannot distinguish valid input from trailing or concatenated streams. Encoded metadata accounting is not heap/RSS control; the 64-field cap is research-only.

The design-only strict result must bind inspected record/input identity and report declared, supplied, consumed and inflated UInt64 counts, CRC and explicit completion. Require exact inspected-span consumption plus DEFLATE END, expected size/CRC and checked arithmetic; stored entries require exact bounded-span/equal-size completion, not a DEFLATE marker. Preserve legal final-byte padding bits while rejecting extra complete bytes. Errors, truncation, stalls, overflow, cancellation and consumer failures throw without partial success; output stays unpublished and is discarded on failure.

Before production adoption, separately reviewed executable evidence must cover empty/valid/truncated streams, zero/nonzero suffixes/concatenation, buffer boundaries/chunk sizes/zero-output steps, ordinary/ZIP64 descriptors, size/CRC/limit/I/O failures and >4 GiB counters on each supported backend. Progress, reduced buffers, hashes or a second permissive pass cannot supply the missing guarantee. No proposed strict interface is claimed implemented; coordination, complete inspection, output ownership and manifest/type acceptance remain separate gates.

#### 21.4.3 CF-05F Implementation Choice: Bounded Candidate Approved

**Historical approval (2026-10-28), subsequently paused:** the owner approved only a local test-only ZIPFoundation candidate from fixed 0.9.20 revision `22787ffb59de99e5dc1fbfe80b19c97a904ad48d`, existing-decoder plumbing/ZIP64 changes and isolated host/unit/simulator integration. No candidate is implemented or retained; no automatic CF-05G restart. [Archives](docs/verification/Archives.md) owns source findings; the §21.1 saved baseline preserves the exact proposed API/source delta, acceptance matrix and budget estimates.

Leif is the sole human maintainer/developer, accountable for security triage, upstream updates and adoption. Separate agent-assisted review must remain distinct from implementation, with limits reported before owner acceptance; it is not an independent human security audit. No additional human reviewer was required to begin local feasibility. Approval grants no second decoder/backend, complete parser expansion, production linkage/validation, remote adoption, publication, commits or M2.

Retain these candidate/adoption constraints:

- The proposed consumer-only strict API preserves the legacy CRC-only API's source compatibility but never falls back to it after strict failure. No skip-CRC, destination extraction or partial-success report. Library-created archive-session/record ordinal/offset identity and reconciled raw metadata bind expectations before consumer calls; wrong archive/record/span fails, including same-name records. App duplicate policy remains separate; identity does not freeze mutable input.
- For declared payload `D`, supplied bytes `S`, residual input `R`, consumed bytes `C` and inflated bytes `I`, prove checked `C = S - R`, `0 <= C <= S <= D`, END, `C == D`, expected `I`/CRC and no cancellation/error. Headers/descriptors are outside `D`; unread and buffered suffixes both count as trailing input. Verify Apple END/`src_size` and alternate zlib END/`avail_in` independently, including internal buffering; inability to distinguish suffixes stops adoption, not authorizes a backend swap. Preserve legal final-byte padding, without zero-bit/canonicalization requirements; never restart after END.
- Stored entries require exact bounded reads, `compressed == inflated == D` and stored completion, including empty/CRC-zero files. Checked offsets/conversions, bounded buffers and pre-delivery inflated limits apply. Accumulate positive short reads; premature EOF, zero/overlong reads, I/O, overflow, no END or stalled processing throws. Zero-output consumption is valid progress; refill a no-progress step only with empty input and declared bytes remaining. Poll cancellation through reads/processing/delivery/final success, including empty entries; release resources on every error. Output remains untrusted staging until success.
- ZIP64 presence is distinct from zero, including serialization/add/remove behavior. Required sentinel fields follow APPNOTE order; missing/malformed/duplicate data cannot fall back. Reconcile local/central evidence and legitimate bit-3 placeholders once for public metadata, payload and exact signed/unsigned descriptor spans, including small/empty/local-only ZIP64. Offset-only fields or version alone do not justify a width heuristic; CRC `0x08074b50` is not automatically a signature. Contradictory/ambiguous interpretation stops acceptance, not bans a producer layout.
- The bounded strict API accepts regular-file payloads only; reported directories/symlinks throw before consumer delivery, never legacy empty/raw-byte shortcuts. This is not exhaustive hard-link detection or a newly approved archive restriction. Complete inspection, optional/gap/prefix/extra/nonseekable-layout compatibility, heap/RSS/full envelope, immutable staging and app manifest/type/hash/resource policy remain separate production gates under §§9.1-9.4 and §21.4.1. No metadata repair, hidden-record skip or manifest-count substitute.
- Preserve MIT/notices, exact base SHA, reviewed patch/source-tree digest, backend/module/dependency identity and baseline gap assertions. The approved evaluation copy is `Vendor/ZIPFoundationStrictCandidate/`, never an edited SPM cache; host/unit and explicitly reviewed test-only simulator linkage stay isolated from app/share targets and unchanged baseline probes. No moving-branch resolution or invented provenance. Remote URL/immutable commit/`Package.resolved` adoption requires a further owner decision, patch ledger, rollback plan, review limitations and applicable regression evidence at that revision.
- Review security/upstream changes monthly and before release; budget at least half a day monthly plus release-day regression/rebase work, with advisory/backend work additional. Record applicability/rebase decisions and rerun affected acceptance on updates. Do not automatically pull development or transfer accountability on upstream merge. Retirement to an independently qualifying immutable upstream revision still requires owner review; insufficient maintenance/review capacity stops adoption.

Future explicitly reprioritized validation must preserve valid controls and baseline provenance, test suffix/truncation/identity/type/descriptor/I/O/limit/cancellation/counter failures and serializer compatibility, and independently measure supported backends and real large boundaries. Changed archive/shared-harness/dependency code warrants free-space preflight and owned scratch cleanup; report unavailable backend/device/full-envelope checks as unproven. Scope growth, format narrowing, hidden enumeration, interoperability failure or unsafe counters require a bounded owner decision, not permissive acceptance. §21.6.8 governs cadence, without resurrecting historical coverage gates.

#### 21.4.4 Owner-Approved Prototype-First Reset

**Owner decision (2026-10-28):** pause fork/archive research and permit a disposable synthetic notebook before full M1 acceptance. This supersedes earlier next-packet sequencing, not safeguards/evidence. CF-05G requires explicit reprioritization; Review research is not automatically Done. Timebox any approved resumed feasibility investigation to half a day/one day with a decision/evidence target, then report and replan rather than generate another prerequisite.

CF-07A's transient library/area/route/five-pitch notes/reorder flow was accepted on 2026-10-29 (`4591da1`). It used stable identities, read-only browsing and separate explicit editors, with truthful reset-on-relaunch disclosure; it did not save durable data or connect diagnostic stores. The reported notes mismatch was navigation-versus-reorder confusion, not corruption, and is closed. Later approved durable/notebook contracts supersede its transient restrictions; do not restore its old labels/notices.

[NotebookPrototype](docs/verification/NotebookPrototype.md) and the [WIP archive](docs/WIP_KANBAN_ARCHIVE_2026-11-05.md) retain results/acceptance and limits. Prototype acceptance did not complete M1, accept valuable data, establish migration/restore/URL-copy safety or authorize a framework switch, unsafe fallback, release reduction or publication. Those unresolved capabilities gate dependent features, not unrelated UI work.

#### 21.4.5 CF-07B Approved Ordinary Durable Save/Relaunch Slice

**Historical approval (2026-10-29):** Leif approved only synthetic fixture route notes, pitch notes and whole sibling pitch order, with explicit saves, isolated storage and retained incomplete initialization without repair UI. CF-07B was superseded by CF-07E; the [WIP archive](docs/WIP_KANBAN_ARCHIVE_2026-11-05.md) requests no separate acceptance or further qualification. [NotebookPrototype](docs/verification/NotebookPrototype.md#decisive-evidence) and [Persistence](docs/verification/Persistence.md#ordinary-fixture-store) retain exact results, warnings and limits; full suites were not green.

Retained-format constraints remain: `NotebookSchemaV1` version `1.0.0` contains Area, Route, Pitch, NoteSection and FixtureState with deterministic UUIDs, explicit inverses and complete ownership validation. Preserve Example Granite/Meadow, Paper Skyline's exact five-pitch set, Unwritten Line, immutable fixture metadata and one General section per route; note bytes, revisions and saved pitch order are content, not seed defaults. This is not `LibrarySchemaV1`, a released diagnostic predecessor or the final notebook schema. Views use plain snapshots, not live models; exact-text/no-op detection compares UTF-8 bytes.

`NotebookStore` owns only app-private `Application Support/NotebookFixtureSlice/Libraries/<fixed-slice-UUID>/notebook.store` and sidecars. No diagnostic-root adoption, generation-manager/replacement journal, live-store copy, implicit move or cleanup. Autosave/CloudKit stay disabled; normal OS backup is not disabled, and owned files follow `completeUntilFirstUserAuthentication`, without claiming physical-device verification. Initialize exclusively only when the slice root is genuinely absent, saving the full graph/marker together and validating before presentation. Existing empty/unrecognized/incomplete roots, missing main store/marker, corruption or invalid graphs fail closed with retained files/Retry, never create/reset/reseed/repair or empty-library success. Only the same verified newly owned initialization session may retry its transaction; relaunch cannot treat incomplete initialization as first launch.

The three commands validate UUID ownership, expected route revision, 1 MiB UTF-8 prose limits and exact whole-sibling permutations before saving; changed commands increment revision once, no-ops invent no save event. Prepare acknowledged snapshots before commit, return only after success, retain failed/conflicting buffers and never overwrite newer revisions automatically. Insert before relationship assignment where required; process pending changes/rollback and replace only the context on the same container after failure. That is not container teardown. §21.6/DESIGN own current Save/Cancel presentation and failure semantics, not old Finish Editing/Done labels or routine notices.

Retain on-disk exact-byte/identity/order/bootstrap/fault assertions and actual process terminate/relaunch coverage; container recreation is not process-relaunch proof and injected failure is not actual ENOSPC. Fault controls use debug assertions/internal injection and generated UUID test namespaces, never arbitrary paths, ordinary-store resets or diagnostic stores; reuse each test's token across relaunch. No unsafe deletion based on assumed teardown. Future full-library/schema adoption or destructive recovery needs reviewed compatibility/recovery approval; ordinary save evidence does not establish migration, backup, real full-disk/power-loss durability or valuable-data safety.

#### 21.4.6 CF-07C Approved Bounded Reading and Navigation Alignment

**Historical approval/acceptance:** the owner approved the bounded reading/navigation packet on 2026-10-30 and accepted human testing in the 2026-10-31 handoff (`423685d`, following CF-07B `3b5e4e7`). No renewed review is requested. [NotebookPrototype](docs/verification/NotebookPrototype.md#cf-07c-reading-and-navigation) retains exact failed full-suite/targeted revalidation results and unmeasured limits; acceptance did not separately accept CF-07B, complete M1 or infer device/VoiceOver/dark-mode passes.

Scope was full General reading, discoverable pitch access, adjacent navigation outside long notes and contextual editors, without API/schema/store/fixture/dependency changes. Preserve stable selection, all five pitches, empty/no-pitch cases and separate note/order editors; reading never mutates notes, order, revisions or acknowledgments. It did not authorize generalized creation, new sections from combined General prose, unavailable destinations or weakened fixture validation. DESIGN and §21.6 now own composition/Save labels; the old autosave-later and permanent-notice wording is superseded. Layout references are not executable specifications or permission to change data/save contracts.

### 21.5 Later Implementation Packets

The original L2-L6 sequence grouped core notebook, media/recovery, intake/share/URL, reliability and release preparation; it is historical, not automatic authorization. [WIP archive](docs/WIP_KANBAN_ARCHIVE_2026-11-05.md) records CF-07B/CF-07D as superseded by CF-07E without separate acceptance/further qualification. Old cadence, coverage, review cycles, UI labels and pending-status wording are not current contracts.

Use the current assignment and approved feature boundary, DESIGN for presentation, §21.6 for notebook operations and §21.6.8 for checks. This history grants no new export work (§21.7 remains deferred), monitoring schedules, sessions/worktrees, spending, signing, TestFlight/App Store submission or publication authority. Future recovery/intake/release work retains its applicable compatibility, ownership and safety gates.

#### 21.5.1 CF-07D Approved First Core Notebook Creation Slice

**Historical approval/disposition (2026-10-31):** the owner approved name-only route creation in either existing fixture area, then ended verification and directed recording results/moving on. Implementation/tests remain; CF-07D was not accepted and was later superseded by CF-07E with no separate qualification requested. [NotebookPrototype](docs/verification/NotebookPrototype.md#cf-07d-current-results) preserves exact completed, failed, interrupted/unrun checks; [Persistence](docs/verification/Persistence.md#cf-07d-creation-boundary) preserves storage conclusions. Do not recreate cards, resume batches or infer acceptance from this former handoff.

This additive exception to CF-07B's fixed-route-only restriction preserves `NotebookSchemaV1.swift` byte-for-byte (version `1.0.0`), all properties/relationships, marker `CF-07B-1`, namespace/path/slice UUID and ModelContainer configuration. Open the same store in place, not a parallel store, diagnostic adoption, copy/export, migration or version bump. Older fixture-only binaries reject added routes; downgrade is not supported compatibility and must never trigger reset. Future complete-library adoption requires reviewed migration/recovery planning. Stop for approval if unchanged-format opening/preservation cannot be demonstrated, rather than inventing a migration or restarting CF-04B.

Retained additive-format/command constraints:

- UUID-valued snapshots/commands/selection retain existing deterministic fixture identities; names, aliases and row positions are never persistence identity. Allocate route/General UUIDs once per draft and retain them through failure/Retry. New routes have exact authored names (nonblank after whitespace/newline emptiness testing, at most 500 Swift Characters, no trimming/normalization), blank grade/style, revision 0, one empty General and zero pitches. Duplicate names, including fixture names, are valid. General remains bounded to 1 MiB UTF-8; no metadata inference, area/pitch creation or broader product graph is authorized by this exception.
- Validate the entire fetched graph, inputs and target area; insert before linking, stage/validate/prepare the snapshot, then save route/note/relationship atomically. Publish exactly one UUID-keyed route only after acknowledgment, never via name lookup or a fallible post-commit fetch. Reject equal draft IDs and reserved fixture/marker IDs before retry matching, including pristine Unwritten Line. Only an exact unedited nonfixture pair (same owner/name bytes/blank metadata/revision-zero/empty General/zero pitches) may return idempotently without another save; partial/cross-entity/foreign/differing/edited collisions conflict, never upsert or allocate replacement IDs. Retain failed draft/name/IDs and acknowledged counts; rollback/replacement affects only the context on the same container.
- Keep exact marker, two area IDs/names and required fixture route/note/pitch IDs, immutable metadata and owners. Preserve existing note UTF-8 bytes, revisions and nondefault saved five-pitch order, never compare them with seed prose/order. Additional routes are allowed only in existing areas, with bounded nonblank names, blank metadata, nonnegative revisions, zero pitches and exactly one `general`/`General`/order-0 note. No extra pitches anywhere. Validate global cross-entity UUID uniqueness, exact fetched/inverse owner membership, section shapes and contiguous orders; counts or child-owner checks alone are insufficient. Unknown areas, missing/extra fixtures, modified immutable metadata, orphans and duplicate/cross-owner links fail closed. Retained area order, route name/UUID tie-break order and persisted pitch order are distinct.
- Creation is unavailable before validated load. Opening/typing/Cancel writes nothing; nonempty names (including whitespace) require discard confirmation, saving/dirty drafts cannot silently dismiss. Termination before commit creates nothing; commit before interrupted UI acknowledgment can leave one route, loaded truthfully without replay/fresh-save claims. Retain absent-root-only exclusive graph/marker initialization, autosave/CloudKit off, symlink/path/protection settings and unavailable-store guidance. Existing incomplete/corrupt/missing-store roots retain bytes: no repair, reset/reseed, fixture-default merge or assumed container teardown/diagnostic cleanup.

Preserve predecessor-format coverage using distinctive exact notes/revisions/IDs and reversed/nondefault pitch order written before extended validation, then in-place creation/edit/reopen assertions; new-format-only fixtures are insufficient. Retain real on-disk collision/ownership/rollback/retry/no-reseed tests, duplicate-safe process-relaunch UI assertions and isolated generated test namespaces. Keep both CF-04B migration tests and their actual runtime-specific assertions; no new failure is known merely by matching a count. §21.6.8 replaces old cadence/coverage/review gates, not these data safeguards. Unexplained byte/identity/order change, relaxed fixture checks, wrong-owner/duplicate retry or premature save acknowledgment stops dependent work. Ordinary success is not valuable-data, migration/replacement, backup, real ENOSPC, crash/power-loss or physical-device safety approval.

### 21.6 Consolidated Text-Notebook Milestone: Approved

**Status (2026-10-31):** owner selected **Approve Milestone** after reviewing this section and its storage, explicit-save and personal-data boundaries. Approval authorizes one end-to-end milestone, including internal implementation sequencing, tests, fixes, independent internal review and documentation. It does not require approval of individual engineering slices. This is a bounded extension of §§21.4.4-21.5.1, not blanket L2/M2, M1, migration, backup or release acceptance. Existing §§4-8, §13, §16.1 and DESIGN.md remain authoritative except for the explicit scope/defaults below.

#### 21.6.1 Audit and Scope

Historical baseline at milestone approval (2026-10-31), not current status or a new inspection. CF-07B/CF-07D were subsequently superseded with no separate acceptance requested. Source establishes implementation, not acceptance:

| Baseline | Disposition for this milestone |
| --- | --- |
| CF-07A (`4591da1`) and CF-07C (`423685d`) | Owner-accepted navigation/reading: read-only Previous/Next, full route General prose, Jump to Pitches, persistent adjacent controls, contextual focused editors. Preserve these behaviors. |
| CF-07B | Implemented durable notes/order, subsequently superseded. Preserve explicit-save, plain-buffer, UUID, revision and rollback patterns; do not infer acceptance. |
| CF-07D | Implemented name-only route creation, owner-paused verification. 33/33 focused state/persistence tests and an earlier 1/1 creation UI pass do not complete acceptance. Carry its duplicate/cancel/error/relaunch requirements into this milestone; do not automatically mark its card Done. |
| Current storage | Five-entity `NotebookSchemaV1` 1.0.0, marker `CF-07B-1`, explicit saves, inverse relationships and pitch order. Loader requires fixed areas, routes and pitches, permits extra zero-pitch routes, and sorts routes by name. No persisted area/route order; generalized deletion/rename would violate fixture validation. |
| Known failures/limits | Two named CF-04B migration tests remain unresolved. CF-07D has distinct UI-helper/keyboard-evidence failures and interrupted checks; these are not baseline migration failures. Simulator software keys were not visibly rendered. Final creation suites/coverage/tablet checks are incomplete. Exact evidence remains in `docs/verification/NotebookPrototype.md` and `Persistence.md`. |

**Included:** create, rename, sibling-reorder and delete flat areas, routes and pitches; browse/read full route General and pitch notes; explicitly edit both note bodies; persist identities, ownership, text and ordering; consistent empty, invalid, cancel/discard, deletion, stale-edit, load and write-failure behavior. Deliver a usable notebook starting with zero areas, not a prepopulated demonstration. A user can create five pitches, enter distinct notes, reorganize them and reopen the entire hierarchy after process termination.

**Deliberately bounded defaults:** areas/routes require nonblank names; duplicate names are allowed. Pitch authored names are optional, with `Pitch N` as a presentation-only fallback. Creation is name-only, with blank unknown metadata and append-at-end order. Rename changes only the name. Retain the existing supported note structure: exactly one route-owned General section (empty allowed) and one plain-text notes field per pitch; do not infer separate sections from prose headings. Common/custom section management, expanded metadata editing, local search and route moves between areas remain later L2 work, not implied by this milestone. Users can delete routes to empty an area; nonempty-area deletion is blocked and explains that requirement, without offering an unavailable Move action. Reorder means siblings, not reparenting.

Excluded: attachments, media viewers, Photos/Files/share/paste intake, URLs/network capture, OCR, sync, collaboration, archives/interoperability, full backup/restore, migration-recovery research, new dependencies, custom fonts, decorative animations, architecture replacement and unrelated infrastructure. Do not restart CF-05 or CF-04B investigations. Preserve research tests and assertions separately from the MVP regression gate under §21.6.8.

#### 21.6.2 Storage and Compatibility Decision

**Approved with this milestone:** retain SwiftData and the small store/state/view implementation, without connecting diagnostic `LibraryStore` or the generation manager. The then-missing persisted area/route sibling order justified a separate successor format, not a framework rewrite or unproven in-place migration of retained files. The initial TextNotebook format described below is implemented; later V2 images are governed by §21.8 and the image contract.

Create a separately namespaced, initially empty text notebook under app-private `Application Support/TextNotebook/`, with the existing exclusive-absent-root bootstrap, symlink/sidecar checks, file protection, CloudKit-off and autosave-off rules. Reuse the demonstrated store lifecycle and transaction patterns. Introduce a small successor versioned schema (proposed `TextNotebookSchemaV1`, actual unique identifier recorded at implementation), retaining the existing five-entity shape and inverse rules, adding only area order, route order and notebook-level revision/state needed below. This is the initial version of a distinct notebook format, not a relabeling or silent alteration of `NotebookSchemaV1`. No in-place migration stages, filesystem move/copy, generation switch or V1 reserialization occur.

Keep `NotebookSchemaV1`, its migration plan, namespace, marker and fixture validation intact as the compatibility boundary. Existing `NotebookFixtureSlice` content, including CF-07D-added routes and all saved notes/order, remains explicitly accessible as **Retained Prototype (Legacy, Read-Only)**. Explain that it contains original examples and any saved edits, whose importance is unknown; do not classify saved edits as synthetic or replaceable. Preserve the accepted reader there; no automatic import, filtering by names/fixture-looking text, or reassignment as personal content. This avoids guessing which old edits are user-authored versus fixture material. Legacy mutation methods/tests may remain for regression evidence but ordinary app entry must not mutate the retained prototype. Later transfer/adoption requires its own reviewed plan; downgrading the new notebook to older binaries is unsupported.

Provide a separately labeled **Example Notebook** only through an explicit Open Examples action, using a distinct example namespace and the existing fictional five-pitch fixtures. Its changes never affect the empty/new notebook or retained prototype. Examples seed only on exclusive first creation, never on ordinary reopening; no Reset action is needed. Normal startup selects the new notebook without seeding examples. When a legacy root exists, show its retained-content entry and status, not a claim that the whole installation had no saved content. An unreadable legacy root is labeled unavailable with retained-files guidance, not hidden or used as a reason to create a replacement. Absence is checked before opening legacy content so browsing the chooser cannot seed a missing old store.

New-notebook failure never falls back to examples, legacy content or an empty library. Existing empty directories, missing store/marker, unknown version, corrupt/incomplete graphs and interrupted initialization fail visibly with Retry and retained-data guidance. No repair/delete/reset action. A failed initialization retains its namespace; after relaunch it may remain unavailable. A valid initialized notebook with no areas is a distinct, normal empty state.

**Compatibility evidence:** independently write a predecessor V1 graph with distinct Unicode bytes, revisions, reversed fixture pitch order and arbitrary added-route IDs; open through the retained reader and compare the whole graph. Create/edit/reopen the separate notebook and examples, then reread the predecessor and prove no semantic changes and no cross-namespace writes. Test unreadable legacy retention and new-store failure independently. Do not claim byte-identical SQLite files after opening (sidecar activity is possible), closed-container migration, or successful adoption. If implementation requires in-place migration, recovery copy or relaxing V1 fixture validation, stop the dependent work for an owner decision.

#### 21.6.3 Data and Local Operation Contracts

No hosted/public HTTP API. Continue one small main-actor store/state mutation owner, plain UUID-valued snapshots and separate editor buffers; no live persistent models in views or cross-actor transfer. Keep helpers local unless genuinely reused. Avoid a generic repository/protocol framework or multiple new coordinator layers.

Bind every snapshot, draft and submitted mutation to its originating notebook-source token (new notebook, particular example namespace or retained prototype), not just entity UUID/revision. Store selection must not retarget an existing editor, including across shared app windows. Disable source switching while a save is in flight; while dirty, keep the editor bound to its original source and require explicit confirmed discard before that window switches. A source mismatch rejects submission with its buffer intact. Retained-source tokens categorically reject mutations. Test shared-window/source-switch cases through state tests even if live multi-window UI cannot be exercised on the available simulator.

| Record | Identity, ownership and order |
| --- | --- |
| Notebook state | Exactly one marker UUID and exact recognized format, plus nonnegative notebook revision. Initialization saves marker and empty graph together. No marker means unavailable, not first-use empty. |
| Area | Stable globally unique UUID, exact name, contiguous zero-based library order; inverse routes with `.deny`. Flat, no parent. |
| Route | Stable globally unique UUID, exactly one fetched area, contiguous zero-based order within area, name, retained grade/style display fields, nonnegative route revision; inverse pitches and notes with `.deny`. |
| Pitch | Stable globally unique UUID, exactly one fetched route, contiguous zero-based route order, optional authored name represented consistently as empty text, retained grade and notes. Derived display position/count only. |
| General section | Stable globally unique UUID, exactly one fetched route, kind `general`, title `General`, order 0, bounded body. Exactly one per route; no separate pitch NoteSection. |

Validate UUID uniqueness across entity kinds including marker, mandatory fetched owners, both directions of inverse membership, absence of orphans/duplicates, exact sibling permutations, contiguous orders and text limits. Never use names, list positions or aliases for identity. Preserve exact Unicode/UTF-8 and newlines; trim names only to check emptiness. Area/route names and pitch names are at most 500 Swift Characters; pitch blank is valid. Each note body is at most 1,048,576 UTF-8 bytes, including boundary/combining-character tests. Limit routes to 100 entered pitches under §6.2; no silent truncation or fabricated metadata. No unmeasured large-library performance promise.

| Local operation | Commit and conflict behavior |
| --- | --- |
| Load | Validate the entire graph; return ordered snapshots and notebook/route revisions, not partial results. |
| Create area/route/pitch | Allocate draft UUIDs once, including General UUID for route; append at current sibling end; require current notebook revision and valid owner. Insert before linking on iOS17. Save all related records/order/revisions together. |
| Rename | Submit UUID, expected notebook revision and exact new name; preserve ownership, note IDs/text, position and other metadata. |
| Save route/pitch notes | Preserve existing expected-route-revision contract, verify exact owner and byte limit. Update route and notebook revisions on change. |
| Reorder any sibling list | Submit owner UUID (root for areas), expected notebook revision and complete unique sibling UUID permutation. Reject duplicates, omissions, extras and foreign owners. Save the full contiguous sequence once. Existing pitch-order clients may also retain the route-revision guard. |
| Delete pitch | Require revision/owner and explicit confirmation; delete only that pitch, renumber remaining siblings, increment owning route/notebook revisions once. |
| Delete route | Require revision/owner and named confirmation with actual pitch/General-note counts. Explicitly delete owned pitches and General then route in one transaction; renumber area siblings. `.deny` is not a substitute for explicit transactional deletion. |
| Delete area | Require revision, zero routes and confirmation naming area. Reject nonempty areas at UI and store boundaries; never cascade routes. Renumber remaining areas. |

Notebook revision serializes structural drafts and whole-list orders across shared app windows; route revisions additionally preserve existing note-conflict semantics. Structural mutations affecting a surviving route's name/pitches/order update its route revision; unrelated route edits need not invalidate a note buffer. Changed commands increment applicable revisions exactly once, with overflow rejection. A no-op returns current acknowledged data without writing/incrementing or announcing a new save. Before saving, validate staged graph and prepare the result; only return/publish it after `context.save()` succeeds. No fallible post-commit fetch may turn an acknowledged write into an apparent failed write.

Keep create IDs through retry. An exact already-committed new-record graph can return its acknowledged identity without reinsertion; partial/cross-kind collisions or changed records conflict, never upsert. Validate this explicitly for each creation kind. All writes remain serialized, duplicate submits disabled. Save failure processes pending changes, rolls back and replaces the context on the same container (existing iOS17 workaround), retaining the last acknowledged snapshots. This is not closed-store recovery. Stale commands retain buffers and offer confirmed reload/review, not automatic overwrite. A deleted owner yields an explicit no-longer-available conflict; it must never crash a force-unwrapped view or silently retarget another record.

#### 21.6.4 UX, Durability and Failure Semantics

Use DESIGN.md's native lists/forms/toolbars/menus/alerts, system typography and scoped semantic palette. Consult indexed visual references when a design decision requires them, not for every routine edit. No inactive future-feature destinations.

- Library offers Add Area and separate Edit Area Order. Area offers Add Route, rename/delete and Edit Route Order. Route offers Add Pitch and a labeled actions menu; retain full General prose, Jump to Pitches and separate Edit Pitch Order. Pitch retains above-scroll Previous/Next and contextual Edit Notes; rename/delete are deliberate labeled actions. Full names wrap in rows; native titles may shorten, so identity remains readable in content/confirmations.
- All reorder workflows buffer a full sibling sequence, use native drag plus target-specific Move Up/Down controls/actions, and commit with Save. Creation, rename and note editors also use Save/Cancel. Do not combine reorder with insertion/deletion in the same editor.
- Changed Cancel requires Discard Changes/Keep Editing; unchanged closes without mutation. Disable interactive dismissal when dirty or saving. Hide Keyboard, Back, navigation, scene changes and backgrounding do not save. Modal editing prevents behind-editor mutations/navigation; stale external changes still conflict. Preserve selected pitch UUID after rename/reorder. After confirmed successful pitch deletion select a surviving adjacent pitch (next, else previous), or return to route if none; route/area deletion returns to the surviving parent only after commit.
- `Saving`, `Unsaved changes`, `Not saved - retry`, Retry and confirmed Reload Saved Version remain non-color, readable states. Failed create/rename/order/note/delete retains the draft or confirmation context, does not navigate or remove acknowledged rows, and permits retry/cancel. Reload/discard never erases another acknowledged edit. A failed store load blocks mutation and is never an empty-library state.
- **Explicit-save contract stays in force.** Non-destructive commits are labeled Save; confirmed Delete is separate. Publish/dismiss only after successful explicit database save. Unacknowledged changes can be lost on termination; no autosave, scene-flush or persistent-draft guarantee. Commit-before-ack may load on relaunch; never replay creation or fabricate a new save event. Distinguish loaded from newly saved internally and in applicable announcements; DESIGN omits routine Loaded/Saved chrome on reading screens. A Saved announcement requires an acknowledged changed write.
- Empty library/area/route/pitch notes have useful creation/edit actions and accurate counts. Invalid names/oversized text retain input with actionable errors. Deletion warnings name content and counts; they do not claim Undo, recoverability or backup. Confirmations can always be canceled before write. No interactive cancellation mid-commit.

#### 21.6.5 Files and Autonomous Execution

| Files | Planned change |
| --- | --- |
| `ClimbingNotebook/Models/NotebookSchemaV1.swift` | Preserve the existing legacy schema/migration contract unchanged. |
| `ClimbingNotebook/Models/TextNotebookSchemaV1.swift` (new) | Minimal separately versioned ordered notebook model above. New schema is justified by missing durable area/route order and clean fixture separation, not future speculative fields. |
| `ClimbingNotebook/Services/Persistence/TextNotebookStore.swift` (new); retained `NotebookStore.swift` | Reuse demonstrated store patterns in a concrete new-format store, leaving legacy graph validation unchanged instead of interleaving incompatible fixture constraints with generalized graph mutations. Add only a `createIfAbsent: false` guard to legacy opening so read-only access cannot seed a vanished root. No generic repositories, diagnostic/generation service edits or framework replacement. |
| `ClimbingNotebook/Features/NotebookPrototype/TextNotebookState.swift` (new); retained `PrototypeNotebook.swift` | Plain new-format snapshots/drafts/revisions and acknowledged mutation publication; explicit notebook/example/retained source selection and namespace isolation. Retain existing fixture/state definitions for examples/legacy validation and regression tests; forward the legacy absent-root creation guard. |
| `ClimbingNotebook/Features/NotebookPrototype/TextNotebookView.swift` (new), `NotebookPrototypeView.swift`, `ClimbingNotebook/App/ClimbingNotebookApp.swift` | Empty notebook entry, labeled examples/retained access, hierarchy CRUD/order, safe UUID lookup/navigation and existing reading/editing patterns. Keep the accepted legacy view with a read-only flag rather than refactor its editing regression path; new-format view uses the same native patterns. No broad renaming/refactor. |
| `ClimbingNotebookTests/NotebookPersistenceTests.swift`, `NotebookPrototypeTests.swift` | Preserve predecessor regressions and add full new-graph on-disk/state/transaction tests. A focused new test file is permitted if the existing files become unwieldy. |
| `ClimbingNotebookUITests/NotebookPrototypeUITests.swift`, `FoundationLaunchTests.swift` | Preserve accepted flow and existing assertions; add empty-notebook CRUD/relaunch, complete ordering/deletion/cancel/error workflows and accurate source/disclosure assertions. Keep fixture tests explicitly in examples/legacy namespaces. |
| README, SYSTEM_DOCS, this plan, Kanban, existing notebook/persistence verification topics | Current behavior and limits, approval/status, exact final results and concise reusable device checklist. No per-slice reports or duplicate feature plan. |

Historical execution sequence was preservation/bootstrap, transactional hierarchy/state, native workflows and focused verification/fixes. The `CF-07E` card already exists; use Kanban for status, never recreate/claim it from this handoff. CF-07B/CF-07D were superseded without retroactive acceptance. No paused archive/migration work or internal approval packets are implied. Routine assigned fixes remain autonomous within these contracts; Done requires owner acceptance, not implementation confidence.

No commits/pushes/PRs, settings/permission/signing changes, new Agent Manager sessions/worktrees, simulator provisioning/settings changes or dependency installation. Internal Task agents for bounded audit/review are permitted, not visible sessions. Stop only dependent work for a consequential scope/data/UX decision, destructive recovery, unproven migration requirement, architecture/framework change or unexplained lost/cross-owned data. Investigate new failures within scope; report concrete evidence and a bounded recommended decision if unresolved, not another open-ended research chain.

**Concrete file split:** source inspection favors leaving legacy schema/graph validation intact to preserve their exact regression boundary, with only the absent-root guard described above. Add `TextNotebookPersistenceTests.swift`, `TextNotebookStateTests.swift` and `TextNotebookUITests.swift` for the new format/workflow rather than duplicating fixture assertions into new semantics. Existing generated-namespace UI regressions may explicitly enter the legacy test path in debug-assert builds; ordinary startup never does. This split is implementation sequencing under the approved contracts, not permission for a second framework, diagnostic adoption or broad refactoring.

#### 21.6.6 Verification and Acceptance

Use §21.6.8 and README for current verification: builds, fast meaningful units and short UI smoke, affected extended checks when warranted, and exhaustive suites before major releases. Reverify destinations/toolchain, use unique result/log paths and inspect actual summaries/failures. Coverage is optional, with no threshold or rejection-self-test gate. Keep named CF-04B assertions intact and report exact failures separately. No archive rerun with untouched archive/dependencies or hosted-success claim without execution. Documentation-only edits need content/link and diff checks, not simulator runs.

All criteria below are **Pending implementation/verification**, not passed by planning:

| ID | Observable acceptance and required evidence |
| --- | --- |
| TN-01 Empty-to-complete workflow | From a genuinely empty notebook create two areas, multiple routes including duplicate names and a five-pitch route; read/edit full General and distinct pitch notes. Stable UUIDs distinguish equal names. No automatic fixtures. Real UI workflow plus model/state tests. |
| TN-02 CRUD and ordering | Rename all entity kinds, reorder all sibling kinds using drag-capable editor and accessible alternatives, preserve notes/UUIDs/owners/selection. Cancel leaves graph/revisions unchanged. Test boundary moves, multi-index moves and every invalid permutation. |
| TN-03 Full on-disk graph | Temporary real store, explicit save, fresh contexts and fresh containers at same URL; compare full UUID sets, both relationship directions, exact note/name bytes, revisions, all sibling orders and counts after each operation and repeated reopen. No in-memory substitute or assumed container teardown. Retain live diagnostic roots rather than unsafe cleanup. |
| TN-04 Process durability | XCUITest uses a generated namespace stable across `terminate()`/relaunch, not reset flags. Verify complete hierarchy/names/notes/order after save, rename, reorder and deletion, across repeated launches. Terminate unsaved creation/edit/order and prove only prior acknowledged data returns. Fresh-context tests alone do not satisfy this criterion. |
| TN-05 Deletion | Canceled confirmation writes nothing; nonempty-area deletion rejected; route deletion removes only its pitch/General graph; pitch deletion renumbers siblings and preserves other notes/selection; empty-area deletion persists. Confirm counts and fresh-container/process readback, including delete-last-item empty states. |
| TN-06 Validation/conflicts/failures | Blank/limit/Unicode names, blank pitch names, byte limits, missing/foreign owners, ID collisions, stale revisions and no-ops. Two-window state/source-switch tests reject wrong-source submissions with buffers intact. Inject staged failures for every mutation kind: unchanged persisted graph/acknowledgment, retained buffer/IDs, Retry exactly once, no false saved/dismissal. Add deterministic corrupt/missing/incomplete-store cases and recoverable load failure without empty fallback. Injection is not real full-disk proof. |
| TN-07 Compatibility/isolation | Independent predecessor-format writer and retained reader prove prior V1 graph unchanged; new notebook and explicit examples are isolated, including draft/source-token mismatch and read-only legacy mutation rejection. No startup reseed, reset, migration or legacy disappearance. Unreadable roots remain visible errors with files retained. Release ignores test controls; Debug-only faults/fixture selection are confined to generated test namespaces, never arbitrary paths. |
| TN-08 Accepted reading | Long route/pitch bottom text reachable; Jump to Pitches plus tap, pinned Previous/Next disabled at boundaries, read-only navigation never mutates order/revision. Contextual editors and explicit-save/cancel/reload contract remain intact. |
| TN-09 UI/accessibility | Exercise default/AXXXL, light/dark, long/duplicate/Unicode names, all new errors/discards and selected tablet layouts; inspect rendered captures. Check native accessibility labels/order/target-specific actions, rendered contrast pairs and actual target geometry, using UI accessibility audits where supported (no blanket exclusions). Attempt keyboard-visible capture/reachability and native drag without changing simulator settings; if unavailable report exact evidence/limitation, not container existence as pass. Live VoiceOver speech, real keyboard and device checks remain explicitly unverified until actually exercised. |
| TN-10 Final quality/handoff | Affected core tests pass, checks follow §21.6.8, material review findings are addressed when review is warranted, and concise evidence/limits are reported. A failed extended/full suite stays Failed; optional coverage and baseline classification cannot turn it green. Owner acceptance is separate; historical audits alone are not an MVP blocker. |

Use internal test seams for before-save failures and generated UUID UI stores, preserving existing isolation. Never damage the ordinary store or alter permissions to force a test. Inspect actual test results rather than treating an attempted build as passed. Apply §21.6.8 to select checks; the detailed table above is retained as historical comprehensive qualification, not the required MVP gate.

#### 21.6.7 Honest Safety Boundary and Final Handoff

**Historical evidence boundary:** dated narratives below preserve actual outcomes and former qualification dispositions. §21.6.8 supersedes their audit-blocker/cadence language; CF-07E is in Review, not blocked by these historical audits. Kanban owns live status. CF-07B/CF-07D need no separate acceptance or resumed qualification under the owner-approved archive disposition. Do not rerun these investigations from this section.

**Owner-authorized audit isolation (2026-11-04):** bounded debug/generated-UUID-only minimal status and native editor probes delivered without persistence or production UI changes. Final explicit-normal-launch27 comparison passes2/9; approved tablet26.4 native/status comparison passes2/4. Native toolbar Dynamic Type failures reproduce without custom styling on both;27 also reports native contrast findings. Existing acceptance audits/exclusions/standards remain unchanged, and owner light/dark regular/maximum-size workflow success is separate human evidence with VoiceOver untested. No supported production remedy or false-positive determination follows; CF-07E stays blocked. Exact bundles, collection correction and environment/measurement limits are in [canonical evidence](docs/verification/NotebookPrototype.md#consolidated-final-disposition). Migration/recovery research remains paused; no external bug report was submitted.

**Owner UX direction (2026-11-03):** owner reports hands-on creation, editing, saving, reordering, deletion and reopening of synthetic notes passed, with accessibility working as expected and no issues found. Device/runtime/settings were not supplied; this is human-observed evidence, not resolution of failed automated audits or blanket milestone acceptance. Owner authorizes concise user-facing editors: remove repeated name-rule and explicit-save tutorial paragraphs; mark required fields locally, label optional pitch names, and use Save for all non-destructive commit actions, including creation and order. Delete stays explicitly destructive. This supersedes the Add/Finish Editing/Done presentation labels above, not their explicit commit boundaries, validation, exact-text, retry, discard or retained-data guarantees. Keep essential backup/recovery disclosure concise at the library and failure/destructive guidance at the point of risk. DESIGN.md owns reusable user-first language guidance; no new feature plan or save-behavior change is required.

**Owner priority update (2026-11-02):** temporarily deprioritize older-iOS accessibility-specific defects affecting visually impaired users, retaining them as known bugs rather than treating them as resolved. Keep iOS27 accessibility standards and unrestricted audit requirements unchanged. Preserve existing tests and report their actual failures; this priority change authorizes neither exclusions nor false pass/qualification claims. Ordinary-touch core operations must not be dismissed as accessibility-only without verification. Minimum17.5 remains provisional; data-integrity, migration/recovery and personal-data boundaries are unchanged. See [known bugs and verification limits](docs/verification/NotebookPrototype.md#known-bugs-and-verification-limits).

Implementation follow-through: bounded simulator visible-center diagnostics distinguish older-phone AX targeting from ordinary touch, including native toolbar overflow; test-only app-scene trait overrides exercise live Dynamic Type with source-bound draft identity and exact text preservation. These do not replace AX acceptance, unrestricted audits or physical-device qualification. No runtime-floor, schema, palette, native-menu architecture or acceptance decision is changed. Exact results and remaining audit/tooling boundaries stay in the canonical evidence above.

Owner-directed newest-iOS continuation records exact interaction severity in [Newest-iOS Interaction Severity Thresholds](docs/verification/NotebookPrototype.md#newest-ios-interaction-severity-thresholds): all12 observed text categories permit Route Actions; only the largest accessibility category requires one native-menu swipe to reach Delete Route in the tested example presentation. This is not an accepted limitation or audit waiver. Default-launch Dynamic Type/contrast audits remain unresolved; unsupported diagnostic style experiments were removed.

**Focused continuation (2026-11-02):**17.5 remains provisional. Controlled UI crash stacks identify injected XCTest automation logging callback SIGSEGV, not the historical17.0 persistence exception; unchanged direct five-pitch relaunch passes1/1 isolated17.5. Minimal test-helper fixes pass legacy largest-text creation/ordinary long reading2/2 on27 and17.5, tablet dark reading/menu/process readback1/1, and complete new current largest-text reading1/1. The latter still fails Route Actions hit-testing17.5. Phone menu outer/inner nodes have invalid hitpoints despite onscreen frames; descendant targeting and explicit toolbar placement failed and were removed. Full default library audit fails Dynamic Type and editor audit now contrast, with unresolved audit-versus-rendered evidence. Independent review narrowed the menu-specific helper; no persistence/schema/settings/floor change, exclusions or timeout increases. Full17.5 suites/combined coverage remain unrun; baseline migration barriers and human acceptance remain separate. [Canonical focused evidence](docs/verification/NotebookPrototype.md#focused-diagnosis-and-fixes-2026-11-02) supersedes stale blocker language below, not historical run totals.

**Controlled comparison (2026-11-01):** identical37 failing selectors on iPhone11/iOS17.5 pass9/37 versus10/37 on iPhone11/iOS18.6; only the direct five-pitch relaunch method changes pass/fail status (app crash17.5). Neither run reports keyboard-focus failures;17.5 has additional undiagnosed crash/disconnection boundaries. Keep17.5 provisional; shared failures and crash diagnosis, not the small pass-count difference, should drive further qualification. No additional floor change or full-suite/coverage claim. See [controlled evidence](docs/verification/NotebookPrototype.md#controlled-iphone11-os-comparison).

**Targeted comparison (2026-11-01):** owner-selected iPhone11/iOS18.6 reran only the37 failures from the17.5 targeted bundle: **10 passed,27 failed**, zero skipped/runtime warnings. Direct five-pitch process readback, maximum names, examples isolation and native drag now pass; remaining boundaries are action reachability/assertions, both audits, legacy creation timeout and the two migration barriers. No full-suite/coverage claim or floor change follows; minimum stays17.5. See [exact comparison](docs/verification/NotebookPrototype.md#iphone11-ios186-targeted-comparison).

**Owner floor update (2026-11-01):** minimum supported iOS is now **17.5**, explicitly authorized by the owner; Debug/Release deployment targets are updated. New selected iPhone15/iOS17.5 is `5640612A-EEF9-4B4D-828F-38EE8BDCC984`. The exact union of 45 failures from the preceding minimum/current full phone bundles was rerun without assertion or timeout changes: **8 passed, 37 failed**. All eight non-migration unit failures, including three fresh-container controls, pass; two migration lifetime failures and all 35 selected UI methods fail. This resolves those tested iOS17.0 persistence reproductions at the new floor, not full runtime qualification or UI acceptance. Historical iOS17.0 proof/results below remain historical; no further runtime decision is required to use the now-approved17.5 floor. Full new-floor suites/combined coverage remain unrun. See [targeted evidence](docs/verification/NotebookPrototype.md#ios175-targeted-failing-test-revalidation).

**Historical complete-suite status (2026-11-01): Failed, not implementation-complete or owner-accepted.** Baseline `35ba5b6` plus uncommitted fixes passed **149/156 iOS27** and **112/156 iOS17.0**; actual combined coverage gates passed **4546/4639 (98.00%)** and **3572/4639 (77.00%)**. Full suites verify current cancellation/termination, five-pitch process readback, maximum identities, retry and strengthened assertions. Assertion-only reruns39/39 current and33/39 historical minimum do not replace combined coverage. Earlier tablet layout3/4 and audits0/2 are superseded only for the affected dark-menu selector by focused evidence above. Historical17.0 first-throw mismatch must not be relabeled as observed17.5 failure or used to recommend another floor increase. Cold-launch scaling does not prove live scaling or waive audits. See [verified disposition/TN status](docs/verification/NotebookPrototype.md#consolidated-final-disposition). Consequential product, schema/data-contract, architecture, runtime-floor or destructive changes still require approval; ordinary debugging does not. Archive/recovery research remains excluded.

This milestone can establish ordinary explicit-save durability across real app process termination, complete hierarchy invariants, non-destructive failed-command handling and clear retained-store failures on the tested simulator matrix. It cannot establish corruption repair, safe future schema migration, closed-generation recovery, portable backup/restore, actual ENOSPC/power-loss durability, OS backup restoration or physical-device protection. CF-04B and archive blockers remain unresolved and separately scoped; no research is silently included to remove them.

**Personal-data recommendation:** still not ready as the sole/irreplaceable store of personal climbing notes. The new notebook accepts user-created text as a functional workflow, but development testing must use synthetic/replaceable content. Use a concise visible disclosure: `Development notebook. Explicit saves stay on this device. Backup and recovery are not available; keep another copy of important notes.` Examples remain explicitly synthetic; retained prototype edits have unknown importance and must not be described as disposable. A separate owner-approved data-safety milestone is required before recommending valuable-data use: bounded migration/failure recovery, usable verified backup/restore and physical-device validation. This milestone is usable for testing the complete text workflow, not a claim of production/release or personal-data safety. Backup/recovery gaps do not justify silently expanding this assignment or blocking every ordinary UI improvement.

**Review:** the historical planning review identified source-switch retargeting and misleading synthetic labeling of unknown legacy edits; the source-token contract and retained-content labeling resolve them. Subsequent independent source reviews and actual selected simulator runs are recorded in canonical evidence. No review or test pass implies owner acceptance or resolution of the named runtime/UI blockers.

Report the delivered change, actual scoped test results and material limitations concisely under §21.6.8. Do not repeat TN-01 through TN-10, device checklists or historical diagnostics for every feature. Owner acceptance and full-product/release readiness remain separate.

#### 21.6.8 MVP Delivery and Verification Policy

**Owner approved,2026-11-04:** simplify development for a bare-bones, pre-production MVP with no users. This policy supersedes conflicting verification sequencing, audit-blocker language, repeated review/approval packets and exhaustive reporting in this plan, skills, Kanban and verification documents. It does not freeze the product roadmap or authorize unrequested features.

**Required MVP signal:** the app builds and current core workflows work without demonstrated ordinary-use crashes, lost acknowledged data or blocked actions. Test hierarchy CRUD/order, General/pitch notes, explicit Save and cancel/discard, validation, failure/retry without false success, stable IDs/ownership/source isolation and saved content after process relaunch. Keep exact-text and meaningful persistence assertions. Passing tests reduce risk; they cannot prove absence of all code errors.

**Development environment,owner direction2026-11-05:** routine commits target latest, not the backwards-compatibility floor. Hosted CI uses `macos-26` and explicitly selects newest stable installed Xcode plus newest available installed iOS/iPhone, logging versions and exporting the same Developer directory for dependency resolution/tests. Current inventory lists26.6/26.5; do not claim this matches local27. Primary local targets are iPhone18Pro/iOS27.0 (development) and iPhone11/iOS17.5 (compatibility). Minimum deployment remains17.5; support intent spans later versions. Compatibility checks are affected/manual release work, not a per-commit matrix. Do not silently substitute first-device/image defaults or claim unavailable hosted runtimes were tested.

**Owner clarification,2026-11-06:** iPhone18/iOS27 is the primary local build and feature-verification target, currently represented by the installed iPhone18Pro simulator. iPhone11/iOS17.5 is solely the minimum-support compatibility target; do not prioritize its automation diagnostics over the primary development workflow. Keep the17.5 deployment floor and meaningful affected compatibility checks. Actual results on iPhone15Pro/iOS17.5 remain labeled as such, not exact iPhone11 qualification. Hosted unavailable-runtime limitations above remain honest; no CI/settings changes are implied.

**Owner-approved project rules,2026-11-05:** all generic development rules at the automatically loaded `https://vibecentral.novacoast.com/rules` are superseded for this native iOS app by its repository instructions and approved contracts. Do not fetch/consult that checklist, apply its defaults or restore requirements merely because they are automatically loaded. Higher-priority system/tool safety instructions and independently established project safeguards remain in force. In particular, mandatory70% coverage/pipeline requirements here are superseded: coverage is optional diagnostic information, never a percentage gate. Do not restore thresholds, introduce coverage-merging infrastructure or lengthen tests to meet a metric without explicit owner approval. Meaningful unit tests, actual test failures, security and data integrity remain project requirements.

**Verification cadence:** each push/PR builds and runs fast meaningful unit tests plus a small critical UI smoke set. Run affected slower checks for consequential changes; manually trigger extended regression/qualification before major releases. Do not require exhaustive UI/device matrices for ordinary commits or run tests merely to increase coverage. Check changed UI for practical readability/navigation at normal/maximum text, light/dark and keyboard states as relevant, reusing recent unaffected evidence. Documentation-only work needs content/link and diff checks, not builds/simulator runs. Independent review is useful when warranted, not an obligatory cycle for every change.

**Separate cohorts:** preserve migration/generation/archive/URL feasibility tests, native-control reproducers, exploratory diagnostics and automated accessibility audits as opt-in research/qualification. Audit flags alone are non-gating for MVP; retain exact failures without suppressing or declaring them passed. Reproducible core accessibility/interaction defects and current save/data-integrity regressions still block the affected feature. Restore/import/migration safety requirements become required when those features are actually implemented. Public-release accessibility and device qualification remain later work; VoiceOver is currently untested by the owner.

**Execution boundary:** `Scripts/test-ios.sh` defaults to `fast` (core units plus short UI smoke). The script and `Scripts/mvp-core-tests.txt` / `Scripts/mvp-smoke-tests.txt` own cohort membership, not counts duplicated here. CI runs independent `core-unit` and `smoke` jobs; manual dispatch selects core/qualification/all. `core-ui` selects core UI; `qualification` excludes the core cohort; `all` runs the full scheme. Choose all before major releases and affected extended checks earlier when warranted. For ad-hoc `-only-testing:`/`-skip-testing:` selectors, explicitly use `--suite all`; named cohorts reject overrides. Direct Xcode Test runs all tests. Preserve behavioral assertions; coverage reports are optional without a threshold or cross-job merge. A fast pass never relabels a failed extended/full suite; hosted success requires execution. README owns reusable command examples.

**Bounded diagnosis:** reuse existing conclusions before rerunning a known failure. At most one confirmation plus one materially different experiment per unresolved hypothesis without an actionable result; then record the limitation and return to feature delivery. No new diagnostic variants, category sweeps, toolchain escalation or repeated full-suite runs unless needed for a concrete core defect or explicitly requested. Paused CF-04B/CF-05 research stays paused. No specialist is required for MVP progress.

**Preserved boundaries:** explicit saves, retained read-only legacy content, no reset/reseed of saved stores, honest error handling, security, permissions and schema compatibility remain in force. Backup/recovery remain unavailable; keep another copy of important notes. No claim of full M1/v1/release readiness, accessibility compliance or owner milestone acceptance follows from this amendment.

### 21.7 Text-Only Notebook Export Contract (Approved)

**Priority deferred, owner direction 2026-11-06:** image-supported notebooks (§21.8) take priority. Export planning is complete and its approved contract below is preserved for possible later use; approval does not prioritize implementation now. No export code exists. Full backup/restore remains separate, not an image dependency.

**Owner direction,2026-11-05; proposal2026-11-06:** plan bounded text-only export after CI handoff. Both routine hosted jobs now pass at `d742ea6`; exact run/revision and verification limits are in [canonical evidence](docs/verification/NotebookPrototype.md#conclusion). CF-07E remains Review pending explicit owner acceptance, not accepted by CI. Superseded prototype and deferred archive/migration cards remain preserved in `docs/WIP_KANBAN_ARCHIVE_2026-11-05.md`, not active export blockers.

**Planning scope only:** propose complete hierarchy/full General and pitch-note export in saved sibling order as a readable text or Markdown file using native sharing. Define source selection, acknowledged snapshot versus unsaved buffers, exact authored text/Unicode, duplicate/empty names/notes, file lifetime/privacy, cancellation/error handling and focused tests. Keep ordinary storage and Save/Cancel contracts unchanged. This is Export, not an app-restorable Backup. No ZIP, attachments, import/restore, migration, networking, new dependencies or revival of archived research. Record the small contract here and obtain owner approval before feature implementation.

#### 21.7.1 Format and Content

**Recommend plain UTF-8 text**, `.txt`, `UTType.plainText`, no BOM. Markdown would require escaping or fenced-block rules that alter the independent readable copy. No format picker, timestamp-dependent output, summary, truncation, normalization or authored-text escaping. App-generated separators use LF; every authored field is inserted as its exact UTF-8 bytes, including composed/decomposed Unicode, emoji, tabs, CRLF, leading/trailing spaces and trailing newlines. Generated boundary newlines are additional bytes, never replacements for authored ones.

Deterministic grammar: begin `Climbing Notebook - Text Export\nSource: Notebook\nReadable copy only; cannot be restored into the app.\n`. Each following block begins with a blank line. Emit `=== Area A ===`, `--- Route A.R ---`, `General notes:`, `--- Pitch A.R.P ---`, and `Pitch notes:` as separate structural lines; A/R/P are one-based positions at their own sibling level. After area/route headings emit `Name:\n` + exact name + `\n`; after each pitch heading emit the same Name field even if empty. After each notes label emit exact notes + `\n`. Emit nonempty saved route Grade/Style and pitch Grade using the same `Label:\n` + exact value + `\n` pattern. Omit unknown empty metadata, not notes or entities. These are literal plain-text labels, not parsing delimiters or a round-trip format; authored text resembling headings/separators remains untouched.

- Traverse every area, route and pitch once in snapshot array order, already validated/sorted by persisted sibling order. No alphabetical sorting, deduplication or identity based on names. Position paths distinguish duplicate names and locate unnamed pitches; no synthetic fallback is written into the authored Name field.
- Emit `No areas entered.`, `No routes entered.` or `No pitches entered.` at the applicable empty collection. Exactly empty names/notes retain their label and empty field followed by a separate structural line `(No name entered.)` / `(No notes entered.)`. Whitespace-only fields are authored content, not empty; preserve them without trimming or replacement. Area/route names remain subject to existing saved-data validation.
- Include complete General and pitch notes; do not infer sections from prose. Do not export UUIDs, revision counters, source tokens/root paths, database/sidecar files, Examples, retained prototype content or unsaved buffers. No store-wide byte cap or silent partial output: preparation either produces the complete file or fails visibly.

#### 21.7.2 Source, Saved State and Native Flow

Add **Export Text…** in a labeled native **Library Actions** menu alongside Edit Area Order (preserve the latter's nonempty guard). Export is available for a successfully loaded ordinary Notebook, including a valid empty one. Hide it in Examples and the retained reader; guard `source == .notebook` in the capture operation too, not just `showsSources` or view visibility. Do not add an all-sources selector or silently use whichever reader is open.

Tapping presents a small native confirmation sheet titled **Export Notebook Text**, identifying **Source: Notebook** and stating **All saved areas, routes, pitches and notes. Unsaved edits are not included. This readable copy cannot be restored into the app.** Include **Share Text** and **Cancel**, plus concise disclosure that the chosen destination receives readable notes and may use cloud/network services. This is explicit source/scope selection, not automatic export on opening the menu.

On Share Text, require no current editor/other source cover, save or export preparation in that window. Capture the current source token, call the existing ordinary store's `load()` once, check its returned token matches, and copy that immutable saved snapshot for formatting. This fresh read includes other windows' completed saves; it excludes pending/failed drafts and does not submit, reload or discard any editor. It never executes a mutation or changes `acknowledgedRevision`/save feedback. A later save is outside this captured revision; no live file regeneration. A missing store, load/validation failure or source mismatch blocks export, never falling back to stale/empty/example data. Export cannot be launched inside an editor; returning to Library uses existing Save/Cancel/discard behavior. Drafts in other windows remain untouched, source-bound and subject to existing conflict rules.

Show **Preparing export…** and prevent duplicate Share/source/editor presentation until ready; Cancel before handoff abandons only export and removes any incomplete owned staging. Format/write once per request, not in SwiftUI `body`; avoid repeated large-string copies or blocking rendering during file work. Present the completed file URL through a small `UIViewControllerRepresentable` for `UIActivityViewController`, locally owned by the originating view with native iPhone sheet/iPad popover anchoring, not a global topmost-controller lookup. No outbound sharing wrapper currently exists to reuse. Dismiss the confirmation before presenting sharing; keep one stable payload/URL for that activity.

Share cancellation/swipe dismissal is normal, leaves saved data unchanged and permits another export. Preparation failures show **Couldn't prepare export** with an actionable load-retry or file-write/free-space explanation, **Retry** and **Cancel**; Retry reads saved data anew. Activity errors reported by iOS show **Couldn't share export**, **Try Again** and **Cancel**; retain the completed payload for that retry. Do not claim to detect destination failures not reported by iOS. Activity completion is a handoff, not proof of durable external storage; never say Backed up or change notebook save status. No app-owned networking is introduced.

#### 21.7.3 Temporary Files and Privacy

Use only an app-owned temporary subtree `TextNotebookExports/<random UUID>/Climbing-Notebook.txt`; no user names in paths. Write UTF-8 atomically and share only after successful completion. Mark generated files excluded from backup and use iOS file protection `completeUntilFirstUserAuthentication` so normal share/background access remains possible; do not promise encryption beyond system protection. No logs/analytics of content or automatic uploads. The user controls the destination; exported copies outside the app are not app-cleanable.

Remove partial/canceled-before-share staging immediately. Keep completed files during presentation, backgrounding and activity/provider access; do not delete on view disappearance or completion callback. Retain completed/canceled-share files for a conservative24-hour grace period, then delete expired directories at next app launch or export preparation, excluding any active payload in this process. A fresh process may remove only expired owned directories, not all temporary files. Thus interrupted exports are cleaned without a timer/service, but may remain until the app next runs; iOS may reclaim temporary storage earlier. Cleanup failure must not delete unrelated files, block notebook use or claim successful removal; retry on the next sweep. No security-erasure guarantee. Tests must constrain cleanup to this subtree and preserve active/recent/unrelated files.

#### 21.7.4 Small Implementation and Acceptance

Inspected implementation: `TextNotebookStore.load()` produces validated sibling-ordered `TextNotebookSnapshot` values in a fresh context; `TextNotebookState` keeps acknowledged snapshots separate from drafts. `acknowledgedRevision` is only a save-announcement marker, not eligibility for export after launch. Use those existing boundaries, not a new repository/service framework.

| Affected file | Bounded responsibility |
| --- | --- |
| `ClimbingNotebook/Features/NotebookPrototype/TextNotebookTextExporter.swift` (new) | Pure snapshot-to-text formatter, no store/file access. |
| `ClimbingNotebook/Features/NotebookPrototype/TextNotebookTextShare.swift` (new) | Small temporary-payload preparation/cleanup and native activity wrapper; local helpers, no generic service layer. |
| `ClimbingNotebook/Features/NotebookPrototype/TextNotebookState.swift` | Small guarded saved-snapshot capture using existing store load; no mutation or draft submission. |
| `ClimbingNotebook/Features/NotebookPrototype/TextNotebookView.swift` | Library menu, explicit source/scope sheet, preparation/error state and native presentation. |
| `ClimbingNotebookTests/TextNotebookTextExporterTests.swift` (new), `TextNotebookStateTests.swift` | Exact-byte formatter snapshots, temporary-file lifecycle/failures and source/saved-state boundaries. |
| `ClimbingNotebookUITests/TextNotebookUITests.swift`, `Scripts/mvp-core-tests.txt`, `Scripts/mvp-smoke-tests.txt` | One short export smoke workflow; include new unit class in the existing class-based core/fast selection without changing test-runner architecture. |
| README, existing notebook verification and Kanban | Document actual delivered behavior/results only after implementation. |

Filesystem-synchronized Xcode groups include new source/test files; no schema, dependency, project identity or store-format change is intended. No Backup UI, export history, attachments, ZIP, import/restore or migration work.

**Acceptance, pending implementation/verification:**

1. Golden exact-UTF-8 output tests cover deliberately nonalphabetical/reordered multi-area/route/pitch snapshots, duplicate names, unnamed/whitespace-only pitches, empty collections/notes, metadata, multiline names, Markdown/separator-looking prose and unchanged input values. Repeated rendering of the same snapshot is byte-identical.
2. Preserve complete large notes (including the existing1-MiB per-note boundary), trailing whitespace/newlines, mixed line endings and composed/decomposed Unicode, including a distinctive last line. Assert bytes against independently constructed expected output, not only a string-equivalent or formatter-generated oracle. No summarization, ellipsis or escaping.
3. On-disk/state checks prove capture after save/reopen, a second window's completed save, loaded-without-new-save eligibility, exclusion and retention of dirty/failed drafts, unchanged revisions/save status, and rejection of Examples, mismatched source tokens and load failure. No ordinary stores are reset/reseeded for tests.
4. Temporary-directory tests cover full UTF-8 file bytes, write failure with no advertised partial file, retry/cancel, unique stable payload, expired cleanup and preservation of active/recent/unrelated files. Use an injected temporary root/failure seam, not device permission changes.
5. Build and fast meaningful unit tests pass. A short generated-namespace UI check saves a small hierarchy, opens the labeled export flow and native share sheet, cancels, reopens and verifies notebook content unchanged; confirm no export action in Examples. Check the prepared payload's exact bytes in units, not via a debug text-preview feature or flaky share-target scraping.
6. Brief hands-on check on phone and available iPad: Save to Files then open the readable `.txt`, confirm order/full note endings, native cancellation/retry and correct iPad presentation. Inspect added controls at regular/maximum text and light/dark. Run affected checks under §21.6.8, not exhaustive historical suites; report unavailable destination/device/VoiceOver checks honestly. External handoff success never establishes restore capability or sole-copy safety.

**Owner approval,2026-11-06:** owner explicitly approved §§21.7.1–21.7.4 as the bounded scope for a subsequent export implementation assignment. TN-EXPORT-01 planning is complete. This turn remains planning-only; no export code is implemented or verified. Approval is distinct from CF-07E milestone acceptance and does not authorize commits, pushes, publication or settings changes.

### 21.8 Image-Supported Route and Pitch Notebooks (Approved)

**Owner approved,2026-11-06; TN-IMAGE-01 planning complete, TN-IMAGE-02 implementation:** the complete behavior/data contract, risks, checks and Stitch references live in [Image-Supported-Notebooks-FeaturePlan.md](Image-Supported-Notebooks-FeaturePlan.md). The owner authorized end-to-end engineering, verification, independent internal review and documentation. CF-07E acceptance and deferred export/backup remain separate. Main plan §21.6.8 governs delivery policy; this grants no commit/push/publication/settings permission.

**Later design reconciliation (2026-11-09):** DESIGN owns the approved intended route/pitch/reference/editor compositions and current visual index. The original image milestone's images-first Route placement is implementation history, not a competing target. Applying the new layout needs separately scoped work; no automatic note splitting, new schema, PDF intake or image-ownership changes follow from mockup approval.
