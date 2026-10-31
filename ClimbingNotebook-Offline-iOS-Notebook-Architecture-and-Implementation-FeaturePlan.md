# Climbing Notebook Offline iOS Notebook: Architecture and Implementation Feature Plan

**Status:** Owner-approved implementation plan, including CF-07B in §21.4.5.
**Prepared:** 2026-10-27
**Updated:** 2026-10-30
**Inputs:** `handoff.md` and the owner's clarification answers in this session.
**Deliverable boundary:** Approved implementation specification. The repository now contains a partial M0/M1 foundation and an accepted disposable notebook prototype; prospective files and contracts below are not claims of implemented features. Measured evidence and remaining gaps live in [notebook prototype verification](docs/verification/NotebookPrototype.md), [persistence verification](docs/verification/Persistence.md) and [archive verification](docs/verification/Archives.md). Task status lives in [WIP Kanban](docs/WIP_KANBAN.md); this plan retains approval scope and milestone gates. README owns setup and build/test entry points, not the evidence ledger.

## 1. Executive Summary

Climbing Notebook is a native, offline-first personal climbing notebook, not a guidebook service or a social network. A climber owns the local library, can consult all saved originals without connectivity, needs no account, and can export and replace-restore the library without a subscription.

The first public release includes the full core notebook, images and PDF originals, plain-text and pasted-text intake, user-initiated single-page URL copying, a receiving share extension, editable import review, source attribution, and verified complete backup/restore. **OCR and automatic structured extraction are deferred.** An image or scanned PDF is useful as a viewable original in v1, without invented route fields. Digital PDF text may be offered as unstructured selectable text when PDFKit exposes it; it is not a requirement to recognize scanned text.

Recommend SwiftUI, Swift, SwiftData with explicit persistence operations, app-managed original files, PDFKit/ImageIO, PhotosPicker, Foundation file APIs, and a small share-extension inbox. The owner approved an iOS 17 minimum; verify minimum/current OS behavior during foundation testing. All required frameworks are available at that baseline; no verified v1 requirement justifies excluding those devices. Build with a currently accepted Xcode/SDK, independently of the deployment target.

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
| Deployment target | iOS 17+ approved. Minimum/current runtime and device testing remain implementation verification tasks. |
| Staffing/development | One volunteer developer using an existing MacBook Pro, VS Code, and GitHub. Weekly availability is not specified. |
| Repository/CI | GitHub Free, public repository confirmed by owner. Use standard hosted macOS GitHub Actions; no GitLab pipeline or runner-tag requirement. |
| Approval and execution | Owner approved the plan after the dependency recommendation and confirmed public GitHub publication. |
| Dependency exceptions | Approved plan includes native Xcode/SPM resolution on local/hosted Macs, reviewed stable ZIPFoundation resolution with committed Package.resolved, and immutable third-party Action references with deliberate updates. |
| Integrity limits/restore | Initial intake/archive/library limits and generation-based replace/revert behavior approved as measurable targets, subject to the stated validation spikes. |
| Platform presentation | Owner confirmed iPhone as primary target with minimal iPad support. |
| Code license | Owner approved starting with MIT after discussing GPLv3 distribution concerns; MIT supersedes the earlier GPLv3 selection for first-party code. Preserve third-party notices. |
| Release ownership | Leif Johnson owns signing, releases, support and privacy URLs. Owner-controlled leifdigital.com will host new app pages without additional hosting costs; pages are not yet built. |
| Language and retention | English-first UI with Unicode user content confirmed; retain originals/raw text until explicit deletion, without automatic expiry of ready deliveries or saved drafts. |
| Minimum-runtime availability | iOS 17.0 Simulator installation and execution verified on 2026-10-28: the 19-test foundation suite passes on iPhone 15 Pro, as well as iOS 27.0. Physical-device coverage remains unverified; deployment target remains iOS 17. |

The owner's explicit answers supersede handoff scope ambiguities. In particular, the handoff's OCR acceptance item becomes a later-release criterion, while non-OCR intake and share receiving become v1 requirements.

### 2.2 Proposed Defaults, Not Yet Approved

- Schedule illustrations use 10 hours/week, not an owner-specified commitment. Staffing is confirmed as one volunteer; do not assume additional reviewers are available.
- Owner-confirmed presentation: iPhone-first native UI with minimal adaptive iPad support and no iPad-exclusive features. Verify basic iPad functionality.
- Foundation/SwiftData APIs must remain within the approved iOS 17 deployment target. Do not use newer SwiftData inheritance or custom-store APIs for v1.
- SwiftData selected only after the foundation proof of concept passes migration, snapshot, and generation-switch recovery tests. Core Data is the fallback if concrete failures cannot be resolved, not a second implementation maintained in parallel.
- Minimal structured import: review manually, optionally copy unstructured text into selected sections. No heuristic name/grade/pitch extraction until the post-v1 import phase.
- Owner approved MIT as the starting first-party code license on 2026-10-28, superseding the earlier GPLv3 selection. Code licensing never licenses user-imported material. Preserve dependency notices and confirm the copyright holder before finalizing the license notice; release ownership and Novacoast builder attribution do not independently establish copyright ownership.
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
| R07 | Automatic prompt persistence, clear pending/error states, recovery from interruptions | Save-failure and termination tests |
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

### 4.1 Navigation

Use a native library navigation stack, route detail as the primary workspace, and toolbar access to Import Inbox and Settings. On wider screens, a split presentation may reuse the same views. Avoid adding a tab solely for empty future features.

### 4.2 Library and Areas

- Library displays flat areas plus local search across areas/routes. Route rows show name, free-text grade, style summary, and entered pitch count.
- A new route requires a nonblank name and an area; create an area inline if necessary. Duplicate names are allowed and distinguished by area and metadata.
- Search is case/diacritic-insensitive substring matching of normalized names; literal user input is never executable predicate syntax. Empty search returns the current browse context. Use deterministic name/UUID tie-breaking and bounded paged fetches.
- Area deletion is blocked while routes remain. Offer moving routes to another area first; do not hide cascade deletion behind an area action. Bulk destructive route deletion is not required.
- Empty library, no search results, unreadable store, and unavailable protected files have distinct states. Store failure must never silently open a new empty library.

### 4.3 Route Detail and Editing

Display a compact header, save/availability state, overview, quick jumps to Approach/Pitches/Descent/Gear/Media, ordered pitches, note sections, media, and a Sources section. These are native readable controls, not a dense dashboard. Pitch access should take one tap from the visible list and at most a quick-jump plus a tap from a long route.

Use plain text, not HTML or an embedded rich-text engine. Common empty sections show an Add action without requiring content. Custom sections can have arbitrary titles and order. Reordering sections does not alter their kind. One common section of each predefined kind per route; multiple custom sections are allowed.

Existing-field edits use an editor buffer, a short debounce (proposed 300-500 ms), and explicit save operations on focus loss/navigation/scene transition when time permits. Show `Saving`, `Saved on this device`, or `Not saved - retry`. A saved indicator appears only after persistent save succeeds. Do not rely on SwiftData's implicit autosave timing or background callbacks for correctness. Unexpected termination can lose an edit not yet acknowledged as saved; do not promise otherwise.

New route/pitch sheets and batch import have explicit Add/Cancel semantics using separate drafts. Cancel never rolls back unrelated saved edits. Existing automatically saved edits have Done/Back, not a misleading Cancel. A locally retained draft supports recovery; destructive discard requires confirmation when nonempty. A failed save keeps the buffer and offers retry; navigation must not silently discard it.

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

Recommend iOS 17+ to retain the handoff's older-device support without introducing an API compatibility layer. SwiftData's ModelContainer and VersionedSchema are documented from iOS 17 [S1-S2]. App Groups and NSItemProvider predate that target [S3-S4]. Newer deployment alone does not prove better integrity, so acceptance tests, not anecdotal reliability claims, determine fitness.

At foundation, test the oldest supported iPhone and minimum OS runtime available to the team, plus a current OS. If the team cannot test iOS 17 or encounters reproducible platform defects, propose raising the minimum to the oldest supportable version, with device impact documented. Do not silently raise it during coding. Xcode/SDK upload requirements are separate: Apple's dated notice requires Xcode 26+ and iOS 26 SDK+ since April 28, 2026 [S5]; recheck the live submission rules before each release.

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
| `Scripts/test-ios.sh`, `Scripts/check-coverage.sh` | Standard xcodebuild test entry and real xcresult coverage gate | M1 |
| `.github/workflows/ios-ci.yml` | Pull-request/main GitHub Actions jobs on standard hosted macOS for the public repository, bounded artifacts, >=70% coverage | M1; verify runner/toolchain availability |
| Xcode project's shared SwiftPM `Package.resolved` | Commit reviewed dependency resolution for reproducible local/CI builds, only if exception approved | M1; ZIP policy gate |
| `.gitignore`, `kilo.json` | Exclude/deny secrets, signing material, generated output and caches; no broad permission weakening | M0 |
| `README.md`, `LICENSE`, `CONTRIBUTING.md` | Owner-approved license, setup/testing, architecture, release and governance | M0/M6 |
| `Documentation/BackupFormat.md`, `Privacy.md`, `ReleaseChecklist.md` | Exact v1 schema/examples, privacy policy, signing/release ownership | M3/M6 |

Future only: `Services/Import/OCRService.swift`, `HeuristicParser.swift`, their fixtures/tests, and an updated review UI. Do not create OCR stubs, CloudKit adapters, or empty future feature directories in v1.

No `.env` or server `config.yaml` is needed for this local app. If signing automation later uses credentials, document placeholder CI variable names, keep actual values outside the repository and agent access, and add `.env.example` only if an environment file genuinely becomes part of setup. Include `Built at Novacoast.` in supported app/extension manifest description metadata and About/license information; this attribution does not decide trademark or App Store seller ownership.

## 13. Test Strategy and Release Acceptance

### 13.1 Coverage and Environments

Require >=70% line coverage across first-party app/shared-intake/extension logic; do not inflate it with dependency sources or generated code. Also report core model, intake, and backup/recovery coverage separately, targeting >=85% where practical. A high percentage is not a substitute for fault-injection tests. Document any platform-only entry points outside automated reach and exercise them on device; no skipped or always-passing tests.

Use temporary on-disk stores and real files for persistence/integrity tests. Test the deployment minimum and a current simulator/runtime, plus a real older device for memory, share-host behavior, file protection, Photos, Files, and airplane-mode checks. Simulator tests cannot fully establish OS termination, data protection, or extension budgets. Run tests after every migration/dependency/SDK update and on every pull request/push to main via GitHub Actions. Use the existing MBP for minimum-runtime/device checks when hosted images lack the iOS 17 runtime; CI must not claim baseline coverage it did not execute.

### 13.2 Test Matrix

