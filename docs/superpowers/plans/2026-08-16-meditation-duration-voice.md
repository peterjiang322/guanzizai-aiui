# 冥想时长预设与语音输入 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use inline execution with the TDD cycle task-by-task.

**Goal:** 为三个共用冥想时长页增加 1、30、60 分钟预设，并支持分钟、小时及小时加分钟的语音时长输入。

**Architecture:** 保持单页 `meditation.ink` 架构不变，只扩展页面常量、纯时长解析函数和现有时长选择逻辑。测试通过现有 VM fixture 加载 `.ink` 的 `<script setup>`，直接验证解析、预设导航和原有冥想行为。

**Tech Stack:** AIUI `.ink`、JavaScript、Node.js built-in `node:test`、Node VM fixture。

## Global Constraints

- 只修改 `pages/meditation/meditation.ink` 和 `tests/meditation-white-noise.test.cjs`。
- 预设顺序固定为 `[1, 5, 10, 20, 30, 60]`。
- 自定义语音时长必须是 1–120 分钟的正整数。
- 语音中的小时按 60 分钟换算，支持小时与分钟组合。
- 保持现有页面生命周期、计时器、音频和三种冥想方式流程不变。
- 不使用不受 AIUI 支持的浏览器输入控件或 WXSS 能力。

---

### Task 1: Add failing duration parsing and preset navigation tests

**Files:**
- Modify: `tests/meditation-white-noise.test.cjs` after `loadMeditation` helper

**Interfaces:**
- Consumes: existing `loadMeditation()` fixture and `page.parseDuration()` / `page.onKeyUp()` interfaces.
- Produces: regression tests that require the new preset list and hour-aware parser.

- [ ] **Step 1: Write the failing tests**

Add these tests after `loadMeditation` and before existing audio tests:

```js
test('parses minute and hour voice durations into bounded minutes', () => {
  const { page } = loadMeditation();

  assert.equal(page.parseDuration('1分钟'), 1);
  assert.equal(page.parseDuration('三十分钟'), 30);
  assert.equal(page.parseDuration('90分钟'), 90);
  assert.equal(page.parseDuration('1小时'), 60);
  assert.equal(page.parseDuration('两小时'), 120);
  assert.equal(page.parseDuration('1小时30分钟'), 90);
  assert.equal(page.parseDuration('一小时十五分钟'), 75);
});

test('rejects invalid or out-of-range voice durations', () => {
  const { page } = loadMeditation();

  assert.equal(page.parseDuration('0分钟'), 0);
  assert.equal(page.parseDuration('121分钟'), 0);
  assert.equal(page.parseDuration('3小时'), 0);
  assert.equal(page.parseDuration('随便坐一会儿'), 0);
});

test('cycles through all six meditation duration presets', () => {
  const { page } = loadMeditation();
  const seen = [];

  for (let i = 0; i < 6; i += 1) {
    seen.push(page.data.durationMinutes);
    page.onKeyUp({ code: 'ArrowDown' });
  }

  assert.deepEqual(seen, [10, 20, 30, 60, 1, 5]);
  assert.equal(page.data.durationMinutes, 10);
});
```

- [ ] **Step 2: Run the focused tests and verify the expected failure**

Run:

```bash
cd /Users/a1/观自在ai智能体/aiui-agent
node --test tests/meditation-white-noise.test.cjs
```

Expected: the new parsing test fails because `1小时` currently returns `1` rather than `60`, and the preset navigation test fails because the current list has only three entries.

### Task 2: Implement bounded hour-aware duration parsing and presets

**Files:**
- Modify: `pages/meditation/meditation.ink` at `PRESET_DURATIONS`, `parseDuration`, `setDuration`, and duration `onKeyUp` navigation

**Interfaces:**
- Consumes: existing `handleVoiceCommand` call to `parseDuration(text)` and `setDuration(mins)`.
- Produces: `parseDuration(text)` returning a valid integer in 1–120 or `0`, and preset navigation using all six values.

- [ ] **Step 1: Update the preset constant**

Change:

```js
var PRESET_DURATIONS = [5, 10, 20];
```

to:

