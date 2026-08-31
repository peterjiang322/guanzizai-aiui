const assert = require('assert');
const fs = require('fs');
const path = require('path');

const root = path.join(__dirname, '..');

function readPage(relativePath) {
  return fs.readFileSync(path.join(root, relativePath), 'utf8');
}

function extractMethod(source, methodName) {
  const marker = `${methodName}: function(event) {`;
  const markerStart = source.indexOf(marker);
  assert.notStrictEqual(markerStart, -1, `${methodName} must exist`);

  const bodyStart = source.indexOf('{', markerStart);
  let depth = 0;
  let quote = null;
  let escaped = false;

  for (let i = bodyStart; i < source.length; i += 1) {
    const character = source[i];
    if (quote) {
      if (escaped) {
        escaped = false;
      } else if (character === '\\') {
        escaped = true;
      } else if (character === quote) {
        quote = null;
      }
      continue;
    }
    if (character === '"' || character === "'" || character === '`') {
      quote = character;
    } else if (character === '{') {
      depth += 1;
    } else if (character === '}') {
      depth -= 1;
      if (depth === 0) {
        return source.slice(bodyStart + 1, i);
      }
    }
  }

  throw new Error(`Could not extract ${methodName}`);
}

function loadHandler(relativePath, ...dependencies) {
  const body = extractMethod(readPage(relativePath), 'onKeyUp');
  const method = new Function('event', 'TYPE_OPTIONS', 'PRESET_DURATIONS', body);
  return function handler(event) {
    return method.call(this, event, ...dependencies);
  };
}

function invoke(handler, page, code) {
  handler.call(page, { code });
}

function makePage(data, methods = {}) {
  return {
    data,
    setData(update) {
      Object.assign(this.data, update);
    },
    ...methods
  };
}

function assertListDirection(relativePath, dataKey) {
  const handler = loadHandler(relativePath);
  const page = makePage({ selectedIdx: 0, [dataKey]: [{}, {}, {}] });

  invoke(handler, page, 'ArrowUp');
  assert.strictEqual(page.data.selectedIdx, 1, `${relativePath}: ArrowUp should select next`);

  page._lastNavTs = 0;
  invoke(handler, page, 'ArrowDown');
  assert.strictEqual(page.data.selectedIdx, 0, `${relativePath}: ArrowDown should select previous`);

  page._lastNavTs = 0;
  invoke(handler, page, 'ArrowLeft');
  assert.strictEqual(page.data.selectedIdx, 1, `${relativePath}: ArrowLeft should select next`);

  page._lastNavTs = 0;
  invoke(handler, page, 'ArrowRight');
  assert.strictEqual(page.data.selectedIdx, 0, `${relativePath}: ArrowRight should select previous`);
}

assertListDirection('pages/index/index.ink', 'menus');
assertListDirection('pages/chat/chat.ink', 'suggestions');

{
  const handler = loadHandler('pages/index/index.ink');
  const page = makePage({ selectedIdx: 0, menus: [{}, {}, {}] });
  let prevented = 0;

  handler.call(page, {
    code: 'Backspace',
    preventDefault() { prevented += 1; }
  });

  assert.strictEqual(prevented, 0, 'index: Backspace should not be intercepted so double-touch can exit');
}

{
  const handler = loadHandler('pages/soundscape/soundscape.ink');
  const page = makePage({ page: 'list', selectedIdx: 0, scenes: [{}, {}, {}] });

  invoke(handler, page, 'ArrowUp');
  assert.strictEqual(page.data.selectedIdx, 1, 'soundscape: ArrowUp should select next');

  invoke(handler, page, 'ArrowDown');
  assert.strictEqual(page.data.selectedIdx, 0, 'soundscape: ArrowDown should select previous');

  invoke(handler, page, 'ArrowLeft');
  assert.strictEqual(page.data.selectedIdx, 1, 'soundscape: ArrowLeft should select next');

  invoke(handler, page, 'ArrowRight');
  assert.strictEqual(page.data.selectedIdx, 0, 'soundscape: ArrowRight should select previous');
}

{
  const typeOptions = [{}, {}, {}];
  const presetDurations = [1, 5, 10];
  const handler = loadHandler('pages/meditation/meditation.ink', typeOptions, presetDurations);
  const page = makePage({ step: 'type', typeIdx: 0, durationIdx: 0 }, {
    confirmType() {},
    confirmDuration() {},
    setDuration(value) {
      this.data.durationMinutes = value;
      this.data.durationIdx = presetDurations.indexOf(value);
    }
  });

  invoke(handler, page, 'ArrowUp');
  assert.strictEqual(page.data.typeIdx, 1, 'meditation type: ArrowUp should select next');
  invoke(handler, page, 'ArrowDown');
  assert.strictEqual(page.data.typeIdx, 0, 'meditation type: ArrowDown should select previous');

  page.data.step = 'duration';
  invoke(handler, page, 'ArrowUp');
  assert.strictEqual(page.data.durationIdx, 1, 'meditation duration: ArrowUp should select next');
  invoke(handler, page, 'ArrowDown');
  assert.strictEqual(page.data.durationIdx, 0, 'meditation duration: ArrowDown should select previous');
}

{
  const handler = loadHandler('pages/scripture/scripture.ink');
  const page = makePage({ showingDetail: false, selectedIdx: 0, scriptures: [{}, {}, {}] }, {
    _lastNavTs: 0,
    handleNext() {},
    handlePrev() {}
  });

  invoke(handler, page, 'ArrowUp');
  assert.strictEqual(page.data.selectedIdx, 1, 'scripture list: ArrowUp should select next');
  page._lastNavTs = 0;
  invoke(handler, page, 'ArrowDown');
  assert.strictEqual(page.data.selectedIdx, 0, 'scripture list: ArrowDown should select previous');

  page._lastNavTs = 0;
  invoke(handler, page, 'ArrowLeft');
  assert.strictEqual(page.data.selectedIdx, 1, 'scripture list: ArrowLeft should select next');

  page._lastNavTs = 0;
  invoke(handler, page, 'ArrowRight');
  assert.strictEqual(page.data.selectedIdx, 0, 'scripture list: ArrowRight should select previous');

  page.data = {
    showingDetail: true,
    verseScrollTop: 200
  };
  page._verseTop = 200;
  page._verseH = 1000;
  page._verseClient = 400;
  page._lastNavTs = 0;
  invoke(handler, page, 'ArrowUp');
  assert.strictEqual(page.data.verseScrollTop, 320, 'scripture detail: ArrowUp should scroll down');

  page._lastNavTs = 0;
  invoke(handler, page, 'ArrowDown');
  assert.strictEqual(page.data.verseScrollTop, 200, 'scripture detail: ArrowDown should scroll up');
}

console.log('touch direction tests passed');
