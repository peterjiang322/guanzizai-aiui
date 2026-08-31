# Scripture Back and Selection Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Keep double-touch back inside the scripture page when reading details and make unselected scripture cards retain their borders.

**Architecture:** Intercept the host's `Backspace` default in the page-level `onKeyUp`, track double-touch timing synchronously on the page instance, and express card selection with stable CSS classes instead of a long inline ternary style.

**Tech Stack:** AIUI `.ink` SFC, page-level key events, WXSS, Node.js built-in `node:test` and `vm`.

## Global Constraints

- Detail-view double `Backspace` returns to the scripture list without calling `wx.navigateBack()`.
- List-view double `Backspace` continues to call `wx.navigateBack()` once.
- Every `Backspace` handled by the page calls `event.preventDefault()`.
- The current card has a transparent border and green translucent background.
- Every unselected card has a `1px` translucent green border.
- Preserve ASR lifecycle, scripture aliases, loading, pagination, and unrelated home-page work.

---

### Task 1: Fix double-touch back behavior

**Files:**
- Modify: `tests/scripture-voice-startup.test.cjs`
- Modify: `pages/scripture/scripture.ink:25-68`
- Modify: `pages/scripture/scripture.ink:335-348`
- Modify: `pages/scripture/scripture.ink:407-470`

**Interfaces:**
- Consumes: page-level `Backspace` keyup events and their `preventDefault()` method.
- Produces: `handleBack()` for detail-to-list and `wx.navigateBack()` for list-to-home.

- [ ] **Step 1: Write failing back-navigation tests**

Extend the VM fixture so `wx.navigateBack()` increments a counter. Add tests that:

```javascript
test('detail backspace is intercepted and double-touch returns only to the list', () => {
  const fixture = createFixture();
  let prevented = 0;
  const event = { code: 'Backspace', preventDefault() { prevented += 1; } };
  fixture.page.data.showingDetail = true;

  fixture.page.onKeyUp(event);
  fixture.page.onKeyUp(event);

  assert.equal(prevented, 2);
  assert.equal(fixture.page.data.showingDetail, false);
  assert.equal(fixture.navigateBackCalls(), 0);
});
```

```javascript
test('double-touch timing does not depend on asynchronous setData', () => {
  const fixture = createFixture();
  const patches = [];
  fixture.page.data.showingDetail = true;
  fixture.page.setData = patch => patches.push(patch);

  fixture.page.handleBackspace();
  fixture.page.handleBackspace();

  assert.equal(patches.some(patch => patch.showingDetail === false), true);
});
```

```javascript
test('list double backspace is intercepted and returns to the home page', () => {
  const fixture = createFixture();
  let prevented = 0;
  const event = { code: 'Backspace', preventDefault() { prevented += 1; } };
  fixture.page.data.showingDetail = false;

  fixture.page.onKeyUp(event);
  fixture.page.onKeyUp(event);

  assert.equal(prevented, 2);
  assert.equal(fixture.navigateBackCalls(), 1);
});
```

- [ ] **Step 2: Run focused tests and verify RED**

Run: `node --test tests/scripture-voice-startup.test.cjs`

Expected: Back-navigation tests fail because `preventDefault()` is not called and double-touch timing depends on asynchronous `setData()`.

- [ ] **Step 3: Implement the minimal back fix**

Replace the render-state timestamp with an instance field:

```javascript
_lastBackspaceTime: 0,
```

Update `handleBackspace()` to read and write `this._lastBackspaceTime` synchronously. At the start of `onKeyUp(event)`, intercept `Backspace`:

```javascript
var code = event.code;
if (code === "Backspace") {
  event.preventDefault();
}
```

Keep the existing detail/list target branches in `handleBackspace()`.

- [ ] **Step 4: Run focused tests and verify GREEN for back behavior**

Run: `node --test tests/scripture-voice-startup.test.cjs`

Expected: All existing and new back-navigation tests pass.

---

### Task 2: Invert and stabilize scripture card borders

**Files:**
- Modify: `tests/scripture-voice-startup.test.cjs`
- Modify: `pages/scripture/scripture.ink:532`
- Modify: `pages/scripture/scripture.ink:578`

**Interfaces:**
- Consumes: `selectedIdx` and each list item's `index`.
- Produces: base `.card-wrap` styling for unselected cards and `.card-wrap-selected` styling for the current card.

- [ ] **Step 1: Write the failing template/style test**

```javascript
test('only unselected scripture cards retain a visible border', () => {
  assert.match(scriptureSource, /class="card-wrap \{\{index === selectedIdx \? 'card-wrap-selected' : ''\}\}"/);
  assert.match(scriptureSource, /\.card-wrap \{[^}]*border: 1px solid rgba\(64,255,94,0\.5\);/s);
  assert.match(scriptureSource, /\.card-wrap-selected \{[^}]*background-color: rgba\(64,255,94,0\.2\);[^}]*border-color: transparent;/s);
  assert.equal(scriptureSource.includes('style="{{index === selectedIdx ?'), false);
});
```

- [ ] **Step 2: Run focused tests and verify RED**

Run: `node --test tests/scripture-voice-startup.test.cjs`

Expected: The card-style test fails because the current template gives selected cards a visible border and unselected cards a transparent one.

- [ ] **Step 3: Implement the minimal card class change**

Use this list wrapper:

```html
<view ink:for="{{scriptures}}" ink:key="id" class="card-wrap {{index === selectedIdx ? 'card-wrap-selected' : ''}}">
```

Use stable-width styles:

```css
.card-wrap {
  border: 1px solid rgba(64,255,94,0.5);
}
.card-wrap-selected {
  background-color: rgba(64,255,94,0.2);
  border-color: transparent;
}
```

Retain all existing `.card-wrap` layout, spacing, radius, and height declarations.

- [ ] **Step 4: Run focused and full regression tests**

Run: `node --test tests/scripture-voice-startup.test.cjs`

Expected: All scripture tests pass.

Run: `node tests/checkin.test.js`

Expected: `checkin tests passed`.

Run: `node --test tests/home-voice-hold-hint.test.cjs tests/meditation-white-noise.test.cjs tests/scripture-voice-startup.test.cjs`

Expected: All Node test cases pass with zero failures.

- [ ] **Step 5: Run static checks and review the scoped diff**

Run: `git diff --check`

Expected: No whitespace errors.

Run: `git diff -- pages/scripture/scripture.ink tests/scripture-voice-startup.test.cjs`

Expected: Only Backspace handling, synchronous double-touch timing, card selection classes/styles, and tests change.

- [ ] **Step 6: Commit the completed fix**

Commit only the scripture page and its test with message `fix: correct scripture back and card selection`.
