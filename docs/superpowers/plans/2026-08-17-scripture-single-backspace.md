# 经文页单 Backspace 返回 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让眼镜一次双击触摸所产生的单个 `Backspace` 事件，在经文详情页立即返回经文列表，并在列表页返回首页。

**Architecture:** 保留 `onKeyUp(event)` 对宿主默认返回的拦截，把 `handleBackspace()` 定义为处理设备已经识别完成的一次双击返回事件。移除应用层第二次 `Backspace` 计时判断，同时复用现有 `stopRecognition()` 和 `handleBack()`，避免改变语音生命周期与详情状态清理规则。

**Tech Stack:** AIUI `.ink` 页面、JavaScript、Node.js 内置 `node:test` / `assert` / `vm`

## Global Constraints

- 一次物理双击触摸只对应一个 `Backspace` `keyup` 事件。
- 详情视图返回列表，不调用 `wx.navigateBack()`；列表视图调用一次 `wx.navigateBack()` 返回首页。
- 两种视图都调用 `event.preventDefault()` 并在返回前停止语音识别。
- 不修改首页、冥想、木鱼、白噪音、经书语音别名或经文列表卡片外框行为。
- WXML 控制属性继续使用 `ink:` 前缀；本修复不引入新的 WXML 或 WXSS。

---

### Task 1: 按真机单事件语义修复经文返回

**Files:**
- Modify: `tests/scripture-voice-startup.test.cjs:224-291`
- Modify: `pages/scripture/scripture.ink:36,336-352,409-473`

**Interfaces:**
- Consumes: AIUI 在一次物理双击触摸后传给 `onKeyUp(event)` 的单个 `{ code: "Backspace", preventDefault() }` 事件；现有 `stopRecognition()`、`handleBack()` 和 `wx.navigateBack()`。
- Produces: `handleBackspace(): void`，每调用一次立即停止识别，并根据 `data.showingDetail` 返回列表或首页。

- [ ] **Step 1: 将返回测试改为只派发一个 Backspace 事件**

把详情和列表测试改为一次 `onKeyUp(event)`，删除旧的异步双事件计时测试，并把语音清理测试的每个视图改为一次 `handleBackspace()`：

```js
test('one device backspace is intercepted and returns detail only to the list', () => {
  const fixture = createFixture();
  let prevented = 0;
  const event = { code: 'Backspace', preventDefault() { prevented += 1; } };
  fixture.page.data.showingDetail = true;

  fixture.page.onKeyUp(event);

  assert.equal(prevented, 1);
  assert.equal(fixture.page.data.showingDetail, false);
  assert.equal(fixture.navigateBackCalls(), 0);
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
```

将语音清理测试改为每个视图只调用一次 `handleBackspace()`，并保留完整断言：

```js
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
```

- [ ] **Step 2: 运行专项测试并确认 RED**

Run: `node --test tests/scripture-voice-startup.test.cjs`

Expected: 新的详情单事件测试失败，`showingDetail` 仍为 `true`；新的列表单事件测试失败，`navigateBackCalls()` 仍为 `0`；语音清理测试失败，识别实例尚未中止。这证明测试能够复现真机问题。

- [ ] **Step 3: 写最小实现**

从页面实例字段中删除：

```js
_lastBackspaceTime: 0,
```

将 `handleBackspace()` 替换为立即处理单个设备返回事件：

```js
handleBackspace: function() {
  this.stopRecognition();
  if (this.data.showingDetail) {
    this.handleBack();
  } else {
    wx.navigateBack();
  }
},
```

保留 `onKeyUp(event)` 中现有逻辑：

```js
if (code === "Backspace") {
  event.preventDefault();
}
```

详情和列表分支仍各调用一次 `this.handleBackspace()`。

- [ ] **Step 4: 运行专项测试并确认 GREEN**

Run: `node --test tests/scripture-voice-startup.test.cjs`

Expected: 全部读经专项测试通过；单事件详情返回、列表返回、语音中止和卡片外框断言均为 PASS。

- [ ] **Step 5: 运行全量回归与静态检查**

先用 `rg --files tests` 确认当前测试文件，再执行每个 JavaScript / CommonJS 测试文件；至少运行：

```bash
node --test tests/*.test.cjs
node tests/checkin.test.js
git diff --check
```

Expected: 所有测试退出码为 `0`，`git diff --check` 无输出。若 shell 中不存在某类扩展名，改为使用 `rg --files tests -g '*.test.cjs'` 返回的明确文件列表执行，避免未匹配 glob 被原样传给 Node。

- [ ] **Step 6: 审查并提交实现**

确认差异只包含以下两个文件，不纳入首页和其他未提交工作：

```bash
git diff -- pages/scripture/scripture.ink tests/scripture-voice-startup.test.cjs
git status --short
git add pages/scripture/scripture.ink tests/scripture-voice-startup.test.cjs
git commit -m "fix: handle scripture double-touch as one event"
```

Expected: 提交仅包含经文返回实现和对应测试；`pages/index/index.ink`、`tests/checkin.test.js`、`tests/home-voice-hold-hint.test.cjs` 的现有工作保持原状。

- [ ] **Step 7: 真机验收**

在眼镜上依次验证：进入任一经文详情后双击触摸一次返回经文列表；返回后语音监听停止；在列表双击触摸一次返回首页。自动化测试不能代替这一步，因为它只能模拟已经确认的单事件语义，不能读取真机实际按键流。
