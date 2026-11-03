---
name: native-interface-design
description: Required workflow for designing, changing or reviewing native iOS/SwiftUI screens, controls, UI copy and interaction layouts in Climbing Notebook.
---

# Native Interface Design

## Read the Contract

Read repository-root `DESIGN.md` for product rules, `SYSTEM_DOCS.md` for routing, then only the relevant approved-plan section and current implementation/evidence. Do not copy product tokens or component specs into this skill. Design guidance does not authorize new features or changes to saving, data contracts or navigation architecture.

For review-only work, return findings without edits or running checks unless requested. For proposals/mockups, distinguish intended design from implemented behavior. The implementation steps below apply only to authorized changes.

## Before Editing

State briefly: **person/task**, **primary content**, **secondary controls**, **behavior preserved**. Identify what can be removed, grouped or moved before inventing another component. Use existing product intent; do not demand owner approval for routine decisions already in scope.

Inspect the actual screen and source. Ask: can the user identify the task, location and primary action without reading a paragraph? Preserve complete authored content; compress app chrome, not notes, text size or touch targets.

## Build the Smallest Coherent Change

- Apply the product's hierarchy and tokens using native SwiftUI components and semantic typography. Do not replace native behavior solely for styling or novelty, or import web-dashboard patterns uncritically.
- Put secondary tools where they are used; reserve prominent explanations for errors, risk and recovery. Compact controls still need discoverability, accessible names and distinct destructive actions.
- Keep user buffers, selection/source identity and commit/cancel semantics intact. If the requested layout requires changing a protected behavior, stop that dependent change and obtain approval.

## Inspect and Exercise

Select affected states/checks under the approved verification contract. Inspect default/largest text, actual light/dark and keyboard open/closed where relevant; cover long/duplicate names, long notes, empty/error states as affected. Use synthetic fixtures; do not change device settings implicitly.

Exercise affected entry, edit, Save, Cancel/discard, failure/retry, order/delete and fresh reopening paths. Check VoiceOver labels/order and target reachability where affected; screenshots alone prove neither. Run focused existing regressions and unrestricted audits when affected; preserve their assertions. Record unavailable checks rather than claiming completion.

Critique the result: does content lead, does every container earn its space, and can context/error text still be read? Within authorized implementation, revise the weakest part before reporting. Never fix density by truncating notes, hiding essential errors or shrinking targets.

## Report Evidence, Not Taste

Give exact executed results and remaining limits. For interaction failures record device/runtime, appearance, observed text category, setup, action, outcome and extra gestures; bound thresholds with adjacent settings. Distinguish ordinary touch, AX automation and audit findings. Human success or a workaround does not clear failed audits; never weaken checks.

Keep reusable product decisions in `DESIGN.md`, results in existing verification docs. Follow repository reporting rules; do not create a parallel design system or session report.
