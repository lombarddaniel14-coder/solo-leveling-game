# Agent HQ — Code Audit Report

Scope: `index.html` (~1900 lines), reviewed in full (CSS block + entire inline JS). Focus: bugs introduced or exposed at the seams between the three historical passes (original dashboard → editable names/attachments → D3/animation rewrite), plus general correctness, error handling, accessibility, and performance.

No live browser was available in this environment (no Node/Python interpreter; PowerShell script-based local server execution was blocked by the sandbox's safety policy, consistent with what was already reported). All findings below come from careful manual tracing of the code paths, not from pattern-matching alone. Fixes were verified by structural re-reads (function boundaries, brace/paren balance, listener wiring) after each edit.

---

## Critical

None found that unconditionally corrupt saved data or crash the app outright. The two closest candidates are documented under Moderate, since they require multi-step user timing to trigger and never write bad data to disk (they only lose *unsaved* in-memory edits or transiently glitch the UI).

---

## Moderate — Fixed

### 1. Auto-refresh silently discards an in-progress CLAUDE.md edit or agent rename
**Where:** `refresh()` (was ~line 1801), `beginEditName()` (~1393), the `editMdBtn` click handler inside `renderAgentDetail()` (~1637).

The 30-second auto-refresh (`tickCountdown` → `refresh()`) always reloads `team.json` and unconditionally calls `renderAgentDetail(agent)` for the selected agent, which replaces `#agentDetail`'s entire innerHTML. If a user has the "Edit" CLAUDE.md textarea open with unsaved changes, or is mid-inline-rename on the detail-panel name, the timer fires and wipes the edit with no warning — the textarea/contenteditable state and all its listeners vanish. This is a real, easily-triggered data-loss bug (a CLAUDE.md edit can easily take longer than 30s to write).

**Fix applied:** Added a module-level `detailEditActive` flag, set `true` when an inline rename or CLAUDE.md edit begins and `false` when it's committed/cancelled/saved. `refresh()` now checks this flag and skips the detail-panel re-render (but still refreshes the org chart and every other panel) while an edit is in flight.

### 2. Modal open/close race can re-show a modal the user just closed
**Where:** `openModal()` / `closeModal()` (was ~line 1697).

`openModal()` schedules `classList.add('in')` inside a `requestAnimationFrame` callback. If `closeModal()` is called before that rAF fires (e.g. user opens then immediately clicks Cancel/backdrop), the pending rAF still fires afterward and re-adds the `in` class — visually reopening (or leaving in an inconsistent) the modal that was supposed to be closed. There was no way to cancel a pending open animation frame or an in-flight close cleanup.

**Fix applied:** Added a small `WeakMap`-based `modalState` tracker per modal element holding the pending rAF id / cleanup timeout id / transitionend listener. `openModal()` now cancels any pending close cleanup before opening; `closeModal()` now cancels any pending open rAF before closing. Rapid open/close/open clicking can no longer leave the modal in a contradictory visual state.

### 3. Attachment preview state is destroyed when the agent is renamed
**Where:** `renameAgent()` (was ~line 1330), `renderAgentDetail()` (~1565), `toggleAttachmentPreview()` (~1439).

Traced the exact scenario from the brief: user expands a `.md` attachment preview, then renames the agent (inline). `renameAgent()` called `renderAgentDetail(agent)` on success, which rebuilds `#agentDetail`'s entire innerHTML — including a fresh, empty `#attachList` via `renderAttachmentList(agent)` — silently collapsing the expanded preview with no indication anything happened.

**Fix applied:** Added `patchAgentDetailName(agent)` — a targeted DOM patch that updates only the avatar initials and the name label text in place, without touching the rest of the panel. `renameAgent()` now calls this instead of a full `renderAgentDetail()` re-render. Attachment previews, the CLAUDE.md preview, and everything else in the panel now survive a rename untouched. (It also naturally fixes the "renaming while CLAUDE.md edit textarea is open" case, since the textarea is no longer torn down either.)

### 4. No Escape-to-close on either modal
**Where:** modal wiring at the bottom of the script (~line 1944 onward).

Both `#addAgentModal` and `#launchModal` could only be closed via a Cancel/Close button or a backdrop click — pressing Escape did nothing, which is a standard accessibility/UX expectation for dialogs (and was explicitly called out in the audit brief).

**Fix applied:** Added a single global `keydown` listener that checks which modal (if any) currently has the `.show` class and closes it on `Escape`.

### 5. Malformed `team.json` with a `parentId` cycle can hang the tab; orphaned `parentId` silently drops an agent from the chart
**Where:** `renderOrgChart()` tree-building logic (was ~line 1224).

Two related robustness gaps, both reachable only via hand-editing `team.json` (there's no in-app way to create either state today, but the brief explicitly asked for malformed-file handling to be covered):
- **Cycle:** if `a.parentId === b.id` and `b.parentId === a.id`, the plain-object `children` arrays built before `d3.hierarchy()` runs form a genuine cycle. `d3.hierarchy()` has no cycle detection and walks `.children` recursively — this would recurse until the stack overflows, likely hanging or crashing the tab.
- **Orphan:** if `a.parentId` points at an id that doesn't exist in the roster (e.g. after a hand-edit), the original code's `else if (!a.parentId && !root)` branch never triggers for it (since it *does* have a `parentId`), so the agent is silently dropped from the tree — `teamCount` still shows it, but it never appears on the chart.

**Fix applied:** Rewrote the parent/child-linking pass into a single loop that computes, per agent, whether its declared parent is (a) present in the roster and (b) not part of an ancestor cycle (walked via a small `hasCycle()` helper). Agents that fail either check are collected into a `topLevel` list and attached under the chosen root instead of being dropped or looped over. Verified by tracing both the cycle case (both agents land in `topLevel`, no recursion) and the orphan case (agent lands in `topLevel`, renders under root) as well as the normal single-root case (unchanged behavior — `topLevel` has exactly one entry, `root = topLevel[0]`).

---

## Moderate — Documented, not fixed (out of safe scope for a bug-fix-only pass)

### 6. Full transcript re-parse every 30 seconds, unbounded by history size
**Where:** `loadTranscripts()` (~line 763), called from `refresh()` on every cycle.

Every 30-second auto-refresh fully re-reads and re-`JSON.parse()`s **every line of every `.jsonl` transcript file in every project directory** under `.claude/projects`, with no caching, no last-modified check, and no incremental read. For a heavy Claude Code user with months of session history across multiple projects, this means the tab does a full-disk-read-and-reparse of potentially many megabytes of text every 30 seconds, indefinitely, for as long as the tab stays open. This will visibly degrade (CPU spin, main-thread jank, battery drain) as history accumulates.

Not fixed: a correct fix (cache by file size/`lastModified`, or track a byte offset and only read new lines) is a genuine feature-sized change, not a one-line fix, and risks introducing new state bugs under a tight "no large refactors" constraint. Flagging for a dedicated follow-up pass.

### 7. Blur-commits a partial inline-rename edit when switching org chart node selection mid-edit
**Where:** `beginEditName()` (~1393) interacting with `selectAgent()` (~1343).

Traced the exact scenario from the brief: double-click node A to start renaming, then before finishing, click node B. `selectAgent('B')` triggers `renderAgentDetail(agentB)`, which replaces `#agentDetail` innerHTML — this detaches the still-focused, still-contenteditable name span for A, and Chrome/Edge fire a native `blur` event on a focused element when it's removed from the document. That triggers `finish(true)`, which commits whatever text was currently in the field for agent A (even a half-typed, unconfirmed edit) via `renameAgent()`.

This is standard "click away commits an inline edit" behavior (arguably intentional), not silent *data loss* to disk in the sense of writing garbage — the committed value is still validated (non-blank) — but a user could easily lose track of the fact that a half-finished edit for agent A just got saved while their attention moved to agent B. Not fixed because the "click away commits" pattern is a defensible, common UX convention, and changing it (e.g. to cancel-on-navigate, or to block navigation) is a product decision, not a bug fix, and risks unintended side effects elsewhere in a codebase already this deep into three stacked passes.

---

## Minor

- **`getDirSafe`/`getFileSafe` swallow all errors uniformly** (~line 670–674): a genuinely revoked filesystem permission mid-session is reported identically to "folder not found" (e.g. `"'.claude' folder not found"`), which is a confusing message if the real cause is a permission revocation. Low priority since every *write* path already surfaces a clear "check write permission" toast on failure.
- **No re-entrancy guard on `refresh()`** (~line 1827): clicking "Refresh" right as the 30s auto-refresh timer also fires causes two overlapping `refresh()` calls. Both are idempotent reads/re-renders so there's no corruption, just wasted work and possible visual flicker. A simple `if (isRefreshing) return;` guard would close this cheaply if desired later.
- **No accessibility attributes anywhere in the file**: no `role="dialog"`/`aria-modal` on the two modal overlays, no focus trap inside them (Tab can escape to the page behind), no focus restoration to the triggering element on close, no `role="textbox"`/`aria-label` on the contenteditable rename span, and the SVG org-chart nodes are click-only with no `tabindex`/keyboard activation (Enter/Space) for selecting or renaming an agent via keyboard. This is a real gap for a "final audit" but is a broader accessibility feature addition, not a targeted bug fix, so it's left documented rather than partially patched.
- **`agent.color` interpolated unescaped into an inline `style` attribute** (`renderAgentDetail`, `.detail-avatar`): if `team.json` is hand-edited with a malicious string in a `color` field, it could break out of the `style="..."` attribute and inject markup, since (unlike every other field) `agent.color` isn't passed through `escapeHtml()` at that call site. Real-world risk is very low — this is a local, single-user tool with no untrusted network input, and the in-app UI only ever writes colors from a fixed preset list — but flagging for completeness since the brief asked about error handling for malformed files.
- **Redundant `currentAgents[idx] = agent` reassignments** in `removeAttachment`, `uploadAttachment`, and the "Save session id" handler: `agent` is already the same object reference living inside `currentAgents` (obtained via `.find()`), so these lines are no-ops. Harmless, just dead code.
- **`connect()` swallows all `showDirectoryPicker` errors identically to user-cancel** (~line 1909): a genuine permission-denied error (as opposed to the user dismissing the picker) gets no toast/feedback at all. Minor, since the connect screen remains visible either way and the user can just retry.

---

## Nitpick

- `staggerDelay()`'s `Math.min(i * 25, 300)` cap was specifically checked against the brief's performance concern about large lists — it's fine as written; stagger delay does **not** scale unboundedly with list size, it correctly caps at 300ms regardless of how many items are rendered.
- The D3 keyed-data concern from the brief (`d.target.data.id` for links vs `d.data.id` for nodes) was traced in detail and found to be **correct and consistent** — every non-root agent appears exactly once in the tree (single `parentId` per agent), so each link's target id is unique and matches its corresponding node's key one-to-one. No fix needed there.
- `marked` failing to load from the CDN is already handled gracefully (`typeof marked !== 'undefined' && marked.parse` guard falls back to `escapeHtml(text)`), and `marked.parse()` throwing on some input is also already wrapped in try/catch. No issue found here despite it being called out as a risk area.
- Non-UTF8 attachment uploads don't throw (`file.text()` decodes with replacement characters rather than erroring), so there's no crash — but the content is silently mangled with no warning to the user. Extremely low priority given the feature is scoped to `.md` files the user creates themselves.

---

## Summary of fixes applied to `index.html`

1. Added `detailEditActive` flag; auto-refresh now skips the detail-panel re-render while a rename or CLAUDE.md edit is in progress, instead of silently discarding it.
2. Modal open/close now tracked via a `WeakMap`-based state machine (`modalState`) that cancels pending open animation frames on close and pending close cleanup on open, closing the rapid-click race.
3. Added `patchAgentDetailName()` for in-place name/avatar patching on rename, so expanded attachment previews (and the CLAUDE.md edit textarea, if open) survive a rename instead of being wiped by a full re-render.
4. Added a global `Escape` key handler that closes whichever modal is currently open.
5. Rewrote the org-chart's parent/child tree-building pass to detect and gracefully handle `parentId` cycles (previously could hang the tab via infinite `d3.hierarchy` recursion) and orphaned `parentId` references (previously silently dropped the agent from the chart).

All other Moderate/Minor/Nitpick findings are documented above but intentionally left unfixed, either because a safe fix would require a larger refactor than this pass is scoped for (transcript re-parsing performance), or because the "bug" is a defensible existing UX convention rather than a defect (blur-commit on selection change).
