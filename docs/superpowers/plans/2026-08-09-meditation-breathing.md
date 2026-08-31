# 冥想倒计时呼吸效果 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans (recommended). Steps use checkbox (`- [ ]`) syntax.

**Goal:** Add a JavaScript-driven six-second breathing fade that synchronizes the meditation countdown and outer timer ring.

**Architecture:** Keep the existing `ringOpacity` binding and add a page-owned 100ms interval with a persisted phase. The interval applies a triangular brightness wave on top of the existing elapsed-time base opacity; lifecycle methods start, pause, resume, and clear it with the meditation state.

**Tech Stack:** AIUI `.ink`, `setData`, JavaScript `setInterval`/`clearInterval`, Node `node:test` VM fixtures.

## Global Constraints

- Do not use WXSS `animation`; AIUI WXSS does not support it.
- Breath cycle is 6 seconds: 3 seconds dimming and 3 seconds brightening.
- Breath factor ranges from 0.20 to 1.0 and updates every 100ms.
- A separate green outline halo follows the same phase without using blurred shadows.
- The halo scales from approximately `0.96` at the dim phase to `1.08` at the bright phase.
- Halo size uses explicit `width`/`height` and matching `left`/`top` offsets in a 194px stage; no CSS transform is used, so the center remains fixed at `(97, 97)`.
- The fixed timer border, progress background, and inner circular fill are transparent; only the countdown text and dynamic halo remain visible.
- The existing elapsed-time ring fade remains the base opacity.
- Running starts the interval; paused, completed, and idle states do not keep it running.

### Task 1: Add failing breathing lifecycle tests

**Files:**
- Modify: `tests/meditation-white-noise.test.cjs`

**Interfaces:**
- Consumes: `page.startMeditation()`, `page.togglePause()`, `page.resetMeditation()`, countdown interval fixture.
- Produces: `runBreathInterval()` fixture helper and assertions for `_breathTimer`, phase-driven opacity, pause/resume, completion, and reset.

- [ ] **Step 1: Add `runBreathInterval()` and tests**

```js
runBreathInterval() {
  const id = this.page._breathTimer;
  assert.ok(id, 'expected an active breathing interval');
  const handler = intervals.get(id);
  assert.equal(typeof handler, 'function');
  handler();
}
```

Add tests that expect the first breath tick to lower opacity below `1`, later ticks to reach the dim phase, and subsequent ticks to brighten again. Assert pause clears `_breathTimer` without changing opacity, resume restores one timer, and completion/reset clear the timer and restore opacity `1`.

- [ ] **Step 2: Run the focused test file and verify RED**

Run: `node --test tests/meditation-white-noise.test.cjs`

Expected: new breathing assertions fail because `_breathTimer` and the breathing lifecycle do not exist yet.

### Task 2: Implement the phase-based breathing controller

**Files:**
- Modify: `pages/meditation/meditation.ink:70-75,300-330`

**Interfaces:**
- Consumes: existing `updateRingStyle(pct, elapsedSec)` and `ringOpacity` data binding.
- Produces: `startBreathing(resetPhase)`, `stopBreathing(resetVisual)`, `applyBreathingOpacity()`, and `_breathPhase`/`_breathTimer` page state.

- [ ] **Step 1: Add state and helpers**

Use a normalized phase increment of `0.1 / 6` per 100ms tick. Map the triangular wave to `0.20 + 0.80 * wave`, multiply by the existing elapsed-time base opacity, and call `setData({ ringOpacity, haloStyle })`.

- [ ] **Step 2: Run the focused tests and verify GREEN**

Run: `node --test tests/meditation-white-noise.test.cjs`

Expected: breathing math and direct helper tests pass; lifecycle tests may still fail until Task 3 connects the helpers.

### Task 3: Connect breathing to meditation lifecycle

**Files:**
- Modify: `pages/meditation/meditation.ink:650-755`

**Interfaces:**
- Consumes: `startBreathing`, `stopBreathing`, timer completion, reset, and pause/resume branches.
- Produces: exactly one active breath interval while meditation is running.

- [ ] **Step 1: Start and stop at lifecycle boundaries**

Start breathing after `startMeditation()` initializes the ring. Pause clears the interval but preserves phase and opacity; resume restarts it without resetting phase. Completion and reset clear it and set opacity to `1`.

- [ ] **Step 2: Run all tests and verify GREEN**

Run: `node --test tests/*.test.cjs`

Expected: all existing audio, countdown, route, and new breathing tests pass.

### Task 4: Verify static constraints and commit

**Files:**
- Verify: `pages/meditation/meditation.ink`, `docs/superpowers/specs/2026-08-09-meditation-breathing-design.md`

- [ ] **Step 1: Run static checks**

Run: `git diff --check` and `rg -n 'animation|_breathTimer|ringOpacity' pages/meditation/meditation.ink`

Expected: no diff errors; breathing uses JavaScript timers and no new WXSS animation.

- [ ] **Step 2: Commit**

```bash
git add pages/meditation/meditation.ink tests/meditation-white-noise.test.cjs
git commit -m "feat: add meditation timer breathing effect"
```
