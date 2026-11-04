---
name: native-interface-design
description: Required workflow for designing, changing or reviewing native iOS/SwiftUI screens, controls, UI copy and interaction layouts in Climbing Notebook.
---

# Native Interface Design

## Read the Contract

Read repository-root `DESIGN.md` for product rules, `SYSTEM_DOCS.md` for routing, then only the relevant approved-plan section and current implementation/evidence. Do not copy product tokens or component specs into this skill. Design guidance does not authorize new features or changes to saving, data contracts or navigation architecture.

For review-only work, return findings without edits or running checks unless requested. For proposals/mockups, distinguish intended design from implemented behavior. The implementation steps below apply only to authorized changes.

## Before Editing

Identify the task, primary content, secondary controls and behavior to preserve. Explain only consequential tradeoffs to the owner; no ritual design report is required. Remove or group unnecessary chrome before inventing components. Do not demand approval for routine decisions already in scope.

Inspect the actual screen and source. Ask: can the user identify the task, location and primary action without reading a paragraph? Preserve complete authored content; compress app chrome, not notes, text size or touch targets.

## Build the Smallest Coherent Change

- Apply the product's hierarchy and tokens using native SwiftUI components and semantic typography. Do not replace native behavior solely for styling or novelty, or import web-dashboard patterns uncritically.
- Put secondary tools where they are used; reserve prominent explanations for errors, risk and recovery. Compact controls still need discoverability, accessible names and distinct destructive actions.
- Keep user buffers, selection/source identity and commit/cancel semantics intact. If the requested layout requires changing a protected behavior, stop that dependent change and obtain approval.

## Inspect and Exercise

Use the plan's current MVP delivery policy, not historical exhaustive qualification gates. Inspect the changed screen in default/largest text, actual light/dark and with the keyboard where relevant. Select representative long/empty/error states for the change, not every historical matrix. Use replaceable content; do not change device settings implicitly.

Run focused regressions for affected core actions, saving/reopening and draft preservation. Keep native accessible labels and reachable controls; fix demonstrated clipping or blocked actions. Automated audits and VoiceOver review are supplemental MVP checks, not mandatory on every UI edit. Preserve their findings without claiming compliance, suppressing failures or starting repeated diagnostics. Record unavailable checks only when relevant to the result.

Critique the result: does content lead, does every container earn its space, and can context/error text still be read? Within authorized implementation, revise the weakest part before reporting. Never fix density by truncating notes, hiding essential errors or shrinking targets.

## Report Evidence, Not Taste

Report actual checks and material limits concisely. For a reproducible interaction defect, record enough environment/setup/actions to reproduce it; no category-threshold sweep unless needed to fix that defect. Distinguish ordinary use, automation targeting and audit findings. Human success does not turn a failed audit green, but an unresolved audit alone does not block MVP feature delivery.

Keep reusable product decisions in `DESIGN.md`, results in existing verification docs. Follow repository reporting rules; do not create a parallel design system or session report.
