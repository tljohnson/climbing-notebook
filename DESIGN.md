# Climbing Notebook Design

Updated: 2026-11-09

## How to Use This Document

This is the owner-approved product and screen design reference. Start with the overview and navigation map, then read the affected screen and shared rules. Screen descriptions express intended design, not proof of implementation or permission to build every depicted feature.

- [README](README.md#current-capabilities) owns what works today; source establishes actual behavior.
- The [technical plan](ClimbingNotebook-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md), especially §21.6, and [image contract](Image-Supported-Notebooks-FeaturePlan.md) own implementation scope, validation, data compatibility and file ownership. Preserve these boundaries when applying the design.
- This document owns the approved composition, including written-sections-first Route Details, explicit editor Save/Cancel and About & Data placement. Older mockups and earlier plan presentation directions do not override these decisions. Changes to protected behavior or schema require separate authorization.
- [Visual references](#reviewed-visual-references) illustrate composition; written specifications resolve generated artifacts. [Open decisions](#open-design-decisions) are not assignments to invent behavior.
- Follow [native-interface-design](.kilo/skills/native-interface-design/SKILL.md) and the [MVP delivery policy](ClimbingNotebook-Offline-iOS-Notebook-Architecture-and-Implementation-FeaturePlan.md#2168-mvp-delivery-and-verification-policy). Keep verification results in existing evidence topics, not this document.

## Product Overview

Owner-approved product direction: a **reading-first notebook**. Preparing and editing material supports the main task: finding and consulting the right information while climbing. This overview describes the intended product, not a claim that every capability is implemented; README owns current capabilities.

Climbing Notebook helps a climber prepare and carry their own climbing reference notebook.

Before a climb, they organize routes into areas, write notes, and collect reference material such as screenshots and topos. For multipitch routes, they can organize information into an ordered sequence of pitches. Routes do not require pitch entries.

While climbing, they can quickly find a route, consult its reference material and complete notes, and move between pitches. Saved content remains available without connectivity. The interface prioritizes reading space, clear location within the notebook, and easy access to the next piece of information.

They can deliberately add or revise information as needed. Reading and navigation do not change saved content. The app preserves what the climber entered or collected; it does not generate or verify climbing advice.

The intended complete product also supports collecting PDFs and text, reviewing imported material, and exporting and backing up the notebook. Those capabilities must be distinguished from what is implemented today.

Climbing Notebook is a working name, not a settled brand. Prefer brand-neutral functional copy where the app name is unnecessary.

## Navigation Map

The **Library is the Home screen**: the app opens directly to the area list, without a separate dashboard. When local route search is implemented, it provides a shortcut into the hierarchy from the Library; this decision does not claim search is available today.

```text
Library -> Area Details -> Route Details -> Pitch Details
Library -> About & Data -> Separate Example Notebook
Route / Pitch -> Image Reference Reader -> Read-only Notes Sheet
Route / Pitch -> Add References / Manage References
Hierarchy actions -> Name / Note / Order Editor or Deletion Confirmation
```

Back/Done returns to the actual originating context. Pitch Previous/Next changes the selected pitch, not its order. The pitch's Route References link returns to the originating route's References section without pushing a duplicate route screen. Editors isolate uncommitted changes from reading. Examples stay separate; conditional retained legacy content remains read-only and must stay accessible without initializing, importing, resetting or replacing it.

## Reading Screens

### Library Composition Direction

The owner-supplied revised Library mockup establishes the composition direction, not implemented functionality or final specifications for every control:

- Compact app-name header with secondary utility access.
- `My Areas` heading and prominent `Add Area` action above the area list.
- Readable area rows with an icon tile, full area name, route count and navigation indicator. Selecting an area opens its routes. The mockup also illustrates an entered-pitch count; whether to include that summary remains undecided.
- Search and Inbox are intentional future placeholders in the mockup, not authorization to show nonfunctional controls in the app. Search covers area and route names when implemented. Inbox behavior remains future intake scope.
- No Active badge or unstructured descriptive subtitle is established by this composition. Example content in the mockup does not authorize automatically populating the ordinary notebook.

Tile selection, tags and aggregate pitch counts remain [open decisions](#open-design-decisions), not inferred metadata or schema fields.

### Area Details Composition Direction

Purpose: find and open a route within the selected area. The owner's revised Area Details mockup supplies the composition reference; this is design guidance, not a claim of implementation or authorization to change saved-data behavior.

- Navigation bar: Back to Library and an overflow menu accessibly labeled `Area Actions`.
- Content header: full area name and entered-route count, with prominent `Add Route` alongside. The area name is not repeated as a second visible navigation title. For long names, narrow widths or larger text, wrap the name and stack the action rather than shrinking or truncating essential content.
- `Routes` section below the header, showing routes in saved sibling order. Each whole row opens Route Details and contains the full route name, optional icon tile and a secondary summary of entered grade, style and pitch count. Omit unknown grade/style and unused separators; zero pitch records means `0 pitches entered`, not an inferred route type. Tile selection/classification remains a future decision.
- Area Actions contains `Rename Area`, `Reorder Routes` and `Delete Area`; reordering is applicable when routes exist. These map to the existing separate editing workflows, not inline changes on the reading screen. Nonempty-area deletion stays blocked; do not offer an unavailable route-move workflow.
- Empty area: `No routes yet`, with the header's `Add Route` still available. Loading/unavailable states must not masquerade as an empty area.
- No separate area-level search, statistics panel, area description or gallery is established by this composition. Planned Library search provides direct area/route lookup. Use `Routes`, not `Logged Routes`; the list is notebook content, not an ascent log.

### Route Details Composition Direction

Purpose: consult information for the whole climb and find the relevant pitch. Owner-approved populated composition for the intended complete product: **General, Approach, Pitches, Descent, Gear, References, Sources**, in that order on one continuous reading screen. Written sections lead; references remain directly reachable through a section shortcut.

- Navigation returns to the originating context, with secondary Route Actions in an overflow menu. The compact content header shows the full route name, area context and entered grade/style/pitch count without a repeated route title or inferred badges.
- Readable section shortcuts jump within the continuous screen, not switch tabs or hide content. The approved mockup uses wrapping shortcuts, including Sources; labels must remain complete as text grows.
- General, Approach, Descent and Gear show complete notes with secondary `Edit Notes` actions. Do not collapse, summarize or split existing General prose into new sections automatically.
- Pitches shows neutral ordered position markers, full names and entered metadata, with `Add Pitch` at the heading. No inferred active/crux badge. Reordering remains secondary rather than a large permanent row.
- References follows Gear, with uncropped identification previews, fully wrapping captions and `Open Reference` below each caption. No controls obscure the original preview. The section provides `Add Reference`; supported types and intake remain governed by approved feature scope.
- Sources follows References as a distinct, quiet provenance list. User-authored statements such as `verified at crag` are preserved as content, never promoted to app-issued assurance. Mockup climbing material is illustrative, not bundled or verified guidance.

Future custom-section placement, empty-section behavior and Sources interactions remain undecided. The approved image is a populated composition reference, not pixel measurements; use native semantic typography and adapt to narrow widths and larger text.

The current bounded image contract and implementation place route images before General notes/pitches; that is not the intended target. Applying the approved composition requires separately scoped work, not automatic prose splitting, schema changes or metadata inference.

### Pitch Details Composition Direction

Purpose: consult one pitch and move through the route's saved sequence. Owner-approved populated composition: identity, compact pitch navigation, complete Notes, Pitch References, then a distinct Route References link.

- Navigation bar returns to the originating route and provides a secondary Pitch Actions overflow menu. No account/profile control or repeated pitch title.
- The scrolling identity card shows full area/route context, authored pitch name and entered grade/length. Without an authored name, use the position-based display fallback without storing it as a name.
- A compact strip below identity shows `Previous Pitch`, `Pitch 2 of 3` (using actual position/count) and `Next Pitch`. Only this strip pins beneath the navigation bar as identity and content scroll away. Disable unavailable directions at sequence boundaries. Wrap/reflow for large text; do not truncate neighboring names or repeat the position elsewhere. Navigation does not save or reorder pitches. The mockup's pinning explanation is a design annotation, never app copy.
- Notes are complete plain text with a secondary `Edit Notes` action. Preserve paragraph breaks; no collapsed preview or inferred structured fields.
- Pitch References contains only pitch-owned attachments, with an `Add Reference` action, uncropped identification previews, fully wrapping captions and separate `Open Reference` actions below captions.
- The quiet `Route References` row identifies shared material and returns to the originating route's References section, rather than pushing a duplicate Route Details screen. It does not copy or reassign those references to the pitch.
- Pitch Actions contains `Rename Pitch` and `Delete Pitch`; reordering belongs at route level. Editing remains separate from reading. No Save/Cancel, routine storage status or extra section-shortcut strip on this reading screen.

Use the approved mockup as a composition reference, not fixed typography or spacing measurements. Boundary/empty/error states and reference-reader interactions require their own specifications; the populated mockup does not establish them all.

### Image Reference Reader Composition

Owner-approved composition: a full-screen image reader and a native read-only Notes sheet over that same reader. PDF page navigation remains open.

- One compact top bar provides `Done`, concise route/pitch owner context and a viewing-tools overflow menu. No outer navigation bar or nested reader card. Done returns to the exact originating screen.
- A compact identity region shows the fully wrapping caption and actual `Image 1 of 2` position. Owner context also wraps/reflows when needed; never shrink essential text to force a row.
- The original image occupies the main viewport, initially aspect-fit without cropping or distortion. Preserve original pixels/colors; no controls, captions, gradients or app-generated annotations overlay it. No forced always-dark appearance is established.
- Controls outside the viewport provide labeled `Previous Image`, `Next Image`, `Fit Width` and `Notes`. The approved phone mockup uses two footer rows; adapt to available width and text size, keeping Fit Width on one line when practical. Disable unavailable image directions. The viewing-tools menu also provides Fit Image and accessible zoom/pan alternatives alongside gestures. No arbitrary zoom cap or auto-dimming behavior is approved by the mockup.
- Image navigation stays within the route-owned or pitch-owned collection that opened the reader; do not silently combine them. Reading never modifies originals, captions, attachment order or notes.
- Notes opens a native sheet with `Pitch Notes` or `General Notes`, compact owner context, complete scrollable plain text and its own `Done`. Pitch references show that pitch's notes; route references show route General notes. Preserve exact text and paragraph breaks without new badges, callouts, headings or interpretation. No keyboard or editing controls.
- Sheet Done closes only the sheet, preserving image selection, zoom and pan. The reader behind it remains the same reader, not an alternate document or new navigation destination.
- A missing original remains a visible failure with Retry and Done, not a silently removed attachment. Do not place routine storage, OCR or backup explanations on the reading surface.

Mockup diagrams and explanatory annotations are reference material, not bundled climbing guidance or app copy. PDF behavior and further failure/empty-state details remain separate decisions.

## Editing and Confirmation

### Shared Editor Rules

These apply to Name, Note, Order, Add References and Manage References workflows. Deletion uses a distinct destructive confirmation.

1. Native navigation bar: Cancel, specific task title, Save. Creation entry actions still say Add Area/Route/Pitch; editor commits say Save.
2. Compact, complete owner/field context before the input. Distinguish duplicate names and Notebook/Examples/retained sources; preserve source-bound drafts. Wrap/stack instead of adding a redundant Editing card.
3. Input occupies useful space. Preserve exact authored text, whitespace, Unicode and order. No silent normalization, retargeting, reset or reseeding.
4. Quiet feedback outside inputs; actionable errors at the point of failure. Keep Save/Cancel reachable with the keyboard visible. Hide Keyboard belongs with the bottom-anchored keyboard, not a permanent content row. Return/Done and keyboard dismissal do not commit.

| State | Required behavior |
| --- | --- |
| Unchanged | No new-save announcement; dismissal does not invent a save |
| Modified | Quiet Unsaved changes, wrapping/stacking with context; no status card |
| Saving | Visible Saving feedback; prevent duplicate submission, conflicting actions, dismissal, Cancel and source switching |
| Save failed / conflict | Retain the complete draft/source identity; show actionable error with Retry/review; never silently overwrite or dismiss |
| Leaving changed draft | Block silent interactive dismissal; offer Discard Changes and Keep Editing |
| Invalid name | Explain the applicable requirement at the field and retain input, without a permanent naming tutorial |

Save closes only after acknowledged success. Cancel abandons only uncommitted changes; Cancel uses the ordinary accent, confirmed discard is destructive. No autosave or recovery of uncommitted work after termination is promised. Plan §4.3 is reconciled to this explicit-save contract; historical buffered-autosave/Done-Back wording does not govern current or future editors.

### Note Editor Composition

Owner-approved modified/keyboard-visible and save-failed/keyboard-dismissed compositions share one separate full-screen plain-text editor.

- Native navigation bar: `Cancel`, `Edit Notes`, `Save`, reachable with the keyboard visible. No back arrow, profile, overflow menu or duplicate commit action.
- Compact, complete owner/field context precedes the editable text (for example, `Paper Skyline · Pitch 2 — Open Book` or `Paper Skyline · Approach`). Wrap context and stack feedback when necessary; no redundant Editing section or identity card.
- A generous plain-text surface uses the available space above the native keyboard. Preserve exact text, whitespace and paragraph breaks. Keep the same basic editor layout across states; do not add formatting tools, attachments, counters, timestamps, coordinates, sync/buffer labels or implementation terminology.
- Modified state shows one quiet `Unsaved changes` indicator outside the field, using the shared keyboard treatment.
- Save failure retains the entire edited text and shows concise `Not saved. Your changes are still here.` feedback with `Retry` between context and field. Do not repeat the unsaved indicator or reset the buffer. Error and Retry wrap/stack at larger text sizes. Applicable failure/conflict details and recovery remain governed by the existing save contract; generic sample copy does not replace actionable errors.

Behavior/explanation panels from Stitch are annotations only and are excluded from the app.

### Name Editor Composition

Owner-approved shared single-field pattern, illustrated by Add Route and Rename Pitch. Use the same pattern for area/route/pitch creation and rename actions.

- Native navigation bar: `Cancel`, the specific task title (for example, `Add Route` or `Rename Pitch`), and `Save`. No generic Field Log Entry title, ascent/logging terminology or profile control.
- Compact, fully wrapping owner context precedes the field. Use parent context for creation and enough area/route/position context to identify a pitch. Quiet `Unsaved changes` feedback wraps/stacks consistently rather than competing with context or appearing as a prominent badge.
- One restrained native name field with a persistent label: `Name *` for required area/route names (accessible as `Name, required`), or `Name (optional)` for pitches. Long entered names wrap; do not truncate, normalize or require uniqueness. A position-based pitch display fallback is not automatically entered or stored as an authored name.
- A clear-field control, if supplied, changes only the draft and remains subject to Save/Cancel. The native keyboard sits at the bottom with only the compact `Hide Keyboard` accessory action; Return/Done does not commit. Use consistent field/context/accessory styling across tasks, without heavy nested outlines or decorative shadows.
- Preserve natural empty space. No other metadata, references, naming-rules tutorial, counters or technical status. Validation appears at the field when needed; save failure retains input and follows the shared error/Retry pattern. Explicit Save, discard confirmation and busy-state behavior follow the existing editor contract.

### Order Editor Composition

Owner-approved shared pattern for deliberately reordering sibling areas, routes or pitches, illustrated by Reorder Pitches.

- Native navigation bar provides `Cancel`, the complete task title and `Save`. If the specific title cannot fit, use `Reorder` with the collection identified in content rather than an ellipsized task title. No profile control or keyboard.
- Compact, fully wrapping owner context precedes the list. Show quiet `Unsaved changes` only when the draft sequence differs from saved order; stack feedback when needed.
- Native ordered rows show current draft position, full wrapping item name, drag handle and visible Move Up/Down alternatives. Disable unavailable boundary moves. Each arrow has a comfortable touch target and an item-specific accessible label such as `Move Open Book Up`; controls reflow at larger text sizes rather than squeezing names or targets.
- Moving changes only the draft sequence and updates displayed positions. Names, notes, references and stable identity travel with each item unchanged. One Save commits the complete order under the shared editor rules.
- Preserve natural empty space below short lists. No delete, rename, add-item, automatic sort, filter, reset or separate numbering controls. Reordering is distinct from reading navigation and does not promise recovery of an unsaved sequence after termination.

### Deletion Confirmation Composition

Owner-approved separate full-screen compositions cover route deletion and blocked nonempty-area deletion. Apply the same restrained pattern to pitch and empty-area deletion with accurate consequences.

- Navigation bar shows `Cancel` and the specific task title (`Delete Route`, `Delete Pitch` or `Delete Area`), without Save, profile controls or a sheet grabber.
- Route confirmation shows compact area context, full route name, an accurate warning identifying the route and loss of its pitches, notes and attached references, and `This cannot be undone.` One red `Delete Route` button performs the destructive action; entering the screen changes nothing. Counts reflect actual content, not mockup values.
- Blocked area confirmation shows the full area name and `This area contains 4 routes. Remove its routes before deleting the area.` with the actual count and appropriate grammar. Only Cancel is available. No Delete All, route-move shortcut, route inventory or disabled destructive button is needed.
- Names, consequences and errors wrap; content scrolls at larger text sizes without blocking controls. Cancel uses the ordinary accent. No unrelated metadata, technical safeguards, instructions explaining Cancel or extra confirmation challenges. Natural empty space is intentional.
- During deletion, prevent duplicate submissions and conflicting dismissal. Failure keeps confirmation open with an actionable error and retry opportunity. Successful route/area deletion returns to its parent; pitch deletion retains the existing adjacent-pitch/parent navigation contract. Deleting app attachments does not imply deleting external Photos originals or immediately destroying shared files.

### Add References Review Composition

Owner-approved populated review composition follows native Photos selection and precedes explicit Save to one route or pitch. It does not recreate the picker or authorize new intake types, PDF support or UI implementation.

- Native navigation bar provides `Cancel`, `Add References` and `Save`. Full owner context wraps below it, with quiet `Unsaved changes` on a separate line when needed. Owner identity stays fixed throughout the workflow.
- `Pending References (2)` uses the actual pending count. Do not describe pending selections as saved attachments or show routine Stored locally status.
- Pending items appear in selection order, each with an uncropped aspect-fit identification preview, a persistent `Caption (optional)` label and editable wrapping caption. An empty field uses `Describe this reference...` as helpful placeholder text, not a duplicate label or suggestion of tags/separate notes. The label remains visible during input.
- Each item has `Open Preview` and `Remove Selection` actions outside the image. Preview is read-only and does not save; returning preserves selections and exact caption edits. Remove Selection affects only that pending item, not Photos originals or saved attachments. Actions stack when needed for larger text/comfortable targets.
- `Add More` remains distinct from Save and returns to Photos selection without losing the existing review buffer. No drag reorder, tags, extraction, classification or reference-editing tools are established here.
- Caption editing follows shared editor rules, retaining pending items and exact captions after failure. Failed/unsupported selections remain visibly identifiable rather than silently disappearing.
- No instructional footer, undefined timeline destination or technical status panels. Preserve natural scrolling; do not squeeze all selected content into one viewport.

### Manage References Composition

Owner-approved populated editor and removal confirmation apply to saved references belonging to one route or pitch.

- Native navigation bar provides `Cancel`, `Manage References` and `Save`; use `References` if the full title cannot fit rather than truncating it. Full owner context wraps below, with quiet draft-change feedback.
- `References (2)` reflects the draft list count, not a claim that edited values are saved. Each item shows draft position, a small uncropped identification preview, persistent optional caption field, Open Preview, drag handle, visible Move Up/Down alternatives and destructive Remove Reference. No inferred category labels. Empty captions use the shared `Describe this reference...` placeholder.
- Captions wrap and remain editable. Give move controls item-specific accessible labels and comfortable targets, disable unavailable boundary moves, and reflow actions at larger text sizes. Preview returns to the exact editor draft without saving or losing edits. Caption editing uses the shared keyboard treatment.
- Remove Reference opens a native confirmation identifying the selected item, with `Remove` and `Keep Reference`. Copy: `The reference will be removed when you save. Files outside this app will not be removed.` The same editor/draft remains underneath; the modal dims and blocks the entire background, including Save/Cancel. Keep Reference leaves the draft unchanged; Remove stages removal only.
- One Save commits caption, order and removal changes together under shared editor rules. No immediate destruction of shared originals or deletion of external files is implied.
- Adding references remains a separate workflow. No Add More, reassignment between owners, image modification, tags, extraction or technical status panels. Use natural scrolling rather than shrinking content to fit.

## Secondary Screens

### About and Data Composition

Owner-approved composition uses native grouped sections in this order: Your Data, Examples, About. It describes current capabilities, not future export/backup availability.

- Navigation bar shows `About & Data` and `Done`, returning to Library. No Save, account/profile controls or invented branding/footer.
- Your Data states: `Your notebook is stored on this device. Saved notes and references can be read without an internet connection.` Follow with the readable limitation: `No backup or recovery is available in this version. Keep another copy of important notes and images.` The owner explicitly approved retaining the decorative checkmark beside the storage statement; it is not an interactive health check or an audit result.
- Examples provides `Open Examples` and `Explore a separate example notebook without changing your own.` This is the approved secondary entry point, replacing prominent Library example access when implemented. Preserve conditional access to retained legacy content during implementation planning; do not reset, import or replace it through this navigation change.
- About states: `A personal notebook for preparing and consulting climbing notes and reference material.` Supporting text: `The app does not generate or verify climbing advice.` No invented publisher, version, support details or settled brand.
- All copy wraps using native semantic typography. Quiet surfaces and optional decorative icons are acceptable; natural empty space is intentional. No disabled future actions, Coming Soon panels, storage meters, diagnostics, subscriptions, sync controls or destructive reset tools. Update capability/limitation copy when the actual features change rather than leaving obsolete claims.

## Content Before Chrome

- Native, iPhone-primary with minimal iPad support. Calm, practical and legible outdoors; a notebook, not a dashboard, ascent log or climbing adviser.
- Lead with the task and user content. Explain location through hierarchy, not an instruction paragraph. Every app-authored sentence must help the task, prevent consequential loss or explain recovery.
- Use one navigation title. Put owner/location in a compact secondary line; retain enough context to distinguish duplicate names and Notebook/Examples/retained sources. Wrap rather than truncate essential identity.
- Group related content with spacing and quiet surfaces. Do not give routine status, provenance and user notes equally prominent cards.
- Compact means fewer redundant containers and labels, not smaller text, hidden actions or smaller touch targets. Preserve authored text verbatim, including whitespace, Unicode and section order; never summarize or trim notes to fit.

## Shared Content and Trust Rules

- Keep note editing, naming, ordering and deletion separate. Reading/navigation never commits or mutates content. No backend, account, sync, analytics or generated climbing advice is implied by mockups.
- Never replace an unreadable library with an empty-library screen. Distinguish loading, genuinely empty and unavailable states. Missing originals remain visible errors with recovery/return actions.
- Do not repeat routine Saved/Loaded status on reading screens. Put the backup limitation in About & Data; keep unsaved feedback, actionable failures and destructive/discard confirmations at the point of risk. Never promise accuracy, synchronization, encryption or recovery without implementation/evidence. Offline availability describes local bytes, not safety.
- Unknown metadata stays unentered. Display counts describe saved/draft records, not verified route characteristics. Preserve user-authored assertions without turning them into app-issued assurances.
- References and provenance are distinct from authored notes. Previews identify files, not replace original reading. Dynamic Type scales controls/text, not raster content; provide zoom alternatives. Appearance changes chrome, never original colors. Keep attachment ownership separate from external Photos/Files ownership.
- No references: retain useful reading content with a quiet add action, not a large empty gallery. Other Route/Pitch empty-section details remain open. The intended Route order is specified above; the old images-first milestone is not a competing design target.
- Use coherent synthetic content for examples/mockups. Generated diagrams, sample climbing text and design annotations are not bundled guidance or user-facing explanations. Generated HTML is not evidence of rendered behavior.

## Native Visual System

Use native SwiftUI navigation, forms, lists, toolbars, menus, alerts and SF Symbols. Keep familiar interaction and platform geometry; do not replace controls merely to style them. Icons clarify actions and have accessible names; unfamiliar actions retain visible labels. Native sheets/popovers own their elevation and material treatment.

Use quiet stone-neutral surfaces, forest-green actions and restrained burnt-orange accents. Color conveys meaning, not decoration; destructive/error meaning also needs text. These approved tokens are roles, not proof of rendered contrast:

| Role | Light | Dark |
| --- | --- | --- |
| Canvas | `#F4F6F8` | `#12181C` |
| Surface | `#FFFFFF` | `#1C2429` |
| Surface secondary | `#E7EDF1` | `#273239` |
| Text primary | `#1C2429` | `#F2F5F7` |
| Text secondary | `#46545E` | `#BDCAD2` |
| Action | `#2D5A43` | `#A5D6B7` |
| On action | `#FFFFFF` | `#12181C` |
| Accent / warning | `#9B4A28` | `#F3B99B` |
| Success | `#244B37` | `#8DC4A2` |
| Error | `#B3261E` | `#FFB4AB` |
| Control boundary | `#71808A` | `#84949F` |

Use system semantic text styles: title/headline for hierarchy, body for notes and essential feedback, supporting styles for context. Do not shrink essential text into captions. No bundled custom-font choice is approved.

Use a 4-point spacing scale for app-owned layout, typically 16-point phone gutters; respect native insets and safe areas rather than forcing them onto a grid. Avoid nested cards, decorative gradients, heavy shadows and promotional headers. App-owned targets are at least 44x44 points; preserve native toolbar sizing. At large text, wrap/stack and allow scrolling instead of truncating or squeezing. Never cover the last line of a note.

## Accessibility

Support Dynamic Type through accessibility sizes, VoiceOver and Reduce Motion. Use logical reading order, heading semantics, specific reorder labels and non-color state cues. Keep Save/Cancel and keyboard dismissal reachable with the keyboard open. No settings changes or motion may be required to understand the interface.

Rendered light/dark contrast targets: 4.5:1 normal text, 3:1 large text and essential control graphics. Quiet secondary text must remain readable. Approval of tokens or appearance is not accessibility qualification; verification follows the skill and approved plan.

## Open Design Decisions

These are gaps to resolve with the owner, not permission to improvise or implement. Existing technical contracts still apply; do not put unavailable destinations or Coming Soon controls in the running app.

| Topic | Still to decide |
| --- | --- |
| Library | Aggregate pitch summaries, detailed search/results and secondary library-management placement |
| Classification | Small user-selectable tile collection: area/route ownership, meaning and editing; custom tag ownership/display, including descriptions such as High altitude; no fixed taxonomy inferred |
| Route notes | Custom-section placement and preservation of authored section titles/order; empty sections and creation/editing of future Approach/Descent/Gear sections |
| Reading states | Remaining Pitch/Reference empty, long, boundary and failure compositions beyond the rules already approved |
| Sources and intake | Sources interactions; Inbox/manual review and target selection; Photos/Files/paste/share/URL copying; distinguish a link from copied bytes |
| PDFs | Page navigation and relationship to reference collection navigation and notes |
| Metadata | Grade/style/length editing and route moves; no values inferred from note text |
| Data portability | Export, backup and replace restore screens; preserve count preview, export opportunity, destructive-loss explanation and final confirmation required by the technical plan |

The plan's broader v1 requirements are not made optional by incomplete screen design. OCR/extraction, grade/style filters, favorites and direct camera are post-v1 possibilities, not required composition elements. Sync/conflicts, annotation, maps, selective sharing and public data need separate planning. Do not invent computed cruxes, verified beta or safety ratings.

## Reviewed Visual References

[Stitch project](https://stitch.google.com/projects/8970725447177276768). The owner supplied these direct references on 2026-11-09 after the screen-by-screen reviews. They replace the older reference index for intended composition. Written rules above resolve generated artifacts (including annotation panels, typography, alerts and placeholders); screenshots do not authorize features or establish accessibility qualification. Remote screens may change; these links are references, not locally archived snapshots or a claim of fresh remote inspection.

| Screen / state | Direct reference |
| --- | --- |
| Library | [Mockup](https://stitch.google.com/projects/8970725447177276768?node-id=3a77417ce44348eb97eae43da0fdd647) |
| Area | [Mockup](https://stitch.google.com/projects/8970725447177276768?node-id=2db1a08c4e284f249536534430ad7e26) |
| Route Details | [Mockup](https://stitch.google.com/projects/8970725447177276768?node-id=7301ee57518540c9a9ec45c5fc50b2b6) |
| Pitch Details | [Mockup](https://stitch.google.com/projects/8970725447177276768?node-id=8982d3e60118427caeb2bedf6ae16ca1) |
| Reference Reader: Notes sheet | [Mockup](https://stitch.google.com/projects/8970725447177276768?node-id=6faf4d3453174ff28840389cba2b3d41) |
| Reference Reader: normal | [Mockup](https://stitch.google.com/projects/8970725447177276768?node-id=bfb8650d9c864c56865472d665aa3b6e) |
| Note Editor: keyboard | [Mockup](https://stitch.google.com/projects/8970725447177276768?node-id=8802e798bf6e475abd4ac9907da79c30) |
| Note Editor: save failure | [Mockup](https://stitch.google.com/projects/8970725447177276768?node-id=71c24c2157ca498585316845ee227cac) |
| Name Editor: Rename Pitch | [Mockup](https://stitch.google.com/projects/8970725447177276768?node-id=478b74ada1fa44a098505bf711b3b047) |
| Name Editor: Add Route | [Mockup](https://stitch.google.com/projects/8970725447177276768?node-id=de2f228120994bbab6742c33826f105d) |
| Reorder Pitches | [Mockup](https://stitch.google.com/projects/8970725447177276768?node-id=ef59efc514f34ff6a01417bbf576f2e0) |
| Delete Route | [Mockup](https://stitch.google.com/projects/8970725447177276768?node-id=c7699f044cd74568b774f22c06ad7799) |
| Delete Area: blocked | [Mockup](https://stitch.google.com/projects/8970725447177276768?node-id=0aa568cf96bb41fc9dca396da3a7f6e0) |
| Add References | [Mockup](https://stitch.google.com/projects/8970725447177276768?node-id=dd2bbfd3ed9040a8b0b5942049f3b3e9) |
| Manage References | [Mockup](https://stitch.google.com/projects/8970725447177276768?node-id=6ceee75303644e74afcc4ed04de0be7f) |
| Manage References: confirmation | [Mockup](https://stitch.google.com/projects/8970725447177276768?node-id=44ad6c0a3fd243c4ae06c415799b02b4) |
| About & Data | [Mockup](https://stitch.google.com/projects/8970725447177276768?node-id=e2a05086498644c5905547a97614d5d1) |
