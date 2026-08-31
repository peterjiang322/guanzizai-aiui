# Selection Style Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the selected menu and meditation cards use the same visible green background and transparent selected border as scripture cards.

**Architecture:** Reuse each page's existing selected index and tap binding, but move the selected class to an outer wrapper around the native card so the background covers the full card. Give the native card a transparent shell and keep navigation and content layout unchanged.

**Tech Stack:** AIUI `.ink` pages, WXSS-compatible CSS, Node.js tests.

## Global Constraints

- Keep the single-file `.ink` structure intact.
- Use the existing green design tokens: `rgba(64,255,94,0.2)` for selected background and `transparent` for the selected border.
- Do not change page logic, navigation direction, or unsupported WXSS properties.

---

### Task 1: Add selected-style regression coverage

**Files:**
- Create: `aiui-agent/tests/selection-style.test.cjs`
- Verify: `aiui-agent/pages/scripture/scripture.ink`, `aiui-agent/pages/index/index.ink`, `aiui-agent/pages/meditation/meditation.ink`

- [ ] **Step 1: Write the failing test**

  Assert that scripture's reference selected rule is copied by outer homepage `.menu-item-wrap-selected` and meditation `.type-card-wrap-selected` rules, and that each native card shell is transparent.

- [ ] **Step 2: Run the test to verify it fails**

  Run: `node tests/selection-style.test.cjs` from `aiui-agent`.
  Expected: FAIL because the current selected classes are on the inner card content rather than an outer card wrapper.

### Task 2: Match homepage and meditation selected styles

**Files:**
- Modify: `aiui-agent/pages/index/index.ink` menu markup and selected-card styles
- Modify: `aiui-agent/pages/meditation/meditation.ink` type-card markup and selected-card styles

- [ ] **Step 1: Move selection to the outer card wrapper**

  Use:

  ```css
  background-color: rgba(64,255,94,0.2);
  border-color: transparent;
  ```

  Keep each rule's existing radius and leave page logic unchanged. The native card shell must use `border-width: 0` and `background-color: transparent` so the wrapper supplies the full-card visual.

- [ ] **Step 2: Run the focused test**

  Run: `node tests/selection-style.test.cjs`.
  Expected: PASS.

### Task 3: Verify no interaction regressions

**Files:**
- Verify: `aiui-agent/pages/index/index.ink`, `aiui-agent/pages/meditation/meditation.ink`, `aiui-agent/pages/scripture/scripture.ink`

- [ ] **Step 1: Run style and interaction tests**

  Run: `node tests/selection-style.test.cjs && node tests/touch-direction.test.cjs && node tests/meditation-white-noise.test.cjs` from `aiui-agent`.
  Expected: all commands pass.

- [ ] **Step 2: Check whitespace and the final diff**

  Run: `git diff --check && git diff -- pages/index/index.ink pages/meditation/meditation.ink tests/selection-style.test.cjs` from `aiui-agent`.
  Expected: no whitespace errors and only selected-style declarations plus the regression test are present for this task.
