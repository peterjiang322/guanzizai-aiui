# Scripture Voice Startup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let users enter the scripture page by voice and then open a named scripture without first touching or swiping the page.

**Architecture:** Gate the first ASR session on both page visibility and scripture-list readiness, sequence it after the spoken prompt with one managed timer, and report listening only from the recognition object's real `onstart` callback. Use recognition-instance and lifecycle guards so aborted sessions cannot schedule stale retries.

**Tech Stack:** AIUI `.ink` SFC, `SpeechRecognition`, `SpeechSynthesisUtterance`, `wx.request`, Node.js built-in `node:test` and `vm`.

## Global Constraints

- The startup order must be list ready → spoken prompt → estimated prompt completion → ASR start.
- `statusText` must become `正在听...` only after the active recognition instance emits `onstart`.
- `onHide` and `onUnload` must clear timers, abort recognition, and prevent stale callbacks.
- Preserve the existing scripture-name matching and touch navigation behavior.
- Do not modify the home-page changes or the user's uncommitted check-in work.

---

### Task 1: Fix scripture voice startup sequencing

**Files:**
- Create: `tests/scripture-voice-startup.test.cjs`
- Modify: `pages/scripture/scripture.ink:27-254`

**Interfaces:**
- Consumes: `wx.request` scripture list response, page visibility lifecycle, `SpeechRecognition` events, and spoken scripture-name text.
- Produces: `beginVoicePrompt()`, `scheduleRecognition(ms)`, `cleanupRecognition()`, and guarded ASR lifecycle behavior.

- [ ] **Step 1: Write the failing lifecycle tests**

Create a `node:test` VM fixture that extracts `<script setup>` from `pages/scripture/scripture.ink`, supplies fake `wx`, timers, TTS, and `SpeechRecognition`, and executes the exported page object. Add these assertions:

```javascript
test('waits for scripture data and prompt completion before listening', () => {
  const fixture = createFixture();
  fixture.page.onLoad();
  fixture.page.onShow();
  assert.equal(fixture.utterances.length, 0);
  assert.equal(fixture.recognitions.length, 0);

  fixture.resolveScriptures(SCRIPTURES);
  assert.equal(fixture.utterances[0], '请说出你想诵读的经文名称');
  assert.equal(fixture.recognitions.length, 0);

  fixture.runNextTimer();
  assert.equal(fixture.recognitions.length, 1);
  assert.equal(fixture.page.data.listening, false);
  assert.notEqual(fixture.page.data.statusText, '正在听...');

  fixture.recognitions[0].onstart();
  assert.equal(fixture.page.data.listening, true);
  assert.equal(fixture.page.data.statusText, '正在听...');
});
```

```javascript
test('hiding cancels a pending first listen', () => {
  const fixture = createFixture();
  fixture.page.onLoad();
  fixture.page.onShow();
  fixture.resolveScriptures(SCRIPTURES);
  fixture.page.onHide();
  fixture.runAllTimers();
  assert.equal(fixture.recognitions.length, 0);
  assert.equal(fixture.page.data.listening, false);
});
```

```javascript
test('common spoken scripture names open the matching item', () => {
  const fixture = createFixture();
  const opened = [];
  fixture.page.data.scriptures = SCRIPTURES;
  fixture.page.loadScripture = item => opened.push(item.id);
  fixture.page.handleVoiceCommand('我要读心经');
  fixture.page.handleVoiceCommand('打开金刚经');
  fixture.page.handleVoiceCommand('诵读大悲咒');
  assert.deepEqual(opened, ['heart-sutra', 'diamond-sutra', 'great-compassion-mantra']);
});
```

- [ ] **Step 2: Run the focused test and verify RED**

Run: `node --test tests/scripture-voice-startup.test.cjs`

Expected: The startup test fails because current `onLoad` speaks immediately and current `onShow` starts recognition before the list response.

- [ ] **Step 3: Implement the minimal lifecycle fix**

Add instance state:

```javascript
_restartTimer: null,
_hidden: true,
_scripturesReady: false,
_voiceFlowStarted: false,
_lifecycleGeneration: 0,
```

Change lifecycle behavior so `onLoad` only loads the list, `onShow` marks the page visible and calls `beginVoicePrompt()`, and `onHide`/`onUnload` invalidate the lifecycle and clean up recognition.

Add the startup gate and one managed timer:

```javascript
beginVoicePrompt: function() {
  if (this._hidden || !this._scripturesReady || this._voiceFlowStarted) return;
  this._voiceFlowStarted = true;
  var prompt = '请说出你想诵读的经文名称';
  this.speak(prompt);
  this.scheduleRecognition(Math.max(prompt.length * 90 + 400, 800));
},

scheduleRecognition: function(ms) {
  var self = this;
  var generation = this._lifecycleGeneration;
  if (this._restartTimer) clearTimeout(this._restartTimer);
  this._restartTimer = setTimeout(function() {
    self._restartTimer = null;
    if (!self._hidden && self._scripturesReady && generation === self._lifecycleGeneration) {
      self.startRecognition();
    }
  }, ms);
},
```

Update `startRecognition()` to create a fresh recognition instance, set `listening` only in `onstart`, and ignore callbacks unless the instance and lifecycle generation are current. Route `onresult`, `onerror`, `onnomatch`, and `onend` through `scheduleRecognition()` so only one retry remains pending.

In the scripture-list success callback, set `_scripturesReady = list.length > 0`, update `scriptures`, and call `beginVoicePrompt()`; on failure keep `_scripturesReady = false`.

- [ ] **Step 4: Run the focused test and verify GREEN**

Run: `node --test tests/scripture-voice-startup.test.cjs`

Expected: All scripture startup and name-matching tests pass.

- [ ] **Step 5: Run all existing regression tests**

Run: `node tests/checkin.test.js`

Expected: `checkin tests passed`.

Run: `node --test tests/home-voice-hold-hint.test.cjs tests/meditation-white-noise.test.cjs tests/scripture-voice-startup.test.cjs`

Expected: All Node test cases pass with zero failures.

- [ ] **Step 6: Run static and scoped review checks**

Run: `git diff --check`

Expected: No whitespace errors.

Run: `git diff -- pages/scripture/scripture.ink tests/scripture-voice-startup.test.cjs`

Expected: Only the scripture voice lifecycle, list-ready gate, and focused tests are new; no unrelated page behavior changes.

- [ ] **Step 7: Perform device verification**

On Rokid glasses: long-press and say “读经文”; after the prompt finishes, say “心经”, “金刚经”, and “大悲咒” in separate runs. Each must open directly without a touch gesture. This remains a manual deployment check if no device is attached.
