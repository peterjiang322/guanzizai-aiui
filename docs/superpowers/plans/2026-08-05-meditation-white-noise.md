# Meditation White Noise Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the standalone white-noise entry and play one random local white-noise track at 15% volume for the lifetime of each meditation session.

**Architecture:** Keep the existing standalone soundscape source and assets, but unregister its route and remove every home-page entry point. Add a shared `wx._bgm` playback layer to `meditation.ink`: prefer the project-verified `AudioPlayer`, fall back to `Sound`, retain the chosen track across pause/resume and page transitions, and stop the shared instance only when the meditation countdown completes.

**Tech Stack:** AIUI `.ink` SFC, `AudioPlayer`, `Sound`, Node.js built-in `node:test`, Git.

## Global Constraints

- All audio sources are local files under `assets/`.
- Playback volume is exactly `0.15`.
- One of the six existing WAV files is selected once per meditation session.
- Pause and resume keep the same selected track.
- `wx._bgm` is the shared singleton; `AudioPlayer` is preferred and `Sound` is the fallback.
- Timers and media instances are cleaned up on completion and reset; `wx._bgm` is deliberately retained across `onHide` / `onUnload` page transitions.
- `pages/soundscape/soundscape.ink` and all six WAV files remain in the repository.
- Do not introduce browser-only APIs or unsupported AIUI template/CSS syntax.

---

### Task 1: Add executable feature-contract tests

**Files:**
- Create: `tests/meditation-white-noise.test.cjs`
- Read: `pages/index/index.ink`
- Read: `pages/meditation/meditation.ink`
- Read: `app.json`

**Interfaces:**
- Consumes: the existing `.ink` `<script setup>` page object and `app.json` routes.
- Produces: a Node test suite that loads the page object in `vm`, provides fake `AudioPlayer` / `Sound` implementations, captures timer callbacks, and verifies route, menu, random playback, volume, pause/resume, completion, and fallback behavior.

- [ ] **Step 1: Write the failing tests**

Create a `node:test` suite with these concrete assertions:

```js
test('standalone white-noise entry is removed but its source remains', () => {
  assert.equal(app.pages.includes('pages/soundscape/soundscape'), false);
  assert.equal(indexSource.includes('/pages/soundscape/soundscape'), false);
  assert.equal(indexSource.includes('白噪音'), false);
  assert.equal(fs.existsSync(soundscapeFile), true);
});

test('a meditation starts one AudioPlayer track at 15 percent volume', () => {
  const fixture = loadMeditation({ random: () => 0 });
  fixture.page.data.durationMinutes = 5;
  fixture.page.startMeditation();
  assert.equal(fixture.players.length, 1);
  assert.equal(fixture.players[0].src, '../../assets/morning_temple.wav');
  assert.equal(fixture.players[0].loop, false);
  assert.equal(fixture.players[0].volume, 0.15);
});

test('pause and resume control the same AudioPlayer instance', () => {
  const fixture = loadMeditation({ random: () => 0.5 });
  fixture.page.startMeditation();
  const player = fixture.players[0];
  fixture.page.togglePause();
  assert.equal(player.pauseCalls, 1);
  fixture.page.togglePause();
  assert.equal(player.playCalls, 2);
  assert.equal(fixture.players.length, 1);
});

test('countdown completion stops and destroys playback', () => {
  const fixture = loadMeditation({ random: () => 0 });
  fixture.page.startMeditation();
  const player = fixture.players[0];
  fixture.page.data.remainingSeconds = 1;
  fixture.runLatestInterval();
  assert.equal(player.stopCalls, 1);
  assert.equal(player.destroyCalls, 1);
  assert.equal(fixture.page.data.status, 'completed');
});

test('Sound fallback uses the selected local track at 15 percent volume', () => {
  const fixture = loadMeditation({ audioPlayerUnavailable: true, random: () => 0 });
  fixture.page.startMeditation();
  assert.equal(fixture.sounds.length, 1);
  assert.equal(fixture.sounds[0].src, '../../assets/morning_temple.wav');
  assert.equal(fixture.sounds[0].volume, 0.15);
});
```

- [ ] **Step 2: Run the suite and verify RED**

Run: `node --test tests/meditation-white-noise.test.cjs`

Expected: FAIL because the white-noise route/menu still exist and `meditation.ink` has no playback state machine.

- [ ] **Step 3: Commit the failing tests**

```bash
git add tests/meditation-white-noise.test.cjs
git commit -m "test: define meditation white noise behavior"
```

### Task 2: Remove the standalone white-noise entry points

**Files:**
- Modify: `app.json`
- Modify: `pages/index/index.ink`
- Test: `tests/meditation-white-noise.test.cjs`

**Interfaces:**
- Consumes: the home page `menus`, voice command router, welcome prompt, and app route list.
- Produces: a four-item home page with no route or copy that opens the standalone white-noise page.

- [ ] **Step 1: Remove the registered route**

Change `app.json` so `pages` contains only:

```json
[
  "pages/index/index",
  "pages/scripture/scripture",
  "pages/chat/chat",
  "pages/meditation/meditation",
  "pages/muyu/muyu"
]
```

- [ ] **Step 2: Remove home-page menu, voice route, and copy**

