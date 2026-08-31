# 经文页双击返回事件修正设计

## 问题

经文详情页收到眼镜的双击触摸后无法返回经文列表。

当前实现把一次物理双击误建模为“两次 `Backspace` 事件”：第一次事件只记录时间，只有 500ms 内收到第二次事件才执行返回。真机实际上会把一次完整的双击触摸手势上报为一个 `Backspace` `keyup` 事件。页面同时调用了 `event.preventDefault()`，因此这唯一一次事件既不会触发宿主默认返回，也不会满足页面等待第二次事件的条件，最终没有任何返回动作。

## 目标行为

- 经文详情视图收到一个 `Backspace` 事件时，立即停止语音识别并切换回当前页面的经文列表，不调用 `wx.navigateBack()`。
- 经文列表视图收到一个 `Backspace` 事件时，立即停止语音识别并调用一次 `wx.navigateBack()` 返回首页。
- 两种视图都继续调用 `event.preventDefault()`，避免宿主默认返回与页面路由同时执行。
- 保留经文列表卡片外框、经书语音别名及其他现有行为。

## 实现设计

- 删除页面实例字段 `_lastBackspaceTime`，不再在应用层对双击进行第二次计时识别。
- 将 `handleBackspace()` 改为处理一个已经由设备识别完成的双击返回事件：
  - 先调用 `stopRecognition()`，清理当前识别实例和待启动定时器；
  - 若 `showingDetail` 为 `true`，调用 `handleBack()` 返回列表；
  - 否则调用 `wx.navigateBack()` 返回首页。
- `onKeyUp(event)` 中仍在 `Backspace` 分支调用 `event.preventDefault()`，随后只调用一次 `handleBackspace()`。

## 测试设计

- 详情视图只派发一次 `Backspace` `keyup`：断言默认行为被阻止一次、`showingDetail` 变为 `false`、没有调用 `wx.navigateBack()`。
- 列表视图只派发一次 `Backspace` `keyup`：断言默认行为被阻止一次、`wx.navigateBack()` 只调用一次。
- 分别从详情和列表触发一次返回：断言活动语音识别被中止、`listening` 变为 `false`。
- 删除依赖“两次事件间隔”的旧测试，因为该测试模拟的不是设备真实事件语义。
- 运行读经专项测试、全量 Node 回归测试和 `git diff --check`。

## 变更范围

- 修改 `pages/scripture/scripture.ink` 中的 `Backspace` 返回处理。
- 修改 `tests/scripture-voice-startup.test.cjs` 中的返回行为测试。
- 不修改首页、冥想、木鱼、白噪音或其他页面。

## 与既有设计的关系

本设计仅更正 `docs/superpowers/specs/2026-08-15-scripture-back-and-selection-design.md` 中将一次物理双击描述为“两次 `Backspace` 事件”的部分；详情返回列表、列表返回首页以及卡片外框规则保持不变。

## 真机验收

1. 从首页进入“读经文”，选择任一经书进入详情。
2. 在详情页双击触摸一次，应返回经文列表，不能返回首页。
3. 确认返回后不再显示“正在听”，也不会继续响应详情页语音识别。
4. 在经文列表再次双击触摸一次，应返回首页。