```js
var PRESET_DURATIONS = [1, 5, 10, 20, 30, 60];
```

- [ ] **Step 2: Implement the minimal parser required by the failing tests**

Replace `parseDuration` with a parser that normalizes whitespace, reads Chinese or Arabic numeric tokens, handles `小时` and `分钟` together, falls back to a unitless minute value, and returns `0` unless the final value is an integer between 1 and 120:

```js
parseDuration: function(text) {
  var t = (text || '').replace(/\s/g, '');
  if (!t) { return 0; }

  var parseNumber = function(value) {
    if (!value) { return 0; }
    if (/^\d+$/.test(value)) { return parseInt(value, 10); }
    var digits = {
      '零': 0, '一': 1, '二': 2, '两': 2, '三': 3, '四': 4,
      '五': 5, '六': 6, '七': 7, '八': 8, '九': 9, '十': 10
    };
    if (Object.prototype.hasOwnProperty.call(digits, value)) {
      return digits[value];
    }
    var match = value.match(/^([一二两三四五六七八九])十([一二三四五六七八九])?$/);
    if (match) {
      return digits[match[1]] * 10 + (match[2] ? digits[match[2]] : 0);
    }
    if (value.indexOf('十') === 0) {
      var tail = value.slice(1);
      return 10 + (tail ? (digits[tail] || 0) : 0);
    }
    return 0;
  };

  var hourMinutes = 0;
  var minuteMinutes = 0;
  var hourMatch = t.match(/^(.+?)小时/);
  var minuteMatch = t.match(/小时(.+?)分钟$/);
  if (hourMatch) {
    hourMinutes = parseNumber(hourMatch[1]) * 60;
    if (minuteMatch) { minuteMinutes = parseNumber(minuteMatch[1]); }
  } else {
    var explicitMinutes = t.match(/^(.+?)分钟$/);
    if (explicitMinutes) { minuteMinutes = parseNumber(explicitMinutes[1]); }
    else { minuteMinutes = parseNumber(t); }
  }

  var total = hourMinutes + minuteMinutes;
  return total >= 1 && total <= 120 ? total : 0;
},
```

- [ ] **Step 3: Make custom duration indices safe while preserving the preset loop**

Keep `setDuration(mins)` responsible for the display value, but set `durationIdx` to the exact preset index when matched and otherwise to the nearest lower preset index. The duration `onKeyUp` logic must continue to index `PRESET_DURATIONS.length`, so custom values do not break ArrowUp/ArrowDown.

- [ ] **Step 4: Run the focused tests and verify they pass**

Run:

```bash
cd /Users/a1/观自在ai智能体/aiui-agent
node --test tests/meditation-white-noise.test.cjs
```

Expected: all tests pass, including the existing audio, pause/resume, lifecycle, and shared-player tests.

### Task 3: Run full validation and review the diff

**Files:**
- Verify: `pages/meditation/meditation.ink`
- Verify: `tests/meditation-white-noise.test.cjs`

**Interfaces:**
- Consumes: completed implementation and focused tests.
- Produces: validated source with no unrelated file changes included.

- [ ] **Step 1: Run every repository test**

Run:

```bash
cd /Users/a1/观自在ai智能体/aiui-agent
node --test tests/*.test.cjs tests/*.test.js
```

Expected: all tests pass with zero failures.

- [ ] **Step 2: Run AIUI static checks**

Run:

```bash
cd /Users/a1/观自在ai智能体/aiui-agent
node --check tests/meditation-white-noise.test.cjs
rg -n "PRESET_DURATIONS|parseDuration|小时|分钟|ArrowUp|ArrowDown" pages/meditation/meditation.ink
```

Expected: JavaScript syntax check succeeds; the page contains the six presets, hour/minute parsing, and duration navigation branches.

- [ ] **Step 3: Review the final diff and commit implementation**

Run:

```bash
cd /Users/a1/观自在ai智能体/aiui-agent
git diff --check
git diff -- pages/meditation/meditation.ink tests/meditation-white-noise.test.cjs
git status --short
```

Confirm that the implementation commit contains only the requested page and test changes, while pre-existing unrelated working-tree changes remain untouched.
