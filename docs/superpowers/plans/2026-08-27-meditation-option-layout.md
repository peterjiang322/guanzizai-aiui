# Meditation Option Layout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Simplify the meditation method cards by removing the checkmark, enlarging the method name, and placing its description to the right on the same row.

**Architecture:** Keep the existing outer selected-card wrapper, click binding, icon, and data bindings. Use the existing horizontal flex row inside each card, with the name and description as adjacent text nodes; remove only the conditional checkmark.

**Tech Stack:** AIUI `.ink`, WXSS-compatible CSS, Node.js tests.

## Global Constraints

- Preserve card dimensions, selected background, click behavior, and navigation logic.
- Keep the `.ink` structure and `ink:for` / `ink:key` attributes valid.
- Do not use unsupported WXSS features.

---

### Task 1: Add regression coverage

**Files:**
- Modify: `aiui-agent/tests/selection-style.test.cjs`
- Verify: `aiui-agent/pages/meditation/meditation.ink`

- [ ] **Step 1: Assert the requested markup and styles**

  Require no `type-check` markup, require `.type-card` to contain `.type-name` and `.type-desc` as adjacent row content, and require the method name size to be larger than the description size.

- [ ] **Step 2: Run the test to verify it fails**

  Run: `node tests/selection-style.test.cjs` from `aiui-agent`.
  Expected: FAIL because the current template still renders `type-check` and nests the description under `.type-info`.

### Task 2: Update the meditation method card layout

**Files:**
- Modify: `aiui-agent/pages/meditation/meditation.ink`

- [ ] **Step 1: Remove the checkmark and flatten the text row**

  Keep the icon, then render `.type-name` and `.type-desc` directly inside `.type-card`; remove `.type-info` and the conditional `.type-check` node.

- [ ] **Step 2: Set the requested typography**

  Keep the existing green palette, set `.type-name` to `18px`, and set `.type-desc` to `12px` with a muted green color.

- [ ] **Step 3: Run focused verification**

  Run: `node tests/selection-style.test.cjs && node tests/meditation-white-noise.test.cjs` from `aiui-agent`.
  Expected: all tests pass.