| Category | Required cases |
| --- | --- |
| Model | Duplicate names, blank name, valid/invalid decimals/units, free grades/styles, owner mismatch, no dangling origins, pitch/section order |
| Editing | Debounced save acknowledgement, navigation, stale revisions, keyboard, disk full/save error, draft cancel vs existing autosave |
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
| M1: Integrity foundation | M0 | Single Xcode project; versioned persistence; app/extension identifiers; on-disk migration/reopen, generation switch, ZIP64/limits spike; CI proof with coverage; sample area/route survives relaunch | 40-60 h |
| M2: Core notebook | M1 accepted | Library/search, route/notes/pitches/edit drafts, revisions and save state, accessible reorder; five-pitch offline text scenario passes | 50-75 h |
| M3: Media and recovery | M1 contracts; M2 model | Originals/thumbnails/PDF viewer, safe deletion, DTO backup, archive validator, full replace recovery; byte-identical round trip and injected restore failures pass | 70-110 h |
| M4: Intake/share/URL review | M1 mailbox and URL policy spike; M2/M3 | Picker/paste/share intake, explicit one-page URL text/selected-image copy, App Group ready inbox, manual draft review/provenance, idempotent commit; host/URL matrix and interruption tests pass | 75-120 h |
| M5: Reliability beta | M2-M4 | Migration/corruption/large-library/offline/accessibility matrix, coverage gate, oldest-device tests; all v1 acceptance cases pass, no known critical data-loss bug | 35-60 h |
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
| CF-06 | P0 / M1 | Wire GitHub Actions standard hosted macOS tests and real >=70% coverage failure on pull requests/main; prove failure with a controlled test change, standard-runner selection and bounded storage | Confirmed public GitHub repository, CF-03 |
| CF-07 | P0 / M2 | Implement area/route validation, edits, route moves, blocked nonempty-area deletion | CF-04 |
| CF-08 | P0 / M2 | Implement route workspace and recoverable autosave/error/revision behavior | CF-07 |
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

The owner approved a native local app instead of a service. Do not add Go, PostgreSQL, OIDC, Docker, HTTP endpoints or API docs merely to satisfy unrelated service defaults. Apply secret protection, unit coverage, provenance, documentation, Novacoast manifest attribution, and explicit review gates.

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

CI should compile both targets, run unit/integration and selected UI tests, gather xcresult/coverage reports, and fail below threshold. Begin with one standard hosted macOS job on a documented supported image/Xcode combination rather than an expensive matrix; cancel superseded branch runs, cap job time, and keep failure artifacts briefly (proposed three days). Keep caches/artifacts within free storage budgets; never upload personal library data or full large-library fixtures. Perform large-device/old-runtime checks locally and before release.

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

1. **Approved:** iOS 17 minimum. Verify minimum/current runtime and device coverage during foundation; no further baseline decision needed unless testing identifies a concrete blocker.
2. **Confirmed:** one volunteer developer, existing MBP, VS Code and GitHub. OCR remains postponed; manual intake/review is v1 scope. Weekly hours remain unspecified; calendar estimates are illustrative.
3. **Approved with the plan:** ZIPFoundation via native Swift Package Manager, reviewed stable-release resolution, committed Package.resolved, and deliberate tested updates. Narrow local/hosted-macOS dependency and reproducibility exceptions apply; so do immutable third-party Action references. No blanket dependency-policy waiver.
4. **Confirmed:** public GitHub repository on GitHub Free, not GitLab. Use standard hosted macOS GitHub Actions with bounded artifacts/cache. Do not change visibility, billing or repository settings without authorization.
5. **Approved:** proposed intake/archive/library limits and generation-based replace/revert behavior, with measurement/fault-injection verification as specified.

The owner subsequently stated, `Plan is approved. GitHub branch has been published as public.` That resolves implementation authorization and item 3. Do not treat this instruction document as permission to commit, push or publish.

### Before Public Release

6. Permanent registration of bundle/UTType/App Group identities, final display branding, and App Store seller/Novacoast attribution placement. Development identifiers rooted at `com.climbingnotebook.foundation` remain provisional; future marketing names should not drive technical-identifier changes.
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

Plan approval is recorded. The next implementation assignment is the bounded M0/M1 handoff in section 21, to be executed when the owner starts or assigns the agent. No commits, pushes, repository changes, signing changes, or App Store publication are authorized merely by plan approval.

## 21. Implementation Handoff

### 21.1 Assignment and Scope

These instructions are suitable as the opening assignment for an implementation session that also has access to this full plan. Do not create another Agent Manager session or worktree automatically. This document does not claim the implementing model has started or completed any work.

Implement the approved Climbing Notebook plan, beginning with **M0/M1 only**, except for the subsequently owner-approved disposable prototype in §21.4.4. Read the full document before editing, particularly sections 6-9, 12-13, and 16. Deliver bounded buildable, tested packets, not an entire app in one unverified pass. Stop at the applicable handoff boundary; subsequent milestones can use section 21.5 when assigned. Do not ask again for already resolved iOS, dependency, public GitHub, restore, intake, or OCR decisions.

Inspect the actual environment, repository and current feasibility evidence rather than assuming the planned files or gates are complete. The original handoff may no longer exist in the current checkout; this approved plan is the implementation source of truth. Preserve any existing user/agent changes.

### 21.2 Permissions and Guardrails

- Use Swift/SwiftUI, iOS 17+, one Xcode project, on-device local persistence/files, and no account/backend. The approved native exceptions apply, including SPM on macOS and a committed resolution file. Do not install unrelated package managers, project generators, or dependencies to avoid learning the native project format.
- VS Code is the preferred editor; Xcode and its tools remain the native build/test environment. Validate toolchain/runtime availability and use a real installed simulator identifier. Do not invent successful builds, test device names, package versions, Action SHAs, or coverage numbers.
- No OCR, sync, nested areas, merge restore, weather/maps, paid services, analytics, LLM calls, or automatic route-field extraction. URL copying is explicit one-page user action, not reference-only and not unattended crawling.
- No commits, pushes, PR creation, repository visibility/billing/protection changes, signing credential access, developer-portal registrations, real-site scraping probes, or App Store publishing without separate owner authorization. Use signing-free simulator builds. A provisional reverse-DNS namespace is acceptable for a simulator-only spike if clearly labeled, not registered or presented as final.
- Do not choose a permanent license or invent Novacoast/App Store legal ownership. Record unresolved license/release identity items without blocking local simulator work; do not distribute a dependency without preserving its required notices.
- Do not use real personal route libraries or third-party copyrighted guidebooks as fixtures. Use synthetic/generated test data and permitted originals. Never report saved/local status before files and metadata are durably acknowledged.
- Keep changes small and executable. No empty feature scaffolds, placeholder success paths, disabled tests, in-memory-only integrity validation, generic sync layers, or permissive ZIP extraction hidden behind a convenience API.
- If a foundation spike disproves the approved design, report the precise failing test/API behavior and the smallest proposed alternative. Do not silently switch to Core Data, reduce backup guarantees/limits, remove URL-copy capability, or weaken the destination policy. Independent safe work may continue, but dependent implementation must stop.

### 21.3 First Work Packet: Foundation, WIP Limit One

Maintain a local structured todo list with one active item. Use CF issue IDs from section 15 in progress/results; this is not permission to create GitHub issues. Work through the following packets in order, except that short feasibility checks may precede scaffolding where they eliminate substantial rework.

| Packet | Work and required output | Exit evidence |
| --- | --- | --- |
| F0: Inspect and reconcile | Read repository/global instructions and this plan; inspect status/branch/remotes, Xcode/Swift versions, simulator runtimes/destinations and public repository metadata using read-only operations. Record approval in any stale plan text. Identify signing-only/license decisions as release gates. | Exact environment observations, clean/dirty file inventory, selected installed simulator, and unresolved external prerequisites. No destructive cleanup. |
| F1: Minimal native build | Create the single Xcode project with app, share-extension, XCTest and UI-test targets/shared scheme. Add minimal launchable foundation UI only, required safe ignore/access-control rules and versioned schema. Build simulator targets before expanding. | Successful xcodebuild invocation with destination, scheme, exit result; shared target membership verified. No need for live App Group registration to prove simulator compilation. |
| F2: Persistence/generation feasibility | Prove explicit save/reopen with stable IDs and representative related records; use temporary on-disk stores, versioned schemas, a synthetic migration, isolation of old/new library directories, close/rebind behavior, and injected interruption/reopen/rollback cases. | Test names/results and actual files checked. Demonstrate that missing/corrupt stores do not silently create an empty library and no restore path depends on moving only an open database file. |
| F3: Archive feasibility | Review current stable ZIPFoundation release/license, resolve it reproducibly, record the real revision, and exercise entry-by-entry streaming, CRC/hash checks, cancellation, forbidden paths/link entries, inflated-byte limits, and ZIP64 boundary. | Interoperable archive inspection/round trip, actual >4 GiB boundary test or explicitly incomplete ZIP64 gate. Large generated files stay outside git; check free space and clean only owned scratch files. Do not substitute a tiny archive for a claimed large-file test. |
| F4: URL-policy feasibility | Prototype only the smallest enforceability check for explicit load, generic text capture and selected-media copy. Use controlled local test content/test harness rather than fetching real guidebook pages. Distinguish harness-only loopback access from production public-destination policy. Verify which WebKit navigation/subresource/DNS/redirect/size protections are actually enforceable. | API availability on iOS 17, real observed behavior, test cases and limitations. A WKNavigationDelegate top-level check alone must not be called complete private-subresource/DNS-rebinding protection. Escalate the documented alternative-design decision if required guarantees cannot be enforced. |
| F5: CI and evidence | Add the GitHub Actions workflow and shared local test/coverage scripts using free standard macOS runners, read-only permissions and verified immutable Action references. Run the equivalent build/tests locally, enforce >=70% first-party line coverage, and verify the checker fails on a below-threshold sample/result. | Exact local command outputs, target coverage breakdown and failure-gate proof. Workflow is syntax/configuration-validated but hosted CI remains unrun until separately authorized publication. Do not claim local tests prove hosted execution. |

F2-F4 are **feasibility gates**, not permission to implement all route screens, full restore UX or production URL import before the findings are sound. Factor successful spike code into the modest production services only where it is already fit; do not leave duplicate prototype implementations in the shipped target. Provide a concise README for actual setup/build/tests and explain native exceptions, rather than a speculative finished-product manual.

### 21.4 M1 Definition of Done and Return Format

**Archive findings (CF-05A/CF-05B):** the host-only streaming harness demonstrates real >4 GiB stored entry/archive/offset boundaries and bidirectional Swift/Python interoperability; deflated fixtures demonstrate only the >4 GiB uncompressed-entry boundary. Visible-entry path/resource policy is feasible, but ZIPFoundation's silent enumeration/header gaps cannot authorize whole-archive acceptance; expected names/counts and symlink rejection do not prove completeness or general link rejection. See [archive verification](docs/verification/Archives.md) for measurements, hostile/crash reproducers, commands, results and cleanup. Complete directory/header/ZIP64/link reconciliation, exact compressed-input consumption, immutable input ownership, full manifest/type validation, device/full-envelope/threshold/cancellation/disk-failure evidence remain gates under §§9.1–9.4 and §§21.4.1–21.4.3. No production validator or restore readiness is established. Research remains paused under §21.4.4; the tracker retains the separate Review/Blocked dispositions.

**Persistence findings (CF-04A/CF-04B):** the bounded generation recovery matrix covers pending-recovery protection, invalid generations, descriptor/journal interruption and retry; it does not complete CF-04 or M1. Closed-generation snapshot, migration recovery/retry and independent post-migration reopen remain unproven because deterministic store teardown is not established. Tests retain every assertion and preserve diagnostic stores rather than perform filesystem operations after a failed lifetime barrier. See [persistence verification](docs/verification/Persistence.md) for exact results, retained paths, limitations and the proposed sequential-process diagnostic; neither that alternative nor a Core Data fallback is implemented or authorized by this finding. Actual termination/power-loss/fsync, production restore and released-schema compatibility remain separate gates. These findings do not establish ordinary save/reopen data loss, permit a framework switch or authorize durable M2 work; §21.4.4 governs sequencing.

M1 is complete only when a clean checkout can resolve the approved dependency and build both native targets, the sample area's/route's acknowledged save survives reopen, actual on-disk integrity/migration/generation tests pass, the ZIP and URL-policy gates have evidence, and the local coverage check passes with meaningful assertions. A missing runtime, unexecuted large-archive case, unproven WebKit guarantee or unavailable hosted result must be reported explicitly; it is not a pass.

