# Home Voice Hold Hint Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the home page's upper and lower idle voice prompts tell users to long-press touch before speaking a supported command.

**Architecture:** Keep the existing AIUI page structure and voice state machine unchanged. Add a focused source-level regression test, then replace only the two user-facing strings in `pages/index/index.ink`.

**Tech Stack:** AIUI `.ink` SFC, Node.js built-in `node:test`, Git.

## Global Constraints

- Both prompts must read exactly `长按触摸后，说「读经文」「敲木鱼」「冥想」「聊佛法」进入`.
- Do not change welcome TTS, `onVoiceWakeup`, recognition lifecycle, menu navigation, or styles.
- Preserve the existing uncommitted check-in changes in `pages/index/index.ink` and `tests/checkin.test.js`.
- Keep AIUI template control attributes on the `ink:` prefix; this copy-only change must not introduce template directives.

---

### Task 1: Update and verify both home voice prompts

**Files:**
- Create: `tests/home-voice-hold-hint.test.cjs`
- Modify: `pages/index/index.ink:66`
- Modify: `pages/index/index.ink:398`

**Interfaces:**
- Consumes: UTF-8 source text from `pages/index/index.ink`.
- Produces: An initial `data.statusText` value and a bottom `.hint` text node containing the exact approved copy.

- [ ] **Step 1: Write the failing test**

```javascript
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const projectRoot = path.resolve(__dirname, '..');
const indexSource = fs.readFileSync(path.join(projectRoot, 'pages/index/index.ink'), 'utf8');
const prompt = '长按触摸后，说「读经文」「敲木鱼」「冥想」「聊佛法」进入';

test('home shows the approved long-press voice prompt above and below', () => {
  assert.match(indexSource, new RegExp('statusText: "' + prompt + '"'));
  assert.match(indexSource, new RegExp('<text class="hint">' + prompt + '</text>'));
  assert.equal(indexSource.split(prompt).length - 1, 2);
});
```

- [ ] **Step 2: Run the focused test and verify RED**

Run: `node --test tests/home-voice-hold-hint.test.cjs`

Expected: FAIL because the approved long-press prompt is not yet present in `pages/index/index.ink`.

- [ ] **Step 3: Apply the minimal copy change**

Replace the initial state with:

```javascript
statusText: "长按触摸后，说「读经文」「敲木鱼」「冥想」「聊佛法」进入",
```

Replace the bottom hint with:

```html
<text class="hint">长按触摸后，说「读经文」「敲木鱼」「冥想」「聊佛法」进入</text>
```

- [ ] **Step 4: Run focused and regression tests and verify GREEN**

Run: `node --test tests/home-voice-hold-hint.test.cjs`

Expected: PASS with 1 test passing.

Run: `node tests/checkin.test.js && node --test tests/meditation-white-noise.test.cjs`

Expected: Both existing test commands exit successfully with no failures.

- [ ] **Step 5: Run static checks**

Run: `git diff --check`

Expected: No whitespace errors.

Run: `rg -n '长按触摸后，说「读经文」「敲木鱼」「冥想」「聊佛法」进入' pages/index/index.ink`

Expected: Exactly two matches, one in initial `statusText` and one in the bottom `.hint`.

- [ ] **Step 6: Review the scoped diff**

Run: `git diff -- pages/index/index.ink tests/home-voice-hold-hint.test.cjs`

Expected: The production diff changes only the two approved strings; unrelated pre-existing check-in changes remain intact.
