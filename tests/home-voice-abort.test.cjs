const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

const projectRoot = path.resolve(__dirname, '..');
const indexFile = path.join(projectRoot, 'pages/index/index.ink');
const indexSource = fs.readFileSync(indexFile, 'utf8');
const idlePrompt = '长按触摸后，说「读经文」「敲木鱼」「冥想」「聊佛法」进入';

function extractPageScript(source) {
  const match = source.match(/<script setup>([\s\S]*?)<\/script>/);
  assert.ok(match, 'expected a <script setup> block');
  return match[1]
    .replace(/import wx from ['"]wx['"];?/, '')
    .replace('export default {', 'globalThis.__page = {');
}

function createFixture() {
  const timers = new Map();
  let nextTimerId = 1;

  class FakeRecognition {
    constructor() {
      this.abortCalls = 0;
    }

    start() {}

    abort() {
      this.abortCalls += 1;
    }
  }

  class FakeUtterance {
    constructor(text) {
      this.text = text || '';
    }
  }

  const context = {
    Date,
    Math,
    SpeechRecognition: FakeRecognition,
    SpeechSynthesisUtterance: FakeUtterance,
    speechSynthesis: { speak() {} },
    wx: {
      getStorageSync() { return ''; },
      setStorageSync() {},
      navigateTo() {},
      speech: { playTTS() {} }
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

  vm.runInNewContext(extractPageScript(indexSource), context, { filename: indexFile });
  const page = context.__page;
  page.data = { ...page.data };
  page.setData = function setData(patch) {
    Object.assign(this.data, patch);
  };

  return { page, timers };
}

test('returning home ignores an aborted stale recognizer and restores the long-press prompt', () => {
  const fixture = createFixture();
  fixture.page.initRecognition();
  const staleRecognition = fixture.page.recognition;
  fixture.page.setData({ statusText: '进入读经文', listening: true });

  fixture.page.onShow();
  staleRecognition.onerror({ error: 'aborted' });
  staleRecognition.onend();

  assert.equal(staleRecognition.abortCalls, 1);
  assert.equal(fixture.page.recognition, null);
  assert.equal(fixture.page.data.listening, false);
  assert.equal(fixture.page.data.statusText, idlePrompt);
  assert.equal(fixture.timers.size, 0);
});