Return one milestone report containing:

1. **Completed CF IDs and files changed:** distinguish finished foundation behavior from feasibility-only work.
2. **Validation:** exact commands, Xcode/runtime/destination, test counts/results, coverage numerator/denominator and exclusions, archive boundary measurements, and URL-policy observations. Reference retained local evidence paths when useful.
3. **Failed/deferred gates:** concrete errors or API constraints; distinguish unrun from failed. Explain whether each blocks dependent work or only release verification.
4. **Decisions required:** only new architecture/permission decisions supported by evidence; do not re-ask resolved scope questions. In an autonomous goal where questions are unavailable, stop dependent work and report a real blocker rather than guessing approval.
5. **Next packet:** the smallest ready CF issue(s) and dependencies. Leave uncommitted changes available for review. Do not advance past M1 automatically under this first packet.

#### 21.4.1 CF-05C Preflight Design and CF-05D Test-Only Spike

Owner authorization (2026-10-28): after reviewing the proposed test-only spike question, the owner directed "Proceed based on your own recommendations." This authorizes the recommended bounded test-target structural-preflight feasibility spike (CF-05D), not a production parser, fork, dependency change or production validator. CF-05B and CF-04B remain Blocked; CF-05A stays in Review. The existing §§9.1–9.4 contract and resource ceilings remain authoritative.