Delete the `soundscape` menu item and the `白噪音/禅境/声音/音景` command branch. Update the status, welcome TTS, description, and bottom hint to list only `读经文`, `敲木鱼`, `冥想`, and `聊佛法`.

- [ ] **Step 3: Run the focused entry-point test**

Run: `node --test --test-name-pattern="standalone white-noise entry" tests/meditation-white-noise.test.cjs`

Expected: PASS.

- [ ] **Step 4: Commit entry-point removal**

```bash
git add app.json pages/index/index.ink tests/meditation-white-noise.test.cjs
git commit -m "feat: retire standalone white noise entry"
```

### Task 3: Integrate random background audio with the meditation lifecycle

**Files:**
- Modify: `pages/meditation/meditation.ink`
- Test: `tests/meditation-white-noise.test.cjs`

**Interfaces:**
- Consumes: `startMeditation()`, `togglePause()`, `startTimer()`, `resetMeditation()`, `onHide()`, and the six local WAV assets.
- Produces: `selectMeditationTrack()`, `startMeditationAudio(track)`, `pauseMeditationAudio()`, `resumeMeditationAudio()`, `stopMeditationAudio(clearTrack)`, `clearAudioLoop()`, and `releaseAudioPlayer()`.

- [ ] **Step 1: Define the six-track local pool and durations**

Add immutable page-level data shaped as:

```js
var MEDITATION_AUDIO_TRACKS = [
  { file: "morning_temple.wav", path: "../../assets/morning_temple.wav", loopMs: 3000 },
  { file: "rain_zen.wav", path: "../../assets/rain_zen.wav", loopMs: 3000 },
  { file: "stream_forest.wav", path: "../../assets/stream_forest.wav", loopMs: 7000 },
  { file: "ocean_mindfulness.wav", path: "../../assets/ocean_mindfulness.wav", loopMs: 4000 },
  { file: "night_temple.wav", path: "../../assets/night_temple.wav", loopMs: 10000 },
  { file: "incense_chamber.wav", path: "../../assets/incense_chamber.wav", loopMs: 3000 }
];
```

- [ ] **Step 2: Implement selection and the compatible playback layer**

`selectMeditationTrack()` clamps `Math.floor(Math.random() * 6)` to `0..5`. `startMeditationAudio(track)` first reuses `wx._bgm` when present; otherwise it creates `AudioPlayer`, assigns it to `wx._bgm`, sets `loop = false` and `volume = 0.15`, calculates `ceil(totalSeconds * 1000 / loopMs)` plays, and uses a duration-based interval to replay the same track. If unavailable, it stores the `Sound` fallback in `wx._bgm` and uses the same calculated replay schedule.

- [ ] **Step 3: Bind pause/resume and termination paths**

Call `startMeditationAudio(selectMeditationTrack())` once from `startMeditation()`. Call `pauseMeditationAudio()` and `resumeMeditationAudio()` from the matching `togglePause()` branches. Call `stopMeditationAudio(true)` when the countdown reaches zero and from `resetMeditation()`. In `onHide()` / `onUnload()`, clean up recognition only and leave `wx._bgm` plus the countdown alive so page transitions do not interrupt playback.

- [ ] **Step 4: Run the complete suite and verify GREEN**

Run: `node --test tests/meditation-white-noise.test.cjs`

Expected: all tests PASS with no warnings.

- [ ] **Step 5: Run AIUI static guards**

```bash
jq -e . app.json
sed -n '/<script def>/,/<\/script>/p' pages/meditation/meditation.ink | sed '1d;$d' | jq -e .
rg -n 'volume = 0\.3|loop = true|onHide|onUnload|stopMeditationAudio' pages/meditation/meditation.ink
test -f pages/soundscape/soundscape.ink
test -f assets/morning_temple.wav
test -f assets/rain_zen.wav
test -f assets/stream_forest.wav
test -f assets/ocean_mindfulness.wav
test -f assets/night_temple.wav
test -f assets/incense_chamber.wav
```

Expected: JSON checks succeed, lifecycle/audio symbols are present, and all retained files exist.

- [ ] **Step 6: Commit the feature**

```bash
git add pages/meditation/meditation.ink
git commit -m "feat: add white noise to meditation sessions"
```

### Task 4: Final regression and review

**Files:**
- Review: `app.json`
- Review: `pages/index/index.ink`
- Review: `pages/meditation/meditation.ink`
- Review: `tests/meditation-white-noise.test.cjs`

**Interfaces:**
- Consumes: all changes from Tasks 1-3.
- Produces: a clean, reviewed Git history and evidence that the feature matches the approved design.

- [ ] **Step 1: Run the full feature suite**

Run: `node --test tests/meditation-white-noise.test.cjs`

Expected: all tests PASS.

- [ ] **Step 2: Inspect repository state and diff**

Run: `git status --short && git log --oneline --decorate -5 && git diff HEAD~3..HEAD --check`

Expected: clean status, three implementation commits after the plan commit, and no whitespace errors.

- [ ] **Step 3: Perform read-only code review**

Verify exact requirement coverage, AIUI lifecycle cleanup, fallback behavior, absence of unrelated edits, and preservation of the retired page and assets. Fix any Critical or Important issue and rerun Step 1.
