const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

const projectRoot = path.resolve(__dirname, '..');
const scriptureFile = path.join(projectRoot, 'pages/scripture/scripture.ink');
const scriptureSource = fs.readFileSync(scriptureFile, 'utf8');

const SCRIPTURES = [
  { id: 'heart-sutra', name: '般若波罗蜜多心经' },
  { id: 'diamond-sutra', name: '金刚般若波罗蜜经' },
  { id: 'great-compassion-mantra', name: '大悲咒' },
  { id: 'huayan-selections', name: '大方广佛华严经（三品节选）' },
  { id: 'lotus-sutra', name: '妙法莲华经' },
  { id: 'medicine-buddha-sutra', name: '药师琉璃光如来本愿功德经' },
  { id: 'shurangama-sutra', name: '大佛顶首楞严经' }
];

function extractPageScript(source) {
  const match = source.match(/<script setup>([\s\S]*?)<\/script>/);
  assert.ok(match, 'expected a <script setup> block');
  return match[1]
    .replace(/import wx from ['"]wx['"];?/, '')
    .replace('export default {', 'globalThis.__page = {');
}

function createFixture() {
  const timers = new Map();
  const requests = [];
  const recognitions = [];
  const utterances = [];
  let nextTimerId = 1;
  let navigateBackCount = 0;

  class FakeRecognition {
    constructor() {
      this.startCalls = 0;
      this.abortCalls = 0;
      recognitions.push(this);
    }

    start() {
      this.startCalls += 1;
    }

    abort() {
      this.abortCalls += 1;
    }
  }

  class FakeUtterance {
    constructor(text) {
      this.text = text || '';
    }
  }

  const wx = {
    request(options) {
      requests.push(options);
    },
    navigateBack() {
      navigateBackCount += 1;
    },
    speech: {
      playTTS(text) {
        utterances.push(text);
      }
    }
  };

  const context = {
    console,
    Date,
    Math,
    SpeechRecognition: FakeRecognition,
    SpeechSynthesisUtterance: FakeUtterance,
    speechSynthesis: {
      speak(utterance) {
        utterances.push(utterance.text);
      }
    },
    wx,
    getApp() {
      return { globalData: { baseUrl: 'https://example.test' } };
    },
    setTimeout(handler, ms) {
      const id = nextTimerId++;
      timers.set(id, { handler, ms });
      return id;
    },
    clearTimeout(id) {
      timers.delete(id);
    }
  };
  context.globalThis = context;

  vm.runInNewContext(extractPageScript(scriptureSource), context, { filename: scriptureFile });
  const page = context.__page;
  page.data = { ...page.data };
  page.setData = function setData(patch) {
    Object.assign(this.data, patch);
  };

  function runNextTimer() {
    const first = timers.entries().next();
    assert.equal(first.done, false, 'expected a pending timer');
    const [id, timer] = first.value;
    timers.delete(id);
    timer.handler();
    return timer.ms;
  }

  function runAllTimers() {
    let remaining = 20;
    while (timers.size > 0 && remaining > 0) {
      runNextTimer();
      remaining -= 1;
    }
    assert.ok(remaining > 0, 'timer loop did not settle');
  }

  return {
    page,
    requests,
    recognitions,
    utterances,
    timers,
    navigateBackCalls() {
      return navigateBackCount;
    },
    resolveScriptures(list) {
      assert.equal(requests.length, 1, 'expected one scripture-list request');
      requests[0].success({ data: { scriptures: list } });
    },
    runNextTimer,
    runAllTimers
  };
}

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
  assert.equal(fixture.recognitions[0].startCalls, 1);
  assert.equal(fixture.page.data.listening, false);
  assert.notEqual(fixture.page.data.statusText, '正在听...');

  fixture.recognitions[0].onstart();
  assert.equal(fixture.page.data.listening, true);
  assert.equal(fixture.page.data.statusText, '正在听...');
});

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

test('unloading cancels a pending first listen', () => {
  const fixture = createFixture();
  fixture.page.onLoad();
  fixture.page.onShow();
  fixture.resolveScriptures(SCRIPTURES);

  fixture.page.onUnload();
  fixture.runAllTimers();

  assert.equal(fixture.recognitions.length, 0);
  assert.equal(fixture.page.data.listening, false);
});

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

test('one device backspace is intercepted and returns scripture detail to home', () => {
  const fixture = createFixture();
  let prevented = 0;
  const event = { code: 'Backspace', preventDefault() { prevented += 1; } };
  fixture.page.data.showingDetail = true;

  fixture.page.onKeyUp(event);

  assert.equal(prevented, 1);
  assert.equal(fixture.navigateBackCalls(), 1);
});

test('one device backspace is intercepted and returns the list to home', () => {
  const fixture = createFixture();
  let prevented = 0;
  const event = { code: 'Backspace', preventDefault() { prevented += 1; } };
  fixture.page.data.showingDetail = false;

  fixture.page.onKeyUp(event);

  assert.equal(prevented, 1);
  assert.equal(fixture.navigateBackCalls(), 1);
});

test('a repeated backspace during the same double-touch only navigates once', () => {
  const fixture = createFixture();
  const event = { code: 'Backspace', preventDefault() {} };
  fixture.page.data.showingDetail = false;

  fixture.page.onKeyUp(event);
  fixture.page.onKeyUp(event);

  assert.equal(fixture.navigateBackCalls(), 1);
});

test('one device backspace stops voice listening from both scripture views', () => {
  const makeRecognition = () => ({
    abortCalls: 0,
    abort() { this.abortCalls += 1; }
  });

  const detailFixture = createFixture();
  const detailRecognition = makeRecognition();
  detailFixture.page.data.showingDetail = true;
  detailFixture.page.data.listening = true;
  detailFixture.page.recognition = detailRecognition;
  detailFixture.page.handleBackspace();

  assert.equal(detailRecognition.abortCalls, 1);
  assert.equal(detailFixture.page.recognition, null);
  assert.equal(detailFixture.page.data.listening, false);

  const listFixture = createFixture();
  const listRecognition = makeRecognition();
  listFixture.page.data.showingDetail = false;
  listFixture.page.data.listening = true;
  listFixture.page.recognition = listRecognition;
  listFixture.page.handleBackspace();

  assert.equal(listRecognition.abortCalls, 1);
  assert.equal(listFixture.page.recognition, null);
  assert.equal(listFixture.page.data.listening, false);
});

test('only unselected scripture cards retain a visible border', () => {
  assert.match(scriptureSource, /ink:if="\{\{!showingDetail\}\}"/);
  assert.match(scriptureSource, /ink:if="\{\{showingDetail\}\}"/);
  assert.match(scriptureSource, /class="card-wrap \{\{index === selectedIdx \? 'card-wrap-selected' : ''\}\}"/);
  assert.match(scriptureSource, /<card data-id="\{\{item.id\}\}" bindtap="handleTap" class="scripture-card-shell">/);
  assert.match(scriptureSource, /\.scripture-card-shell \{[^}]*border-width: 0;[^}]*background-color: transparent;/s);
  assert.match(scriptureSource, /\.card-wrap \{[^}]*border: 1px solid rgba\(64,255,94,0\.5\);/s);
  assert.match(scriptureSource, /\.card-wrap-selected \{[^}]*background-color: rgba\(64,255,94,0\.2\);[^}]*border-color: transparent;/s);
  assert.equal(scriptureSource.includes('style="{{index === selectedIdx ?'), false);
});