**Source check (2026-10-28):** the [GitHub latest-release API](https://api.github.com/repos/weichsel/ZIPFoundation/releases/latest) still reports 0.9.20. The inspected upstream development [Archive.swift](https://github.com/weichsel/ZIPFoundation/blob/e7a17d57c583067eaa6659cd6d9521265b7664e9/Sources/ZIPFoundation/Archive.swift) retains `AnyIterator<Entry>`, nil on failed record reads, and internal directory accounting; [Entry.swift](https://github.com/weichsel/ZIPFoundation/blob/e7a17d57c583067eaa6659cd6d9521265b7664e9/Sources/ZIPFoundation/Entry.swift) retains internal raw headers and optional encrypted-entry construction. GitHub reported development head `e7a17d57c583067eaa6659cd6d9521265b7664e9`. This is source inspection, not a build/test of development, an exhaustive audit of other libraries or a guarantee about future upstream releases. No package was downloaded, installed or resolved. A version bump alone is not an evidenced fix.

| Option | Benefit | Cost / approval boundary |
| --- | --- | --- |
| Reviewed upstream strict inspection API | Reuse the ZIP implementation and avoid a second production parser | No sufficient API found in inspected release/development files. Waiting or publishing an upstream proposal is not authorized implementation; publication requires separate permission |
| Narrow maintained fork exposing strict inspection | Could share record parsing with extraction | A throwing iterator and public raw fields alone do not validate malformed extras, directory accounting, descriptors or byte ownership. Requires a dependency/fork decision, maintained security fixes and full regression evidence; not selected |
| Separate bounded structural preflight, retain ZIPFoundation extraction | Can be prototyped entirely in tests against existing fixtures without changing the package | It is security-sensitive ZIP parsing, even if small. Requires explicit owner approval, independent review and an acceptance gate before any production use; proposed test-only research option |
| Alternative ZIP library/platform wrapper | May provide stronger introspection | No alternative has been audited here. Apple Compression is not ZIP; host Python/command-line tools are not an iOS production solution. New dependency/license/build/security review would be required |

**Recommendation for owner decision:** authorize only a test-target structural-preflight feasibility spike with the existing dependency unchanged. Do not authorize shipping the parser or call it a production solution. First prove complete record accounting and local/central reconciliation on small fixtures; if the approach requires restricting currently approved interoperable ZIP features, return for owner review rather than reject them silently. This is an additional capability proposal under §21.2, not an inference of approval from the prior commit or a generic continuation request.

**Architecture and files if approved:** add `ClimbingNotebookTests/ArchivePreflightProbe.swift` and `ArchivePreflightFeasibilityTests.swift`, using synchronized test-target membership only; extend the existing hostile-fixture helper in place only if needed to share deterministic construction, without moving it into app sources. No project/package/signing changes are planned. Update this section, [archive evidence](docs/verification/Archives.md) and the Kanban after measurements. Do not touch persistence, production file coordination/staging, manifest DTOs, extraction destinations or app targets. Do not compile with `@testable import ZIPFoundation`, edit the cached checkout, use reflection into internals or patch binary layouts to bypass the API boundary.

**Proposed test-only API/data contract:** a throwing `inspect` operation takes a caller-owned file URL, explicit test resource budgets and cancellation check, and produces structural metadata only after the entire inspection succeeds. Metadata describes archive byte count, central-directory span, verified record count and each entry's ordinal, raw name bytes, flags/method, creator/type attributes, local-header and compressed-data spans, effective UInt64 sizes, CRC and descriptor span where present. No output file URL, extraction permission, persistence object or restore validation token is returned. Failures distinguish I/O/truncation, malformed structure, unsupported feature, ambiguity/header disagreement, budget exceeded and cancellation; unexpected conditions never return partial success. Values remain UInt64 until a checked conversion for a bounded read; every addition/range is overflow-checked against actual file length. Names and variable fields are length-bounded before allocating; aggregate retained metadata has an explicit budget in addition to the 25,000-entry ceiling, with valid-envelope compatibility measured before any production budget is selected.

**Structural acceptance requirements:**

1. Read through bounded random-access operations, never whole-file `Data`. Establish one unambiguous EOCD/ZIP64 directory interpretation, validate comments/locator/record lengths, disk fields, offsets, actual directory extent and count agreement. Do not trust count alone, use a signature scan inside payloads, or accept a truncated prefix as a complete directory. Ambiguous interpretations fail closed.
2. Parse each central record within the verified directory span and account for the complete region. Validate every local reference against actual archive length and all variable field lengths before reading. Reject repeated local-header references, overlapping entry spans and header/data ranges crossing into the directory. Investigate gaps, unreferenced records, prefixes/trailing data and optional ZIP structures explicitly; define compatibility treatment with positive fixtures and owner review before imposing a new archive profile.
3. Compare raw local/central names, methods and relevant flags. Reject encryption in either header and unsupported methods; validate stored size consistency. Reconcile effective sizes/CRC according to ZIP rules, not unconditional byte equality: valid data-descriptor archives legitimately use local placeholders. ZIP64 sentinel fields must have complete, noncontradictory extra information; malformed/duplicate ZIP64 fields cannot silently fall back. Descriptor width, optional signature, sizes, CRC and bounds must be verified; unresolved ambiguity rejects, not guessed acceptance.
4. Bound and validate all extra-field framing, including unknown fields. Establish an explicit policy for fields that can change path/type/link interpretation. Do not claim arbitrary hard-link metadata rejection from UNIX mode or `.symlink` alone. Identify representations from the ZIP specification and independent fixtures; unresolved semantics keep the link gate blocked. A blanket unknown-extra-field rejection or a descriptor ban would be a compatibility decision requiring owner review, not an automatic shortcut.
5. Bind each library-returned entry to the corresponding inspected ordinal and effective metadata before consumer extraction. Exact visible-path equality is insufficient for duplicate paths or hidden tails. If public extraction metadata cannot be reconciled safely with inspected records, stop this approach rather than substitute offset-based extraction or a new decompressor. Preflight does not prove exact compressed-stream consumption through the current API; trailing compressed bytes, overlapping payload interpretation and backend differences require explicit tests and may expose a further blocker.
6. Keep content policy separate: exact generated backup namespace, normalization/collision checks, manifest/foreign-key/type validation, per-file/aggregate streaming budgets, CRC comparison and SHA-256 remain required after structural inspection. Preflight header sizes are never sufficient to stop inflated-byte overrun. Structural success alone is neither backup validity nor restore authorization.

**Input identity boundary:** tests own closed synthetic files and make no claim of provider coordination or adversarial concurrent-write protection. Hash-before/hash-after equality is not by itself a coherent snapshot or a complete time-of-check/time-of-use solution. Production would require owner-reviewed immutable/coordinated staging tied to the archive hash across inspection and extraction (§9.4); pathname identity or modification time alone is insufficient. That production file-ownership service is outside this packet.

**Executable acceptance if approved:** preserve the CF-05B observations unchanged, and assert that preflight rejects each encrypted/unsupported, malformed-record, false-count, malformed-ZIP64 and disagreeing-header fixture as a whole before any consumer receives data. Add first/middle/last malformed positions, inconsistent directory size/count, offset overflow, duplicate/overlapping local references, descriptor truncation/ambiguity and extra-field framing cases. Pair every rejection rule with valid stored/deflate controls, local-placeholder descriptor controls (signature present/absent), ordinary and ZIP64 extras/offsets, UTF-8 names and independent-tool fixtures. Positive controls must prevent a reject-all implementation from passing. Any legitimate producer layout that cannot be supported safely remains a measured blocker, not permission to weaken §§9.1–9.4.

Run the focused baseline/hostile/preflight classes and full unit/UI suite on reverified iOS 17 and newest installed runtime, preserving all migration assertions. Require both combined >=70% coverage gates, rejection self-test and `git diff --check`; report known CF-04B failures separately. Because the preflight would newly consume large ZIP structures, run it against CF-05A's four capability archives containing real >4 GiB entries (only the stored archives exceed 4 GiB total) after free-space preflight, using an opt-in host driver and owned scratch cleanup. Do not retrofit those synthetic capability fixtures into valid backups or reduce resource limits. Measure bounded reads/metadata, cancellation and exact thresholds; document unrun device/envelope gates. Do not publish or promote to production until independent review and the owner decision resolve the demonstrated gaps.

**Exit and stop conditions:** this spike may establish only test-only structural feasibility. Crashes, hidden entries, unchecked ranges, ambiguous descriptors/extras, unreconciled extraction metadata, missing link semantics or rejection of required valid controls stop dependent implementation. Report exact fixtures and the smallest next design decision; do not install another library, expand into a general-purpose ZIP framework or silently redefine the accepted archive format. CF-05B remains Blocked until the capability is actually demonstrated and reviewed. CF-04B, production URL copying, full M1 acceptance and M2 authorization are unaffected.

**CF-05D measured outcome (2026-10-28):** the owner-authorized test-only probe now rejects 42 first/middle/last hostile-header variants plus false counts, bad directory accounting and shared local references. Five added test methods cover valid stored/deflate/UTF-8, signed/unsigned ordinary and small-ZIP64 descriptors, budgets/cancellation, framed UNIX `0x000d` link-capable tails and explicit unresolved ASi/unknown extras. Existing CF-05B assertions remain active; only fixture-helper visibility and optional descriptor construction were shared. An opt-in host driver (`CF05D_PREFLIGHT=1 bash Scripts/test-archive-boundaries.sh --run-large`) reruns the independent Swift/Python large-boundary probe unchanged in content, then inspects all four archives with <=65,881 read bytes / 65,557 maximum request each. It preserves the stored-vs-deflated boundary distinction and cleans verified owned scratch. Full evidence/commands are in [archive verification](docs/verification/Archives.md), CF-05D. Focused 14/14 each, full 30 passed / 2 unchanged CF-04B failed / 0 skipped out of 32 each on iOS 17.0 and 27.1; both coverage gates 167/194 (86.08%), rejection self-test/shell syntax/diff checks pass.

**CF-05D stop:** structurally consistent nine-byte payload `cb48cdc9c90700dead` yields `hello` and expected CRC from ZIPFoundation despite trailing declared compressed bytes, with no consumed-input count. `testPreflightCannotProveExactDeflateConsumption` preserves this extraction ambiguity, not successful whole-archive validation. Broader extras/link semantics, optional/prefix/gap layouts and untested descriptor/ZIP64 variants are unresolved; conservative research errors do not approve a narrower format. No second decoder, fork, new dependency or production acceptance was implemented. CF-05D and CF-05B remain Blocked, bounded code awaiting independent review; CF-05C design and CF-05A remain Review. The smallest next packet is review/design of a strict library extraction result (exact input consumption/end-of-stream) and unresolved metadata compatibility, not further parser expansion. Production immutable input ownership, manifest/type/policy validation, full envelope/device evidence and all prior M1 gates remain. Nothing here proves data loss or escaped files; it demonstrates missing validation evidence.

#### 21.4.2 CF-05E Strict Extraction Boundary Review

This bounded review follows committed CF-05D `39c3829`. It authorizes no fork, cached-package patch, second decoder, new dependency, production linkage or format restriction. Review corrections within the existing test probe and public-API observations are independent safe work; implementation dependent on exact compressed consumption stays stopped.

**Inspected flow:** ZIPFoundation 0.9.20 `Archive+Reading.swift:86–118` returns CRC only. `Archive+Helpers.swift:31–42` forwards the declared compressed span to `Data.decompress`, while consumer progress increments inflated bytes. `Archive+Progress.swift:32–38` defines read work in terms of uncompressed size. On Apple platforms `Data+Compression.swift:117–149` records provider-read position, but returns after `COMPRESSION_STATUS_END` without exposing residual `stream.src_size`, unread declared bytes or stream-end status. Therefore progress, public entry compressed size and provider read totals are not consumption evidence. A decoder can read ahead beyond its stream end; reducing buffer size is not a correctness contract.

**Proposed library-level result, design only:** strict consumer extraction should return UInt64 declared compressed bytes, actual compressed bytes consumed, produced inflated bytes, CRC-32 and an explicit completed end-of-stream outcome. Internal read-ahead bytes must be accounted separately from consumed bytes; at end, `consumed = supplied - remainingBufferedInput`, with checked arithmetic, no second stream accepted and no unread declared bytes. A strict success requires consumed exactly equals the inspected compressed span, reached stream end, produced exactly the expected inflated count and matching expected CRC. Stored entries require exact bounded reads and stored compressed/inflated equality; they do not invent a DEFLATE end marker. Valid final-byte DEFLATE bit padding is not a trailing byte and must not be rejected by a byte-level equality rule. A result must belong to the inspected record/immutable input, not merely a path match.

**Failures and streaming:** truncation/no stream end, trailing or concatenated stream data, I/O errors/short reads, consumer limit errors, cancellation and size/CRC disagreements must throw, never return a partial successful result. Counters use UInt64 and check overflow before increments; buffers stay bounded, zero-progress decoder loops fail rather than spin, and invalid buffer sizes are rejected. Consumer output before final checks remains untrusted/unpublished and is discarded on failure; a strict result cannot retroactively prevent earlier consumer callbacks. Production coordination, output ownership and manifest/type acceptance remain separate. No strict-result interface is mocked as if the approved package already implements it.

**Minimum executable acceptance for a future approved implementation:** valid stored/deflate and empty streams; truncated streams; trailing zero/nonzero bytes; concatenated complete streams; stream end within a read buffer and exactly at its boundary; varied chunk sizes and zero-output steps; consumer/cancellation errors; ordinary/ZIP64 descriptors; CRC/size mismatch; bounded counters beyond 4 GiB. Cross-check both Apple Compression and any supported alternate backend independently. Existing small public-API tests can demonstrate the gap, not verify the proposed result. Any library/fork/decoder implementation requires a separate owner-reviewed scope and independent review before production use. Neither a second validation pass through the same permissive API nor manifest/output hashes supplies the missing consumption guarantee.

**CF-05E measured review outcome (2026-10-28):** separate internal review of `39c3829` produced executable ZIP64 counterexamples: effective local offset zero structurally passes but disappears from library enumeration, and local-only ZIP64 descriptor yields library inflated size zero versus inspected five. These are retained mismatches, not accepted archives or new compatibility restrictions. Three added methods also prove that 5/5 Progress and full provider read-ahead counts cannot distinguish valid deflate from trailing junk/concatenated streams; add mid-inspection cancellation coverage; and bound extra-field cardinality before dictionary allocation. The probe now calls its metadata limit encoded-byte accounting, **not retained/transient heap allocation control**; tail/object overhead is outside that accounting, and the new 64-field budget is research-only. EOCD candidates use one optional index; cancellation is checked periodically during scanning/extras and around bounded sorting/return. No format/decoder/dependency expansion occurred. Full evidence, exact commands and cleanup are in [archive verification](docs/verification/Archives.md), CF-05E. Final focused 17/17 each; full 35 each, 33 passed / only 2 unchanged CF-04B failed / 0 skipped on iOS 17 and 27.1. Both coverage gates remain 167/194 (86.08%), self-test and diff check pass. Affected independent large harness was rerun successfully with unchanged boundary measurements and verified scratch cleanup. CF-05E is Review; CF-05B/CF-05D remain Blocked and CF-05A/CF-05C stay Review. Smallest next work is owner review of a library-level strict result and ZIP64 reconciliation implementation choice, not shipping the structural probe. Production hostile-archive validation, restore readiness, all prior M1 gates and M2 authorization remain unresolved.

#### 21.4.3 CF-05F Implementation Choice: Bounded Candidate Approved

**Scope and status (2026-10-28):** this packet is documentation-only design/research against clean committed baseline `9488fc5`; no candidate, dependency update, decoder change or production validator has been implemented. CF-05F remains Review pending independent verification of its evidence; the owner has approved the bounded next candidate packet below, not production adoption or acceptance of prior capability gates. CF-05A/CF-05C/CF-05E remain Review; CF-05B/CF-05D and CF-04B remain Blocked. The existing probe is research-only, its `metadataLimit` accounts for encoded bytes rather than heap/RSS, and its 64-extra-field cap is not an approved compatibility restriction. §§9.1–9.4 and all M1 gates remain unchanged.

**Owner approval (2026-10-28):** after the bounded proposal and maintenance/testing recommendations were presented, the owner stated: "Leif will be the primary and only maintainer / developer for now. We will utilize agent models to assist and lighten the burden. All other recommendations approved." Leif is the sole human maintainer/developer and accountable owner for security triage, upstream updates and adoption decisions. Separate agent-model review passes may assist with review and evidence verification; they do not establish an independent human security audit or transfer maintenance accountability. No additional human developer/reviewer is required to begin the local feasibility candidate. Maintain implementation/review separation and report review limitations before owner acceptance. The approval covers the local source copy, specified existing-decoder plumbing and ZIP64 changes, isolated host/unit/simulator integration, acceptance matrix, stop conditions and estimated maintenance budget. It does not authorize another decoder/backend, production linkage/validation, broad inspection/parser expansion, remote dependency adoption, publication, commits or M2. The conditional proposal language below records the decision presented; this approval resolves its local candidate authorization and ownership prerequisites only.

**Reverified evidence and decision basis:** `Package.resolved`, the project test-target linkage, cached checkout HEAD/clean status and MIT license still agree on ZIPFoundation 0.9.20 at `22787ffb59de99e5dc1fbfe80b19c97a904ad48d`. Read-only Git status succeeds with the current alternate object store; the previously recorded stale `cragfolio` alternate-path diagnostic persists. No package source or metadata was modified/resolved. The [latest-release API](https://api.github.com/repos/weichsel/ZIPFoundation/releases/latest) still identifies 0.9.20; [development HEAD](https://api.github.com/repos/weichsel/ZIPFoundation/commits/development) is still `e7a17d57c583067eaa6659cd6d9521265b7664e9`. Inspection of that immutable revision's `Data+Compression.swift`, `Entry.swift`, `Entry+ZIP64.swift` and `Archive.swift` retains the relevant consumption, zero-value and descriptor-selection gaps. Development also changes path interpretation through Info-ZIP Unicode extras; an upgrade would need compatibility review, not just a version change. Development was not built or executed. These are targeted source checks, not a complete upstream/alternative-library security audit.

| Pinned source evidence (paths under `Sources/ZIPFoundation/`) | Consequence for the proposed change |
| --- | --- |
| `Data+Compression.swift:103–149`, Apple `process` exits at `COMPRESSION_STATUS_END`, returning only CRC | Preserve END and residual `src_size` before cleanup; provider position is supplied input, not consumed input. Decoder-state accounting must be verified, not inferred from output or progress |
| `Data+Compression.swift:217–258`, alternate zlib `decode` omits the declared size argument and returns only CRC | Any portable strict API must pass the span bound and account actual chunk length, residual `avail_in` and `Z_STREAM_END`; Apple-only measurements cannot certify this branch |
| `Archive+Helpers.swift:17–42`, stored reads use central inflated size; deflate forwards central compressed size; progress counts output | Strict stored reads must use the reconciled payload span and equality checks. Neither path currently returns a consumption report |
| `Entry.swift:299–315`, all three effective ZIP64 getters require expanded value `> 0`; `Entry+ZIP64.swift:25–33,106–125` represents absent fields as zero | Field presence must be retained independently of value; deleting `> 0` alone would turn absent fields into zero overrides |
| `Archive.swift:233–244`, descriptor width chosen by central `isZIP64`; `Entry.swift:134–138,172–196` separately chooses descriptor-derived public values | Reconcile local/central ZIP64 evidence once and use the same descriptor interpretation for public metadata, extraction and span length |
| `Entry+Serialization.swift:153–169` guesses optional signature from the first word; `Entry+ZIP64.swift:83–103,128–140` serializes/counts by nonzero values | Validate descriptor candidates against known CRC/sizes/bounds; retain explicit field presence in serialization too. Review add/remove regressions even for a read-oriented patch |
| `Archive.swift:218–255` still exposes nonthrowing prefix iteration | Strict extraction for one entry cannot establish complete enumeration or whole-archive acceptance |

Existing executable public-API evidence remains `ArchivePreflightFeasibilityTests.swift:5–25,49–98`: offset-zero disappearance, local-only ZIP64 public size zero versus inspected five, and identical output/CRC/completed progress for a valid seven-byte stream, nine-byte stream-plus-junk and fourteen-byte concatenation. These tests already use bounded file-backed synthetic fixtures and need no second decoder or new reproducer to establish the implementation-choice blocker. They were inspected, not rerun in CF-05F.

**Choice and tradeoff:** recommend a library-owned strict read capability, with reviewed upstream adoption the preferred long-term home. No sufficient released/development capability was found. For the next executable feasibility packet, propose a **narrow, explicitly owned ZIPFoundation fork candidate based on the exact pinned revision**, only after separate owner approval. Keep a reviewable patch to the existing record/decoder paths rather than adding a second decoder or shipping the first-party structural probe. This is a proposed fallback, not a selected remote dependency or approval to publish/contact upstream. If the owner cannot assign security maintenance and independent review, do not create the fork; dependent extraction stays blocked while upstream capability is evaluated. No alternative library is recommended now: the evidence identifies changes at the existing decoder/record boundary, not proof that a larger replacement is safer. A separately approved comparative library/license/iOS/API investigation becomes warranted if decoder consumption cannot be proven, the patch grows into general ZIP parsing, or maintenance cannot be sustained. Host Python/libarchive tools are not evidenced iOS replacements.

**Proposed source/API delta, not existing symbols:** add an opt-in `Archive.extractStrict(_:expectation:bufferSize:progress:consumer:) throws -> StrictExtractionReport`, consumer-only, leaving the shipped CRC-only API source-compatible. Existing consumers justify preserving that API, but it must never be a fallback after strict failure. No `skipCRC32` option, extraction destination or success-shaped partial result. The library constructs a read-session entry identity containing the archive-instance identity, central-record ordinal/offset and effective local-header offset; callers cannot forge it from a path. Add a read-only `Entry.readIdentity` and `Entry.readMetadata` snapshot (raw name bytes, both flags/methods, reconciled CRC/sizes, local/payload/descriptor spans, descriptor width/signature and ZIP64 field presence). They are record metadata, not a complete-inspection token. The strict operation requires a matching identity and expectation snapshot and checks the actual entry interpretation against it before reading. A copied `Entry` from another `Archive`, another record's expectation, changed spans or disagreement throws. Same-name records remain individually addressable by distinct identities; duplicate/collision rejection is separate app policy, not this library operation. Production immutable/coordinated file ownership is still required: an instance ID does not freeze file bytes or solve concurrent-write TOCTOU.

`StrictExtractionExpectation` is a design-only value carrying that read identity, exact compressed payload span, expected inflated count, expected CRC and a maximum inflated-byte budget. Test code may compare it with the existing probe result by ordinal and raw fields; it may not bypass the library with an arbitrary offset/provider. The maximum is checked before consumer delivery and never substitutes for the app's aggregate budget. A report carries the same identity/span, UInt64 `declaredCompressedBytes`, `suppliedCompressedBytes`, `consumedCompressedBytes`, `inflatedBytes`, CRC-32 and completion enum `.deflateEnd` or `.storedSpanComplete`. Failure types distinguish invalid arguments/identity, header or descriptor disagreement, unsupported/unresolved interpretation, I/O/truncation, missing stream end, trailing compressed data, inflated limit/size, CRC, overflow, stalled decoder and cancellation; original consumer errors propagate. No report is returned after failure.

| Proposed library files | Exact responsibility / ownership boundary |
| --- | --- |
| `Data+Compression.swift` | Add an internal strict decode result/path using the existing backend, separate from encode behavior; initialize decoder state safely, preserve terminal status/residual input, enforce bounded supply, checked counters, termination and cleanup. No new decoding algorithm/backend |
| `Archive+Helpers.swift`, `Archive+Reading.swift` | Plumb the strict result to the consumer-only API, exact payload-bound reads with checked seek/read errors, stored equality, expected CRC/size and limits, cancellation and identity checks; return only after all checks |
| `Entry+ZIP64.swift`, `Entry.swift` | Replace zero-as-absence with explicit field presence (optionals or a field mask); resolve each sentinel using its required present field including zero; never fall back from malformed/missing required ZIP64 data. Share reconciled metadata/descriptor width across public sizes, local span and extraction |
| `Entry+Serialization.swift`, `Archive.swift` | Add bounded throwing per-record reconciliation used by strict reads and identity assignment; reconcile local/central flags, methods, names, ZIP64 fields and descriptor candidates. Preserve signed/unsigned descriptor length explicitly instead of assuming the maximum struct size. This is not authorization for complete archive-inspection implementation |
| Library unit tests for those paths | Add strict-result and ZIP64 regressions using synthetic fixture records; retain legacy API observations. Exercise serializer/add/remove compatibility affected by presence changes |

The library owns byte-level decoding/record interpretation and its result truthfulness. This bounded strict API supports regular-file payloads only: a library-reported directory or symlink throws an explicit unsupported-entry-type error before any consumer call, whether stored or deflated. Do not reuse legacy directory empty-callback or symlink raw-byte shortcuts. This API limitation does not approve a new archive-format restriction or establish exhaustive link detection; the app's already-required type/link policy and separate inspection gate remain responsible for that. The app still owns archive namespace/path collision policy, all §§9.4 manifest/type/hash/resource checks, immutable input staging and unpublished output cleanup. Neither layer may silently repair contradictory metadata, skip hidden records, trust a manifest count instead of directory accounting, or promote permissive extraction to strict success.

**Byte and completion contract:** let `D` be the reconciled declared payload span length, excluding headers and any descriptor; `S` the sum of actual bytes returned by bounded source reads and supplied to the decoder, including read-ahead; `R` its remaining supplied input at termination; `C` the sum consumed by decoder processing; `I` the bytes inflated. Record/process checked deltas so `C = S - R` at stream end (including all earlier consumed chunks), with `0 <= C <= S <= D`. Unread declared bytes are `D - S`; buffered suffix is `R`; all trailing bytes total `D - C`. A strict DEFLATE success needs an explicit backend END, `C == D`, `I == expectedInflated`, matching CRC and no cancellation/error. Reading all `D` bytes, a completed output `Progress`, matching hashes/CRC or calling the permissive decoder twice cannot establish this. Do not restart the decoder after END to accept another stream.

On Apple retain `COMPRESSION_STATUS_END` and `stream.src_size`; on the existing alternate backend retain `Z_STREAM_END` and `avail_in`. Prove both report the required byte boundary, including backend internal buffering, before relying on the formula. If either backend hides/overconsumes suffix bytes such that residual accounting cannot distinguish controls, stop and return for another decoder-level design decision; this proposal does not authorize swapping backends. Preserve legitimate unused **bits in the final consumed DEFLATE byte**: no requirement for zero padding bits, no byte re-encoding/canonicalization and no rejection of a final byte merely because some bits are padding. Reject extra complete bytes after the first stream end, including zero bytes. Positive padding fixtures must demonstrate that the selected backend's consumed-byte semantics support this distinction.

For stored entries there is no DEFLATE END. Require `compressed == inflated == D`, exact bounded reads of the whole span, matching count/CRC and `.storedSpanComplete`, including empty stored files with CRC zero. Never read into a descriptor to satisfy an incorrect size. For both methods use UInt64 checked additions/subtractions and checked conversions to `Int`/`Int64`/file offsets/backend widths; reject nonpositive/oversized buffers before allocating. Exact-read adapters may accumulate positive short reads until the requested bounded region is filled; premature EOF, zero read before that point, overlong reads or I/O errors throw. Do not interpret a short read as final stream input. At declared input exhaustion drain pending output only through a bounded backend call that can report END; absence of END throws truncation. A step that consumes no input and produces no output may refill only when input is empty and declared bytes remain; otherwise fail as stalled unless END was reported. Consuming input with zero output is legitimate progress. Poll cancellation before reads, each processing step, before/after consumer delivery and before final success, including empty entries; release decoder/buffers on every throw. Consumer-delivered bytes remain untrusted and unpublished until success; a later failure cannot undo callbacks, so caller-owned staging must be discarded. No app destination manager is included here.

**ZIP64 and descriptor reconciliation:** follow [APPNOTE 6.3.10](https://pkware.cachefly.net/webdocs/casestudies/APPNOTE.TXT) §§4.3.9.1–4.3.9.3, 4.4.8–4.4.9, 4.4.16 and 4.5.3. Presence is separate from numeric value: a sentinel with a present expanded offset zero must resolve to zero, while absent/malformed required data throws; zero uncompressed/stored sizes must not become `0xffffffff`. Central expanded fields follow the sentinel-prescribed order, local ZIP64 size information includes both sizes, and serializer length derives from present fields even when zero. Reconcile ordinary nonplaceholder metadata exactly; bit-3 local placeholders are not unconditional local/central mismatches. Use local as well as central ZIP64 size evidence for 64-bit descriptors even for five-byte/empty entries, not just central version or `size > UInt32.max`. An offset-only central ZIP64 field or a version number alone does not justify an unreviewed descriptor-width heuristic; explicitly test its APPNOTE interpretation. Validate signed and unsigned candidates at the reconciled payload end using expected CRC, both sizes, available record bounds and width evidence. A CRC equal to `0x08074b50` is not automatically a signature. Require one consistent interpretation, retaining its exact length; missing/truncated/contradictory/ambiguous candidates throw an explicit error, not zero public metadata. Compatibility ambiguity stays a blocker rather than a new producer-layout ban.

**Separate complete-inspection gate:** per-entry reconciliation and strict decode reporting do not make `Sequence` complete. Before production acceptance, a separately reviewed bounded library inspection capability still must establish one unambiguous EOCD/ZIP64 directory, complete count/extent/bounds accounting, every local reference, no hidden tails/duplicate references/overlaps, raw header agreement, framed extras and explicit path/type/link semantics. Define treatment of optional records, gaps/prefixes, ZIP64 extensible records, unknown extras and independent nonseekable layouts with positive fixtures; no research-only allowlist/cardinality cap becomes a production restriction. A throwing iterator or public raw fields alone cannot establish these properties. This packet deliberately does not implement that capability or convert `ArchivePreflightProbe` into it. Heap/RSS and full-envelope acceptance are also separate from encoded-byte accounting.

**Provenance, reproducibility and maintenance:** preserve upstream MIT copyright/license and `THIRD_PARTY_NOTICES`, record base SHA plus the complete reviewed patch and candidate source-tree digest, and retain the existing backend, module and dependency identity. Approved local evaluation location is `Vendor/ZIPFoundationStrictCandidate/`, an owned source copy rather than an edited SPM cache; no copy exists now. Initially compile only its host/unit feasibility harness, with an explicit source path in the approved bounded harness change, no app/share-extension linkage and no project-wide replacement. Do not run it alongside another decoder as an acceptance workaround. A remote fork URL, immutable commit and `Package.resolved` change require a further explicit adoption decision; never invent provenance or resolve a moving branch. Leif owns maintenance with separate agent-assisted review under the owner decision above. Before any adoption document the patch ledger, rollback plan and review limitations, and run full regression gates at that exact revision; no independent human security audit is claimed.

Budgetary estimate, not measured delivery: 3–5 engineering days for the bounded Apple strict-result/ZIP64 candidate and local regressions, plus 2–4 days independent review/backend and interoperability validation; full inspection/format compatibility work is excluded. Reserve at least a half-day monthly security/upstream triage and a release-day regression/rebase budget, with additional work for advisories or OS/backend changes. Review upstream stable/security changes monthly and before release; record applicability, cherry-pick/rebase decisions and rerun the matrix on every candidate update. Do not automatically pull `development` or assume an upstream merge transfers security ownership. Prefer retiring the patch when an upstream immutable revision independently passes the same contract; retirement/adoption still needs owner review. Lack of sustained maintenance/reviewer capacity is a stop condition, not a reason to ship a stale fork.

**Files and scope if separately approved:** the candidate library files above and its unit tests, a bounded `Scripts/ArchiveStrictHostProbe.swift` plus explicit opt-in driver (proposed, absent), and minimal new strict-API assertions in `ClimbingNotebookTests/ArchivePreflightFeasibilityTests.swift` after an approved test-only candidate linkage arrangement. Preserve the existing pinned-library gap observations as baseline evidence, keeping candidate runs isolated instead of rewriting them into assertions about the unchanged package. Any simulator target/package-path switch must be part of the approved test-only integration diff, not a cached-checkout edit. Update this plan, [archive evidence](docs/verification/Archives.md) and Kanban with results; update notices only for actual adopted code. No first-party production sources, persistence, DTOs, validator, destination manager, URL copy, M2 or decoder replacement are included. CF-05F was documentation-only; its evidence is now consolidated in the archive reference.

| Acceptance matrix for an approved candidate | Required result / stop boundary |
| --- | --- |
| Stored and raw-DEFLATE controls, zero/one/five-byte outputs; independent fixed/dynamic/stored DEFLATE blocks and legal final-byte padding | Exact report identity/span/count/CRC and correct completion; empty stored span distinguished from empty DEFLATE output. No reject-all or padding-bit restriction |
| Valid stream plus zero/nonzero suffix and concatenated second stream, at buffers 1/2/7/32 and output boundaries | Throw trailing input even when CRC/size/progress match; distinguish supplied from consumed when END is inside buffer or before a later unread chunk |
| Truncation at every byte, malformed streams, exact-boundary END, zero-output steps, stalled backend, positive short reads/EOF/overlong read/I/O error | Bounded termination, exact-read semantics, no partial success, no out-of-span read; fault-injected library tests, not an alternate validator |
| Wrong CRC/size, understated inflation, buffer zero/negative, checked-counter/offset overflow | Throw before over-budget consumer delivery; exact limits pass. Test UInt64 arithmetic faults without huge allocation, then real >4 GiB counters |
| Pre/mid/final cancellation including empty entry; consumer throws | Same failure propagated with deterministic cleanup, no success result or published payload |
| Central ZIP64 expanded offset zero and zero sizes, local-only ZIP64 signed/unsigned 64-bit descriptor with ordinary central sizes | Enumerate/bind exactly one record, resolve zero by presence, report five (or empty) correctly; compare public metadata, candidate reconciliation and independent expected bytes |
| Ordinary/ZIP64 descriptors, small forced ZIP64, offset-only central extras, placeholders, CRC equal to signature, malformed/duplicate/truncated/missing required fields | One documented consistent interpretation and exact descriptor span; valid producer controls preserved, unresolved ambiguity stops dependent acceptance |
| Entry from another archive, wrong record's expectation (including same-name records), changed span, local/central disagreement | Throw before consumer; ordinal/session identity, not path matching. Two same-name records with their own matching identities remain individually addressable; app duplicate policy rejects separately. Does not claim protection from mutable providers |
| Directory (empty/nonempty payload), stored/deflated symlink | Explicit unsupported-entry-type failure before consumer; never legacy empty/raw-byte shortcut success. Regular-file controls remain valid; no general hard-link detection claim |
| Existing independent large stored/deflated Swift/Python archives and serializer add/remove regressions | Preserve real stored archive/offset boundaries and >4 GiB inflated deflate distinction, exact strict counters/hash/CRC and legacy compatibility; verify no large fixtures committed |
| Apple and alternate backend | Independently verify consumed-input/END semantics before claiming either backend supported by strict API. No Linux pass inferred from iOS; unavailable runner leaves portability unproven |
| Complete directory/header/link/extra/layout gates | Stay Blocked until separately demonstrated/reviewed; candidate extraction success alone cannot satisfy CF-05B/CF-05D or M1 |

After any approved code change run focused archive and full unit/UI suites on reverified iOS 17 and newest installed runtime with new result/log paths, both combined >=70% coverage gates, rejection self-test and `git diff --check`, retaining every migration assertion. If shared harness or dependency behavior changes, free-space preflight then rerun `CF05D_PREFLIGHT=1 bash Scripts/test-archive-boundaries.sh --run-large` against the unchanged baseline as well as the approved isolated candidate driver; the existing script hardcodes baseline provenance and must not be silently repointed. Record candidate provenance and scratch cleanup separately. Failure of valid interoperability, inability to prove backend consumption, expanding patch scope, required format narrowing, missing ownership, hidden enumeration or unsafe counters stops dependent work for owner review. Full 5 GiB/many-asset envelope, device, immutable provider ownership and manifest/type validation remain separate gates.

**Approved implementation boundary:** the explicit owner decision above authorizes creation of the local test-only ZIPFoundation candidate from `22787ffb59de99e5dc1fbfe80b19c97a904ad48d`, the specified source/API delta and isolated host/unit/simulator integration, with Leif maintaining it and separate agent-assisted review. It permits changes to existing decoder plumbing inside that candidate, not another decoder, production linkage, complete inspection/parser expansion, upstream publication, remote dependency adoption or a change to approved ZIP compatibility. The smallest next ready packet is CF-05G: implement and measure only this bounded candidate, stopping on the documented capability/compatibility failures. Approval is not evidence that the proposed backend consumption contract works, nor independent acceptance of CF-05F or earlier Review cards.

**Implementation disposition:** no strict extraction/ZIP64 candidate is implemented or retained. CF-05F's source/design review adds no behavioral acceptance beyond the [archive verification evidence](docs/verification/Archives.md). CF-05G is paused by the owner sequencing decision below, not blocked on file permissions, and must not resume automatically under the earlier candidate approval. The pinned dependency and committed feasibility tests remain unchanged.

#### 21.4.4 Owner-Approved Prototype-First Reset

The following records the accepted CF-07A transient packet. Its reset-on-relaunch/storage restrictions are superseded only for the three explicitly approved CF-07B durable changes in §21.4.5; all other scope boundaries remain in force.

**Owner-accepted implementation (2026-10-29):** Leif's usability testing passed; the accepted CF-07A implementation is committed as `4591da1` and recorded Done in [WIP Kanban](docs/WIP_KANBAN.md). The earlier name/notes mismatch was navigation-versus-reorder confusion, not corruption; that investigation is closed. The current synthetic flow uses stable area/route/pitch IDs and transient notes/order only. Browsing is read-only, with Previous/Next pitch navigation; full-screen Edit Notes and Edit Pitch Order isolate mutations, with explicit completion, native drag handles and accessible move controls only inside order editing. Finish Editing is not a durable save, and the reset-on-relaunch notice remains visible. No persistence or dependency scope expansion is implied.

**Evidence boundary:** [Notebook prototype verification](docs/verification/NotebookPrototype.md) owns decisive measurements, reproduction commands, review conclusions and remaining limits. Both full phone suites still fail the CF-04B migration tests; the prototype's usability acceptance does not override those failures. Owner acceptance closes this disposable prototype only: **M1 remains incomplete**, and ordinary durable save/relaunch remains the smallest subsequent reviewed packet.

**Decision (2026-10-28):** after reviewing the excessive archive-investigation cost and lack of product UI, the owner agreed to pause the fork/archive research, permit a disposable notebook prototype before full M1 acceptance, and resolve the unused working-tree changes. This supersedes the immediate-next-packet sequencing in §§21.4.1–21.4.3, not the retained evidence or release requirements. Leif remains sole human maintainer/developer with agent assistance. Do not resume CF-05G without an explicit reprioritization. Research Review cards are not automatically Done; unresolved capabilities remain feature-specific gates, not universal prerequisites.

**Approved CF-07A scope:** one native SwiftUI, synthetic-data prototype: library/area list -> route detail -> five pitches -> editable plain-text notes -> pitch reorder. Follow §§4.1–4.4 for the intended interaction model, using a compact readable route workspace rather than a dashboard. Allow enough editing to assess flow; do not scaffold all future screens or import/backup buttons that imply working features. This accepted prototype is not durable M2 implementation or permission to store personal data.

**Architecture, files and data boundary:** replace the foundation placeholder in `ClimbingNotebook/App/ClimbingNotebookApp.swift` with the prototype entry view; add only the small feature views and transient fixture/edit state needed under `ClimbingNotebook/Features/NotebookPrototype/`. Add focused state tests under `ClimbingNotebookTests/` and navigation/edit/reorder UI tests under `ClimbingNotebookUITests/`; update [prototype verification](docs/verification/NotebookPrototype.md) and Kanban with actual results. Exact file splits follow source inspection, not speculative coordinator/service scaffolds. Transient area/route/pitch values use stable fixture IDs, ordered pitch collections and plain-text fields only. Reorder updates the whole transient sibling order; fixture reload/relaunch resets edits. No persistence entities, schema changes, DTO/manifest system, archive dependency changes or network/API contracts are introduced. The only new interface is local view-to-state editing; no hosted or public API exists. Keep the existing persistence harness and every migration assertion active.

**Truthful state and edge cases:** display a persistent `Prototype - changes reset on relaunch` notice; never show `Saved on this device` or an offline-ready claim. Use synthetic examples only. Include empty area/no-pitch presentation, long and Unicode text, keyboard dismissal/navigation, five-pitch scrolling, stable selection after editing, reorder boundaries and accessible Move Up/Down. Do not silently imply that transient state is a recoverable draft. Do not connect to LibraryStore/LibraryGenerationManager or operate on existing diagnostic stores. Backup/restore, URL copy, share intake and media remain unavailable.

**Acceptance and owner testing:** the simulator must launch the flow on iOS 17 and newest installed runtime, support opening a route, editing notes and changing pitch order without crashes or false saved indicators. Run focused tests, full unit/UI suites, both >=70% combined first-party coverage gates, rejection self-test and `git diff --check`, with new evidence paths; report the two known CF-04B failures separately and do not weaken/skip them. No large ZIP rerun is needed unless archive/shared harness/dependency code actually changes. Leif reviews navigation, information density, pitch editing/reordering, keyboard behavior and readability with large text; report usability feedback before expanding the prototype or wiring durable storage. Tablet/physical-device checks are reported as executed or unrun, never inferred.

**Subsequent order and stop rules:** after the prototype review, prioritize a narrowly scoped ordinary durable save/relaunch vertical slice before valuable user data is accepted. CF-04B's failed teardown barrier leaves generation replacement/migration recovery unproven; it does not establish ordinary save/reopen data loss or a need to switch frameworks. Resolve that capability before depending on it, not before every UI change. Archive inspection/extraction gaps gate production restore; URL-policy gaps gate URL copying. Retain these requirements for release, but timebox any resumed feasibility investigation to half a day/one day with a stated decision and evidence target. On expiry, report the bounded finding and replan rather than automatically creating another research prerequisite. No release scope reduction, unsafe extraction fallback, persistence-framework switch, publication or commits are authorized by this reset.

#### 21.4.5 CF-07B Approved Ordinary Durable Save/Relaunch Slice

**Approval boundary (2026-10-29):** Leif explicitly approved this packet after reviewing its risks, alternatives and recommendation, including explicit saves rather than autosave, isolated schema/store adoption and retained incomplete initialization without repair UI. CF-07B was unused in the inspected repository and tracked plan/board history. CF-07A remains accepted and Done; its interaction model is retained. Approval authorizes only this synthetic fixture slice, not all of L2 or M1 acceptance. Leif is the sole human maintainer/developer; agents assist implementation and separate review. No further feasibility prerequisite is proposed.

**Implementation decisions:** the isolated `NotebookSchemaV1` uses version `1.0.0` (in its own namespace), deterministic UUID mappings and ordinary explicit saves. iOS 17 requires inserted records before relationship assignment; after a failed mutation, process pending changes, rollback and replace the context on the same container before retry. No live model escapes the store, and this is not container teardown/generation recovery. Note dirty/no-op detection compares UTF-8 bytes, not Swift canonical string equivalence. Debug-assert configuration, not the project's undefined `DEBUG` conditional, gates generated UUID test namespaces and fault controls. Separate internal implementation review found a no-op acknowledgment issue; the revision-based fix and regression cover all three commands. Final verification and remaining gaps belong in `docs/verification/NotebookPrototype.md` and `Persistence.md`; owner acceptance remains required.

**Implemented review handoff (2026-10-30):** final selected-phone suites each executed 67 tests, 65 passed and only the two existing CF-04B assertions failed; both combined coverage gates passed at 1558/1595 (97.68%). iPad (10th generation)/iOS 26.4 UI passed 10/10 with orientation-support warnings, retained without settings changes. Separate final native-layout review found no material defect. Read navigation uses stable IDs/plain snapshots rather than nested bindings; native ScrollView reading and a fixed title/keyboard header preserve accepted edit separation while resolving an iOS 17 layout loop and focus-dismissal issue. Largest-text controls remain scroll-accessible, not capped. Decisive evidence and remaining gaps are consolidated in existing verification documents; implementation is ready for Leif's testing, not owner-accepted/Done. No migration assertions, diagnostic stores, archives or dependencies changed.

**Inspected baseline:** clean `main` at `54fed64`, following accepted prototype commit `4591da1`. `NotebookPrototypeView` owns transient fixture arrays; notes write through while typing and reorder changes whole pitch values immediately. `LibrarySchemaV1` contains only Area/Route; `LibraryStore` is an explicit-save diagnostic harness and `LibraryGenerationManager` is a replacement/recovery harness. Neither is a production save boundary. Preserve both and every migration assertion unchanged. Reverified `/Applications/Xcode.app/Contents/Developer`, Xcode 27.1 (`27A9275`), iPhone 15 Pro/iOS 17.0 `A1A7DBEF-BA07-4904-9CE9-3C6B1F5A3492`, iPhone Duo/iOS 27.1 `AD5A310D-DBEB-497C-8921-1A49BC52C3C6`, and iPad (10th generation)/iOS 17.0 `D287E486-8D5E-4268-97A1-3AEAD2847683`. These are environment observations, not newly executed test evidence.

**Bounded deliverable:** retain Example Granite, Example Meadow, Paper Skyline's five pitches and Unwritten Line. Only route-note body, pitch-note body and full sibling pitch order are mutable. Read-only browsing and Previous/Next never mutate or reorder. Explicit note/order editors remain full-screen native SwiftUI workflows with drag handles and accessible Move Up/Down. No area/route/pitch creation or deletion, renaming, custom sections, search, media, import, archive, replacement, URL copying or share intake; no speculative service/coordinator hierarchy, dependency changes or framework switch.

**Small persisted model:** introduce a separately named fixture-slice VersionedSchema and migration plan, rather than changing `LibrarySchemaV1`, inventing a V2 migration or claiming the diagnostic schema is a released predecessor. Assign its actual initial version identifier during implementation after checking for collisions; no migration stages or adoption of old stores are required. Use the following narrow subset of §6, not a serialized UI array/blob:

| Record | Stored values / invariant |
| --- | --- |
| Area | Unique UUID, name, inverse routes. Two deterministic fixture IDs; empty area is valid. |
| Route | Unique UUID, area relationship, name, grade/style display values and route revision. Must have exactly one valid area. |
| Pitch | Unique UUID, owning route/inverse pitches, zero-based order, display name, grade and description (the prototype's pitch notes). Notes belong to the pitch ID, never the visible position/name. |
| NoteSection | Unique UUID, owning route/inverse notes, `general` kind, title, body and order 0. Exactly one per fixture route, including the initially empty note. The current combined route prose stays one general section; do not split or invent approach/descent/gear editors. |
| FixtureState | One fixed unique UUID and fixture-format identifier, committed with initial fixtures. Distinguishes a fully initialized store from empty/partial initialization; it is not a generation journal or backup format. |

Use explicit inverses and boundary validation for ownership. Fixed UUIDs replace transient word IDs through a deterministic fixture mapping; existing readable accessibility IDs can remain UI aliases, not persistence identity. No random IDs on each launch. Keep view snapshots as plain values adapted from these records; no live SwiftData models in editor bindings. Unimplemented §6 fields/entities remain absent. Persistent identifiers and relationships are the future migration input, not a promise that this limited schema is already the final product schema.

**Store location and initialization:** use only app-private `Application Support/NotebookFixtureSlice/`, with a single fixed generation-shaped path `Libraries/<fixed-slice-UUID>/notebook.store` and its SQLite sidecars. This is a packet-specific namespace under the app container, not Caches/tmp, App Group storage, an existing diagnostic root or an active-generation descriptor. It is an explicit bounded staging of §8.1's eventual layout; later adoption into the complete library requires separate planning, not an implicit move. No `LibraryGenerationManager` call, descriptor/replacement journal, live-store copy, migration, overwrite or diagnostic cleanup. CloudKit is disabled, autosave is disabled on every write context, normal OS device backup is not disabled, and new owned directories/files use the §8.1 protection direction (`completeUntilFirstUserAuthentication`). Physical-device protection/backup behavior remains unverified until tested.

Only an absent slice root permits first initialization. Exclusively create that namespace; an existing empty/unrecognized directory is not proof of first launch. Seed the entire fixed graph and FixtureState in one explicit database save, then validate/read snapshots before presenting content. A missing record, duplicate ID, wrong owner, invalid sequence, missing marker, corrupt/incompatible store or missing main store in an existing root is a load failure, not a reason to reseed, repair or create a new library. Do not open a missing existing store with create enabled. Repeated launches load exactly the saved graph and never apply fixtures as defaults over saved content. Bootstrap failure retains files and shows an initialization error; only the same still-owned, verified new initialization session may retry its failed transaction after rollback. After interruption/relaunch an incomplete root fails closed with retained-data guidance, not an automatic reset. This small slice does not provide an incomplete-initialization repair tool.

**Data/API boundary:** one small main-actor `NotebookStore` owns its container/context and serializes the slice's load and mutation operations. Reuse only the demonstrated SwiftData configuration, explicit-save and rollback patterns from `LibraryStore`, not its sample insertion API or generation behavior. Keep UI load/save state in the existing feature state file; introduce no additional coordinator/repository/protocol layers. Proposed local operations (names can follow implementation conventions) are `load() -> [area snapshots]`, `saveRouteNotes(routeID, expectedRevision, text)`, `savePitchNotes(routeID, pitchID, expectedRevision, text)`, and `savePitchOrder(routeID, expectedRevision, orderedPitchIDs)`. Successful commands return the acknowledged updated route snapshot/revision, not a success boolean followed by a fallible fetch. Validate and prepare the returned value before commit so no post-commit fetch is misreported as an unsaved mutation.

Fetch by UUID, verify ownership and expected persisted route revision before mutation. Every changed command increments that revision once, in the same save as its text/order update. Reorder must contain each current sibling UUID exactly once; reject missing, duplicate, extra and foreign IDs before writing, then assign contiguous order to the entire sibling set in one save. No-op finish closes without a new save/revision or invented save event. Reject stale revision with a review/reload conflict while retaining the working buffer; never automatically retry against a newer revision or overwrite it. A user can explicitly reload the latest acknowledged snapshot, confirming loss of changed working content, then reapply their edit. No public/hosted API or network operation is introduced.

**Editing and acknowledgment semantics:** this packet proposes an explicit-save exception to §4.3's eventual debounce/focus/scene autosave, without changing that broader product requirement. Opening either editor copies the last acknowledged snapshot and route revision into a local working buffer. Typing/moving affects only that buffer, not browse snapshots or persistent models. Keep `Finish Editing` for notes and `Done` for order as the save-and-close actions, with visible explanatory text that they save on this device; remain open until a changed save succeeds. Hide Keyboard only changes focus. Show `Unsaved changes` while dirty, `Saving` during the command and a non-color `Not saved - retry` error on failure; offer Retry in place. Disable duplicate save, discard and dismissal while the command is in flight.

Add Cancel to both editors. Unchanged Cancel closes directly; changed Cancel requires explicit Discard Changes confirmation and otherwise keeps editing. Disable interactive dismissal while dirty; browsing Back and Previous/Next are unavailable behind the full-screen editor. No dismiss, navigation, focus-loss or scene-transition callback silently commits or discards. Backgrounding retains the in-process buffer but does not promise a saved draft; termination can lose any change not acknowledged. An editor notice says `Unsaved changes are lost if the app closes. Finish Editing/Done saves on this device.` Failed saves rollback context mutations, retain entered text/order and the base revision, leave acknowledged browse state unchanged, and expose a truthful retryable error. Retrying the same failed transaction must not duplicate fixtures, notes or pitches. Recoverable storage errors do not close the editor or claim success. A failed load shows a distinct unavailable-store screen with Retry, no empty areas list and no reset/delete action; a later failure with existing snapshots labels them as last-loaded/unavailable for editing, not freshly saved.

Replace the global reset warning only once the durable path is implemented with `Synthetic notebook - explicit saves stay on this device. Not for personal data; backup/restore unavailable.` Retain the not-climbing-guidance notice. A route-scoped `Saved on this device` acknowledgment is justified only after its successful explicit database save (including validated fixture initialization); on later launches use `Loaded from this device` after successful validation, not a fabricated new save event. A loaded unchanged editor can close with no new saved toast. Never show success while dirty, saving, failed or unavailable, and never imply backup, full offline-content integrity, migration safety or every-keystroke durability.

**Edge cases/accessibility:** empty areas and no-pitch routes remain valid, with route notes editable and no reorder action for an empty sibling set. Allow empty note bodies and preserve exact Unicode/newlines without trimming/normalization. Apply §6.2's proposed 1 MiB UTF-8 per prose field as this packet's explicit limit: reject oversized text visibly at save, retain it for correction, never truncate. Test boundary bytes, combining characters, emoji and long multiline text. Preserve selection by stable pitch ID across saves/reorders, not index. Keep native TextEditor, interactive keyboard dismissal/Hide Keyboard, readable errors and confirmations, wrapping finish/retry/cancel controls, Dynamic Type, VoiceOver labels and accessible move actions. Request focused Stitch design review with synthetic examples only when implementing the changed save/error/confirmation controls if available; generated output is input, not web UI or permission to broaden scope. Tool availability does not gate implementation; retain established native patterns and report unavailability briefly.

**Concrete file changes after approval:**

| File | Bounded responsibility |
| --- | --- |
| `ClimbingNotebook/Models/NotebookSchemaV1.swift` (new proposed name) | Separate versioned slice schema/migration plan and only the records above. Recheck name/version availability before adding. |
| `ClimbingNotebook/Services/Persistence/NotebookStore.swift` (new) | App-owned path/bootstrap policy, explicit load/validation and three narrow save commands; small internal injectable failure seams, not a general persistence framework. |
| `ClimbingNotebook/Features/NotebookPrototype/PrototypeNotebook.swift` | Fixed UUID fixture mapping, plain snapshots, minimal observable load/save state and independent editor buffers/revisions. Keep whole-value reorder helpers. |
| `ClimbingNotebook/Features/NotebookPrototype/NotebookPrototypeView.swift` | Load/error presentation, existing browse flow, buffered explicit-save editors, cancel/discard/retry/conflict feedback and truthful notices. |
| `ClimbingNotebook/App/ClimbingNotebookApp.swift` | One shared slice-state/store lifetime for the app's windows; no duplicate seed/mutation owners. |
| `ClimbingNotebookTests/NotebookPersistenceTests.swift` (new), `NotebookPrototypeTests.swift` | On-disk store/bootstrap/fault tests and focused state/buffer/order/revision cases. |
| `ClimbingNotebookUITests/NotebookPrototypeUITests.swift`, `FoundationLaunchTests.swift` | Replace relaunch-reset expectations with genuine save/terminate/relaunch assertions; preserve navigation/explicit-editing coverage. |
| `README.md`, `SYSTEM_DOCS.md`, `docs/verification/NotebookPrototype.md`, `docs/verification/Persistence.md`, this plan and `docs/WIP_KANBAN.md` | Current behavior, decisive results/reproduction, limits, scope and status in their existing authoritative locations, not a diary. |

The project uses synchronized source groups; no project/signing/target/dependency edits are expected. Leave `LibrarySchemaV1.swift`, `LibraryStore.swift`, `LibraryGenerationManager.swift`, migration tests and archive code untouched. Test fault controls must be internal/unit-injected or Debug-only UI-test launch controls scoped to a generated test-store namespace, never an arbitrary path or a production reset button. Use a distinct test store token per UI test; reuse that token for terminate/relaunch within the test. Do not reset on every launch or let fault/fixture controls touch the ordinary slice or retained diagnostic stores.

**Tests and acceptance:** implement real temporary on-disk tests for exact fixed UUID/ownership/value/order round trips, explicit autosave-off configuration, initialization transaction/marker, repeated load/no duplicates/no reseed, empty cases, long/empty/Unicode byte preservation and size limits. Verify all invalid reorder sets, whole multi-index moves, revision conflicts/no-op completion, cancel/discard behavior and failure -> unchanged acknowledged state -> retained buffer -> successful retry. Inject failures immediately before the real save to verify rollback of staged mutations, plus real corrupt/missing/unwritable store cases where deterministic; do not present injected failures as proof of actual ENOSPC. Existing roots/failed loads must retain existing bytes and never turn into successful empty fixtures. Reopen tests prove ordinary readback only; do not perform unsafe filesystem cleanup based on assumed context teardown or reopen the CF-04B lifetime investigation.

Real XCUITests must save route notes; save distinct notes on at least two pitches; reorder the full five-pitch set; terminate the app process; relaunch with the same store token; and assert exact note ownership, identities, full displayed sequence and route notes. Repeat launches to prove fixture counts do not grow/reset. Exercise failure/retry with no false success, failed load with no empty-library fallback, cancel/discard and termination before acknowledgment leaving prior saved data, unchanged finish, read-only Previous/Next and explicit editing separation. Unit assertions alone or in-process container recreation are not substitutes for those UI relaunch checks.

**Owner-directed verification cadence (2026-10-30):** supersedes this packet's original requirement for separate focused and full runs on both phone runtimes. During development run affected focused tests on one phone, iPhone 18 Pro. Run the full unit/UI suite once on each selected phone for final phase acceptance; a completed final full run supersedes a separate focused run on the same unchanged code. After a fix, rerun affected checks and replace only invalidated acceptance evidence, not every suite after every edit. Reserve tablet iteration checks for layout-related changes. Use the selected Device Hub destinations: iPhone 15 / iOS 17.0 (`FB17E53E-C6B7-419C-8D52-6205AD037B52`), iPhone 18 Pro / iOS 27.0 (`087CDB20-DD15-43C5-8CBB-69D32A5A7478`), and iPad (10th generation) / iOS 26.4 (`A6DB0B3A-AD70-435D-AC6C-46B370A06BA7`), reverified 2026-10-30 after the owner configured Device Hub. iPhone Duo is removed from future suites; retain historical device/runtime evidence without treating it as selected-device acceptance. Do not silently provision another simulator or claim iOS 27.1 coverage.

Discover commands from the scripts before execution. Reusable invocation is `SIMULATOR_ID=<verified-UUID> RESULT_BUNDLE_PATH=<fresh-path.xcresult> bash Scripts/test-ios.sh -quiet -test-timeouts-enabled YES -maximum-test-execution-time-allowance 300 -collect-test-diagnostics never`; focused checks select only affected test methods/classes with `-only-testing:`. Require fresh result/log paths, both final phone `bash Scripts/check-coverage.sh <fresh-result.xcresult>` >=70% combined first-party gates, `bash Scripts/check-coverage.sh --self-test`, and `git diff --check`. Check phone/iPad, keyboard and largest Dynamic Type layouts/screenshots for modified controls; report VoiceOver/device/native-drag checks actually performed and remaining gaps. Keep every migration assertion active and report failures honestly. No large archive rerun is needed with untouched archive code/dependencies.

The latest recorded baseline is 42/44 tests on each phone, two CF-04B failures, combined coverage 865/895 (96.65%) each, iPad UI 6/6; this proposal does not claim reruns. Keep both named migration assertions active and distinguish their actual per-runtime failures: iOS 17 ModelContainer barriers; latest iOS 27.1 failed recovery 26-versus-23 bytes and migrated reopen ModelContext barrier. Any new failure is not automatically the known baseline. Ordinary-slice tests must pass; full-suite failures and coverage results must be reported without claiming migration acceptance. Obtain a separate internal agent-assisted implementation review (no Agent Manager session), fix material findings and rerun affected checks. Move implemented CF-07B to Review for Leif's testing, not Done until his acceptance. Leave all changes uncommitted.

**Risks and stop rules:** explicit save is a deliberate bounded departure from eventual automatic persistence and must be owner-approved with these cancellation/termination semantics. SwiftData ordinary-save behavior on both runtimes must be demonstrated, not inferred from CF-07A or diagnostic results. Startup interruption may leave a retained incomplete namespace with no repair UI in this slice; never delete it to make launch pass. A future schema/full-library adoption requires its own migration/recovery approval. Physical-device file protection, actual full-disk behavior, crash/power-loss durability and full accessibility remain limits unless measured. If implementing this slice requires destructive recovery, a persistence-framework switch, speculative layering or changes to existing diagnostic stores/tests, stop the dependent change for an owner decision. Do not restart archive research, CF-04B process-boundary work or the closed navigation-versus-reorder investigation. M1 and release gates remain incomplete; no tool installs, paid services, visible sessions/worktrees, signing/settings changes, publishing, commits, pushes or PRs are authorized.

#### 21.4.6 CF-07C Approved Bounded Reading and Navigation Alignment

**Assignment and approval boundary (2026-10-30):** the owner approved `DESIGN.md` and directed continuation into the next plan phase, then explicitly selected `Approve CF-07C (Recommended)` after reviewing this packet. CF-07B remains Review pending Leif's testing; this direction does not establish its acceptance. This is an L2-aligned increment on the existing synthetic fixture slice, not complete-library adoption, L2 completion or a persistence change. The approved design supplies navigation, interaction, accessibility and visual guidance; its indexed Stitch screenshots are layout references, never executable specifications.

**Architecture and behavior:** retain the current app/store/state lifetime, stable identities, plain snapshots and three explicit-save commands. Improve only the existing Library -> Area -> Route -> Pitch reading flow: show the complete General note in the route workspace instead of requiring a truncated preview; provide a discoverable jump to the pitch list; keep Previous/Next reachable outside long scrolling pitch notes; identify owner and field in focused note editors. Preserve all five pitches, empty-area/no-pitch cases, separate note/order editing and selection by stable ID. Reading and navigation must never mutate notes, order, revisions or save acknowledgments. Keep explicit Finish Editing/Done, Cancel/discard, retained failure buffers and Retry; automatic saving is a later functional packet, not visual styling.

**Visual boundary:** apply native system typography and the approved semantic palette only to touched reading/editor controls. Allow wrapping and accessibility-size scrolling, respect safe areas/keyboard, retain meaningful labels and non-color status. Review current indexed Library, Area, Route, Pitch and Note Editor screenshots before editing their corresponding layout. Do not reproduce simulated handlers, invented fields or the illustrative three-pitch seed. Do not create new Approach/Descent/Gear sections from the combined General prose, add unavailable Sources/Media/Inbox/Settings destinations, or restyle unrelated screens.

| File | Proposed change |
| --- | --- |
| `ClimbingNotebook/Features/NotebookPrototype/NotebookPrototypeView.swift` | Bounded reading/navigation layout, editor context and accessible semantic styling. Keep small view helpers here unless genuinely shared. |
| `ClimbingNotebookUITests/NotebookPrototypeUITests.swift` | Full-note reading, long-content navigation, stable pitch selection and large-text/dark-mode regressions; retain durable relaunch/error/discard assertions. |
| `ClimbingNotebookTests/NotebookPrototypeTests.swift` | Only necessary selection/navigation regressions if state logic changes; no new speculative layer. |
| `README.md`, `docs/verification/NotebookPrototype.md`, this plan, `DESIGN.md`, `docs/WIP_KANBAN.md` | Actual behavior, approval boundary, decisive evidence and task status. |

**API contracts and data models:** no new API, schema, store format, fixture identity, migration, namespace or initialization policy. Leave `NotebookSchemaV1`, `NotebookStore`, fixture definitions, diagnostic stores, migration assertions, archive code, dependencies and signing/project settings unchanged. General creation requires a separately reviewed expansion of fixture-only ID mapping and validation; this packet must not weaken those checks or accept personal data.

**Acceptance and edge cases:** full route prose is readable without entering editing; a long five-pitch route has discoverable pitch access; Previous/Next remains reachable with long notes and disables at boundaries. Notes/identity/order and loaded-versus-saved state stay unchanged after read-only navigation and relaunch. Preserve Unicode, empty bodies, long names, error/retry/discard behavior and all existing persistence tests. Validate default/largest Dynamic Type, light/dark, keyboard and selected iPad layout; report actual VoiceOver/native-drag/device checks without inference. Follow §21.4.5's owner-directed focused iPhone 18 Pro then final two-phone unit/UI cadence, both combined >=70% coverage gates, rejection self-test and diff check. Retain/report the two known CF-04B failures and tablet orientation warnings without weakening assertions/settings. Obtain separate internal implementation review before moving to Review; owner acceptance is still separate.

**Stop rules:** if layout requires changing save semantics, generalized record creation, store adoption/migration, new dependencies or unrelated screens, stop and revise the packet for approval. Do not restart paused archive or migration research. No commits, publication, new sessions/worktrees or tool installation are authorized. CF-07C is approved for implementation and tracked separately from CF-07B's pending acceptance.

**Implemented review handoff (2026-10-30):** full General reading, pitch jump, pinned adjacent navigation and contextual note editors are implemented without model/store/state/dependency changes. Large-text review required a compact horizontal Previous/Next row, wrapping pitch metadata and a concise persistent synthetic/not-personal-data notice; the full original save/device/no-backup disclosure remains its accessibility label and visible Library footer. This is a presentation adjustment, not relaxed storage/safety semantics. System typography and scoped action tint are used; custom fonts are not adopted. Current-phone full 65/69 and minimum-phone full 66/69 retained known migration assertions and exposed UI/helper/disclosure failures; final all-UI current-phone 12/12 and minimum launch 1/1 revalidate corrected cases, not a fabricated new full-suite pass. Selected tablet changed-layout 3/3 passes with existing orientation warnings. Both full coverage gates and final current-phone UI coverage (90.57%) pass; separate final review found no new material defect. Exact evidence and remaining dark-mode/VoiceOver/keyboard-open/device limits are in [notebook verification](docs/verification/NotebookPrototype.md). CF-07C moves to Review, not Done; CF-07B acceptance and M1 remain unresolved.

### 21.5 Later Implementation Packets

When separately assigned to continue, use the same WIP-one and evidence rules. Re-read current code and the prior report; do not repeat completed foundation work. Implement the actual approved feature flows, not just protocol declarations or service stubs.

| Packet | Backlog | Required end-to-end checkpoint |
| --- | --- | --- |
| L2: Core notebook | CF-07 through CF-11 | Five-pitch route, common/custom notes, reorder, recoverable save errors, literal local search, accessible actions, acknowledged data retained after restart. |
| L3: Media and recovery | CF-12 through CF-17 | Immutable originals/PDF viewing, captions/tags/owners, shared-reference deletion safety, portable full export, hostile archive rejection and old-or-new generation recovery. |
| L4: Intake/share/URL review | CF-18 through CF-21 and CF-20A | Real Files/Photos/paste and extension inbox, receipt idempotence, editable manual review, explicit page/selected-media copying under proven policy, provenance and originals survive backup. |
| L5: Reliability | CF-22 and CF-23 | Full acceptance matrix, real device/offline/accessibility coverage, resource/large-library measurements, no known critical data-loss issue and real coverage gate. |
| L6: Release preparation | CF-24 and CF-25 preparation only | Accurate docs/privacy/attribution/licenses and a release checklist. TestFlight upload/App Store submission, signing changes and publication still require explicit authorization. |

Run the relevant unit/integration/UI checks for every packet and the full local suite before milestone handoff. Required failures are work to fix, not reasons to skip tests or lower coverage. This assignment creates no ongoing monitoring schedules, remote publication, new visible sessions or authority to spend money.
