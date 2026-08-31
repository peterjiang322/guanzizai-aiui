# Scripture ASR Aliases Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Open four full scriptures from their approved spoken short names on the scripture page.

**Architecture:** Extend the existing table-driven alias map and its VM-based voice-command regression test. Keep the current ASR lifecycle and loading flow unchanged.

**Tech Stack:** AIUI `.ink` SFC, JavaScript alias map, Node.js built-in `node:test`.

## Global Constraints

- `华严经` maps to `huayan-selections`.
- `法华经` maps to `lotus-sutra`.
- `药师经` maps to `medicine-buddha-sutra`.
- `楞严经` maps to `shurangama-sutra`.
- Do not add `莲华经` as an alias.
- Do not modify ASR lifecycle, scripture loading, touch navigation, or unrelated home-page work.

---

### Task 1: Add and verify the approved scripture aliases

**Files:**
- Modify: `tests/scripture-voice-startup.test.cjs`
- Modify: `pages/scripture/scripture.ink:231-238`

**Interfaces:**
- Consumes: Normalized ASR transcript passed to `handleVoiceCommand(text)`.
- Produces: The matching scripture object passed to `loadScripture(item)`.

- [ ] **Step 1: Extend the failing alias test**

Add the four target scripture fixtures:

```javascript
{ id: 'huayan-selections', name: '大方广佛华严经（三品节选）' },
{ id: 'lotus-sutra', name: '妙法莲华经' },
{ id: 'medicine-buddha-sutra', name: '药师琉璃光如来本愿功德经' },
{ id: 'shurangama-sutra', name: '大佛顶首楞严经' }
```

Add a focused test:

```javascript
test('approved short scripture names open the matching full scripture', () => {
  const fixture = createFixture();
  const opened = [];
  fixture.page.data.scriptures = SCRIPTURES;
  fixture.page.loadScripture = item => opened.push(item.id);

  fixture.page.handleVoiceCommand('打开华严经');
  fixture.page.handleVoiceCommand('打开法华经');
  fixture.page.handleVoiceCommand('打开药师经');
  fixture.page.handleVoiceCommand('打开楞严经');

  assert.deepEqual(opened, [
    'huayan-selections',
    'lotus-sutra',
    'medicine-buddha-sutra',
    'shurangama-sutra'
  ]);
  assert.equal(scriptureSource.includes('"莲华经":'), false);
});
```

- [ ] **Step 2: Run the focused test and verify RED**

Run: `node --test tests/scripture-voice-startup.test.cjs`

Expected: FAIL because `华严经` is not yet mapped to `huayan-selections`; the other three aliases already resolve.

- [ ] **Step 3: Add the minimal production mapping**

Add this entry to the existing `aliases` object:

```javascript
"华严经": "huayan-selections",
```

Keep the existing `法华经`, `药师经`, and `楞严经` entries unchanged. Do not add `莲华经`.

- [ ] **Step 4: Run the focused test and verify GREEN**

Run: `node --test tests/scripture-voice-startup.test.cjs`

Expected: All scripture voice tests pass.

- [ ] **Step 5: Run regression and static checks**

Run: `node tests/checkin.test.js`

Expected: `checkin tests passed`.

Run: `node --test tests/home-voice-hold-hint.test.cjs tests/meditation-white-noise.test.cjs tests/scripture-voice-startup.test.cjs`

Expected: All Node test cases pass with zero failures.

Run: `git diff --check`

Expected: No whitespace errors.

- [ ] **Step 6: Review and commit the scoped change**

Run: `git diff -- pages/scripture/scripture.ink tests/scripture-voice-startup.test.cjs`

Expected: One new production alias plus focused test fixtures/assertions; no ASR lifecycle changes.

Commit only those two files with message `feat: add scripture voice aliases`.
