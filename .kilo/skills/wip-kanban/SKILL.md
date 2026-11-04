---
name: wip-kanban
description: Required workflow for claiming and updating the shared WIP Kanban board.
---

# WIP Kanban Workflow

The shared operational board is `docs/WIP_KANBAN.md`.
Read this skill and the current board before claiming work that is represented
by a board card. The board coordinates work; it does not replace the linked
plan or its acceptance criteria.

## Required Workflow

1. Read the card and only the relevant sections of its authoritative plan, including the current MVP delivery policy. Historical qualification instructions do not override that policy.
2. Claim a card by moving it to **In Progress** and replacing `Owner: Unassigned` with the current agent or worktree identifier. An agent or worktree may own multiple active cards when each is independently actionable and its status can be accurately maintained.
3. Preserve the card ID, priority, plan link, dependencies, and done condition. Do not change another agent's active card.
4. Keep board edits minimal. Do not reformat unrelated cards, reorder columns, or add narrative notes, investigation detail, design rationale, terminal output, or implementation logs.
5. When blocked, move the card to **Blocked** and replace its dependency/blocker line with a concise actionable blocker. Link evidence rather than describing it at length.
6. When implementation and scoped core checks are ready for owner review, move the card to **Review**, retain ownership, and add a single `Evidence:` line containing concise file, test, commit, or pull-request references. A separate specialist/agent review cycle is not required by default.
7. Move a card to **Done** only after its stated done condition and required validation pass. Record `Completed: YYYY-MM-DD` and one concise `Evidence:` line.
8. If no card covers the work, create one in **Ready** using the required card format before implementation begins. Do not create cards for incidental edits, routine verification, or long-lived ideas that lack an approved plan.
9. Update the linked plan only when scope, API, acceptance criteria or an authoritative state conclusion changed. Do not add per-task completion narratives to an otherwise unchanged plan.

## Card Format

```md
- [ ] `AREA-###` Concise deliverable title
  - Priority: P0|P1|P2|P3
  - Owner: Unassigned|agent/worktree identifier
  - Depends on: None|concise dependency
  - Plan: `docs/authoritative-plan.md` §...
  - Done when: Observable acceptance condition.
```

Use `Blocked by:` rather than `Depends on:` only when the card is in
**Blocked**. Use `Completed:` only in **Done**; use `Evidence:` in **Review** and **Done**.

## Boundaries

- The board is limited to **Ready**, **In Progress**, **Blocked**, **Review**, and **Done**. Do not add an unstructured notes column or free-form backlog.
- Status facts belong in this board. Rationale, scope, API contracts, edge cases, and implementation details belong in the linked plan.
- Do not use the board to create or imply product approval. An unapproved idea remains outside the board or in its planning document.
- Non-gating audit flags and paused future-feature research do not block an unrelated MVP feature card. Preserve them in their existing evidence/card; block only on a concrete dependency under the current policy.
- Keep **In Progress** limited to independently actionable work with independently verifiable done conditions. Avoid claiming work that cannot be actively progressed or accurately maintained.
- The lead agent periodically archives completed cards in a dated section or archive document. Do not delete completion evidence.
