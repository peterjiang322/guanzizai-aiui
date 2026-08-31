# Touch Direction Navigation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reverse the directional touch navigation across every AIUI page so forward/down selects the next item and backward/up selects the previous item.

**Architecture:** Keep each page's existing page-local state, wrapping behavior, scroll behavior, Enter handling, and Backspace handling. Change only the direction-to-action mapping in each existing `onKeyUp` handler; horizontal aliases follow the same next/previous mapping where they already exist.

**Tech Stack:** AIUI `.ink` pages, JavaScript page handlers, Node.js tests.

## Global Constraints

- WXML control attributes continue to use the `ink:` prefix.
- Do not introduce unsupported WXSS features or browser-only APIs.
- Preserve existing page lifecycle, voice, audio, routing, and selection state behavior.
- `muyu` has no directional selection handler and therefore requires no production change.

---

### Task 1: Add regression coverage for the reversed direction mapping

**Files:**
- Create: `aiui-agent/tests/touch-direction.test.cjs`
- Test: `aiui-agent/pages/index/index.ink`, `aiui-agent/pages/chat/chat.ink`, `aiui-agent/pages/meditation/meditation.ink`, `aiui-agent/pages/soundscape/soundscape.ink`, `aiui-agent/pages/scripture/scripture.ink`

**Interfaces:**
- Consumes: each page's existing `onKeyUp(event)` function and its current page state shape.
- Produces: a repeatable test that fails until every directional handler maps up/left to next and down/right to previous, including scripture detail scrolling.

- [ ] **Step 1: Write the failing test**

  Extract each page's `onKeyUp` function from source, execute it with a small page fixture, and assert the requested next/previous state changes. For scripture detail, assert `ArrowUp` increases `verseScrollTop` and `ArrowDown` decreases it at a non-edge position.

- [ ] **Step 2: Run the test to verify it fails**

  Run: `node tests/touch-direction.test.cjs` from `aiui-agent`.
  Expected: FAIL because the current handlers map `ArrowUp` to previous and `ArrowDown` to next.

### Task 2: Reverse all page direction handlers

**Files:**
- Modify: `aiui-agent/pages/index/index.ink:344-364`
- Modify: `aiui-agent/pages/chat/chat.ink:355-368`
- Modify: `aiui-agent/pages/meditation/meditation.ink:846-879`
- Modify: `aiui-agent/pages/soundscape/soundscape.ink:349-359`
- Modify: `aiui-agent/pages/scripture/scripture.ink:352-405`

**Interfaces:**
- Consumes: the failing directional navigation tests from Task 1.
- Produces: `ArrowUp`/`ArrowLeft` next behavior and `ArrowDown`/`ArrowRight` previous behavior for list selectors; scripture detail maps up to down-scroll/next-section and down to up-scroll/previous-section.

- [ ] **Step 1: Implement the minimal mapping changes**

  In list handlers, use this mapping while retaining each page's existing wrapping/bounds logic:

  ```js
  if (code === "ArrowUp" || code === "ArrowLeft") {
    var next = this.data.selectedIdx + 1;
    if (next >= items.length) { next = 0; }
    this.setData({ selectedIdx: next });
  } else if (code === "ArrowDown" || code === "ArrowRight") {
    var prev = this.data.selectedIdx - 1;
    if (prev < 0) { prev = items.length - 1; }
    this.setData({ selectedIdx: prev });
  }
  ```

  In meditation, apply the same mapping independently to `typeIdx` and `durationIdx`. In scripture detail, move the existing down-scroll/next branch to the up event and the existing up-scroll/previous branch to the down event without changing edge checks.

- [ ] **Step 2: Run the focused regression test**

  Run: `node tests/touch-direction.test.cjs`.
  Expected: PASS.

### Task 3: Run the complete available test suite and static checks

**Files:**
- Verify: all files under `aiui-agent/pages/` and `aiui-agent/tests/`

**Interfaces:**
- Consumes: the updated page handlers and focused regression test.
- Produces: verified behavior with no regressions in existing voice, meditation, scripture, or check-in tests.

- [ ] **Step 1: Run every test file**

  Run: `for test in tests/*.js tests/*.cjs; do node "$test"; done` from `aiui-agent`.
  Expected: every test exits successfully.

- [ ] **Step 2: Check the changed direction mappings**

  Run: `rg -n -C 2 "ArrowUp|ArrowDown|ArrowLeft|ArrowRight" pages` from `aiui-agent`.
  Expected: each selector maps up/left to next and down/right to previous; scripture detail maps up to down-scroll/next and down to up-scroll/previous.

- [ ] **Step 3: Review the diff**

  Run: `git diff -- pages tests/touch-direction.test.cjs docs/superpowers/plans/2026-08-27-touch-direction.md` from `aiui-agent`.
  Expected: only the requested direction mappings, regression test, and implementation plan are changed.
