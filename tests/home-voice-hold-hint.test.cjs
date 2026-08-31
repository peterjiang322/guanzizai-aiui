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
  assert.equal(indexSource.split(prompt).length - 1, 3);
});
