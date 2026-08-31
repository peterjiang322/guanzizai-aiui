const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.join(__dirname, '..');

function read(relativePath) {
  return fs.readFileSync(path.join(root, relativePath), 'utf8');
}

function ruleBody(source, selector) {
  const match = source.match(new RegExp(`${selector}\\s*\\{([^}]*)\\}`));
  assert.ok(match, `${selector} must exist`);
  return match[1];
}

function assertCardShell(source, wrapperSelector, selectedClass, shellClass, file, selectedIndex = 'selectedIdx') {
  const expectedBinding = `class="${wrapperSelector} {{index === ${selectedIndex} ? '${selectedClass}' : ''}}"`;
  assert.ok(source.includes(expectedBinding), `${file} must bind selection on an outer card wrapper`);
  assert.match(source, new RegExp(`class="${shellClass}"`), `${file} must use a transparent card shell`);
  const shell = ruleBody(source, `\\.${shellClass}`);
  assert.match(shell, /width:\s*100%;/, `${file} card shell must fill its wrapper`);
  assert.match(shell, /border-width:\s*0;/, `${file} card shell border must be transparent`);
  assert.match(shell, /background-color:\s*transparent;/, `${file} card shell background must be transparent`);
}

const scriptureSource = read('pages/scripture/scripture.ink');
const scriptureSelected = ruleBody(scriptureSource, '\\.card-wrap-selected');
const expectedDeclarations = [
  'background-color: rgba(64,255,94,0.2);',
  'border-color: transparent;'
];

for (const declaration of expectedDeclarations) {
  assert.match(scriptureSelected, new RegExp(declaration.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')));
}

{
  const grid = ruleBody(scriptureSource, '\\.scripture-grid');
  const wrapper = ruleBody(scriptureSource, '\\.card-wrap');
  const shell = ruleBody(scriptureSource, '\\.scripture-card-shell');
  const content = ruleBody(scriptureSource, '\\.card');
  const name = ruleBody(scriptureSource, '\\.card-name');

  assert.match(grid, /width:\s*405px;/, 'scripture grid must stay inside the 407px content area');
  assert.match(grid, /grid-template-columns:\s*131px\s+131px\s+131px;/, 'scripture grid must use three equal fixed columns');
  assert.match(grid, /gap:\s*6px;/, 'scripture grid must keep two 6px gaps');
  assert.ok(131 * 3 + 6 * 2 <= 407, 'three scripture cards and their gaps must fit the content area');

  for (const [label, body] of [
    ['wrapper', wrapper],
    ['native card shell', shell],
    ['card content', content]
  ]) {
    assert.match(body, /box-sizing:\s*border-box;/, `scripture ${label} must preserve its assigned width`);
  }
  assert.match(wrapper, /width:\s*131px;/, 'every scripture wrapper must have the same fixed width');
  assert.match(shell, /width:\s*100%;/, 'native scripture card must fill the fixed wrapper');
  assert.match(content, /width:\s*100%;/, 'scripture card content must fill the native card');
  assert.match(name, /width:\s*100%;/, 'long scripture names must wrap inside the fixed card width');
  assert.doesNotMatch(scriptureSelected, /(?:width|padding|margin|border-width)\s*:/, 'selection must not change card dimensions');
}

for (const [file, selector] of [
  ['pages/index/index.ink', '\\.menu-item-wrap-selected'],
  ['pages/meditation/meditation.ink', '\\.type-card-wrap-selected']
]) {
  const selectedRule = ruleBody(read(file), selector);
  for (const declaration of expectedDeclarations) {
    assert.match(selectedRule, new RegExp(declaration.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')), `${file} must match scripture selected style`);
  }
}

assertCardShell(read('pages/index/index.ink'), 'menu-item-wrap', 'menu-item-wrap-selected', 'menu-card-shell', 'pages/index/index.ink');
assertCardShell(scriptureSource, 'card-wrap', 'card-wrap-selected', 'scripture-card-shell', 'pages/scripture/scripture.ink');
assertCardShell(read('pages/meditation/meditation.ink'), 'type-card-wrap', 'type-card-wrap-selected', 'type-card-shell', 'pages/meditation/meditation.ink', 'typeIdx');

const meditationSource = read('pages/meditation/meditation.ink');
assert.equal(meditationSource.includes('class="type-check"'), false, 'meditation cards must not render a checkmark');
assert.match(
  meditationSource,
  /<text class="type-name">\{\{ item\.name \}\}<\/text>\s*<text class="type-desc">\{\{ item\.desc \}\}<\/text>/,
  'meditation name and description must be adjacent in the card row'
);
assert.match(ruleBody(meditationSource, '\\.type-name'), /font-size:\s*18px;/);
assert.match(ruleBody(meditationSource, '\\.type-desc'), /font-size:\s*12px;/);

console.log('selection style tests passed');
