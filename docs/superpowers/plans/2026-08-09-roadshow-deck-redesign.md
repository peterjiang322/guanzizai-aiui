# 观自在开发者大赛路演 PPT 改版 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将现有 12 页商业计划风格路演稿改为一份面向开发者大赛评委、5 分钟可讲完、突出创意、UE 设计和未来可能性的 9 页新版 PPT。

**Architecture:** 以现有 `/Users/a1/观自在ai智能体/观自在-路演PPT.pptx` 作为唯一模板源，先完成全量模板盘点与 9 页 frame map，再由 `@oai/artifact-tool` 导入复制后的 starter deck，定点修改继承元素并导出新版副本。内容事实来自当前 AIUI 代码，市场背景采用 WHO、IDC 和中央网信办权威来源，最终通过逐页渲染、布局检查、溢出检查和模板保真检查完成验收。

**Tech Stack:** PowerPoint `.pptx`、`@oai/artifact-tool` JavaScript ES Modules、presentation template-following helpers、Node.js、LibreOffice/Poppler 渲染辅助工具。

## Global Constraints

- 受众是开发者大赛评委，路演时长 5 分钟。
- 最终页数为 9 页；删除商业模式、收入预测、融资式市场空间和夸大的竞争壁垒。
- 主线是“创意起点 → 产品体验 → UE 细节 → 技术落地 → 未来可能性”。
- 当前能力与未来能力必须明确区分，不把规划中的功能写成已实现。
- 产品全貌页必须覆盖读经文、敲木鱼、冥想、聊佛法，并为每个模块列出核心卖点。
- 视觉使用黑底 `#000000`、主绿色 `#40FF5E` 和透明度层级；字体沿用 `PingFang SC`。
- 原 PPT 是唯一视觉和结构来源；每一页都必须从源幻灯片复制，禁止重新创建空白页或叠加平行模板。
- 必须使用 `@oai/artifact-tool`，禁止使用 `python-pptx` 或直接修改 OOXML。
- 不伪造设备截图、产品截图、用户数据或性能数据。
- 市场数据的演讲者备注必须包含 `[Sources]` 区块。
- 原稿不得覆盖；最终文件固定为 `/Users/a1/观自在ai智能体/观自在-开发者大赛路演PPT-新版.pptx`。

---

## File Structure

- Modify via import/export: `/Users/a1/观自在ai智能体/观自在-路演PPT.pptx` → `/Users/a1/观自在ai智能体/观自在-开发者大赛路演PPT-新版.pptx`
- Create: `/private/tmp/guanzizai_ppt_review/template-audit.txt` — 模板结构、字体、页面类型、继承元素和改版合同。
- Create: `/private/tmp/guanzizai_ppt_review/template-frame-map.json` — 9 个输出页到源页的映射和可编辑元素范围。
- Create: `/private/tmp/guanzizai_ppt_review/deviation-log.txt` — 黑绿重着色、内容改写和结构微调的逐页理由。
- Create: `/private/tmp/guanzizai_ppt_review/source-notes.txt` — 权威来源、项目代码来源和无外部素材声明。
- Create: `/private/tmp/guanzizai_ppt_review/content.txt` — 9 页最终可见文案与备注文案。
- Create: `/private/tmp/guanzizai_ppt_review/slide-edits.json` — starter inspect id 到最终文本、样式和位置的完整编辑配置。
- Create: `/private/tmp/guanzizai_ppt_review/build-roadshow.mjs` — 导入 starter、修改继承元素、写备注、渲染和导出最终 PPTX。
- Create: `/private/tmp/guanzizai_ppt_review/qa-ledger.txt` — 逐页检查结果和修复记录。
- Modify: `docs/superpowers/plans/2026-08-09-roadshow-deck-redesign.md` — 勾选执行状态。

### Task 1: 完成模板审计和页面映射

**Files:**
- Read: `/private/tmp/guanzizai_ppt_review/template-inspect/template-manifest.json`
- Read: `/private/tmp/guanzizai_ppt_review/template-inspect/template-inspect.ndjson`
- Read: `/private/tmp/guanzizai_ppt_review/template-inspect/layouts/source-slide-*.layout.json`
- Create: `/private/tmp/guanzizai_ppt_review/template-audit.txt`
- Create: `/private/tmp/guanzizai_ppt_review/template-frame-map.json`
- Create: `/private/tmp/guanzizai_ppt_review/deviation-log.txt`

**Interfaces:**
- Consumes: 12 页源稿的 source slide 编号、`aid`、字体、位置和渲染 PNG。
- Produces: 可被 `prepare_template_starter_deck.mjs` 验证的完整 frame map。

- [x] **Step 1: 写入模板审计**

使用 `apply_patch` 写入：12 页、1280×720、`PingFang SC` 为中文主字体、源稿无图片/图表、内容均为可编辑文本框与形状；1/11/12 为深色极简页，2/5/8 为三列页，4 为四列页，6 为纵向架构页，7 为三层叙事页。记录原稿使用米白 `#FBF5EB`、深灰 `#2C2C2C`、金色 `#C4A04A`，新版允许统一改为黑绿，但不得删除未列入 editTargets 的继承元素。

- [x] **Step 2: 写入 9 页 source mapping**

`template-frame-map.json` 的页面映射固定为：

```json
{
  "outputSlides": [
    { "outputSlide": 1, "sourceSlide": 1, "narrativeRole": "opening thesis", "reuseMode": "duplicate-slide" },
    { "outputSlide": 2, "sourceSlide": 8, "narrativeRole": "market context", "reuseMode": "duplicate-slide" },
    { "outputSlide": 3, "sourceSlide": 3, "narrativeRole": "creative insight", "reuseMode": "duplicate-slide" },
    { "outputSlide": 4, "sourceSlide": 4, "narrativeRole": "product overview", "reuseMode": "duplicate-slide" },
    { "outputSlide": 5, "sourceSlide": 7, "narrativeRole": "UE principles", "reuseMode": "duplicate-slide" },
    { "outputSlide": 6, "sourceSlide": 3, "narrativeRole": "meditation hero experience", "reuseMode": "duplicate-slide" },
    { "outputSlide": 7, "sourceSlide": 5, "narrativeRole": "experience details", "reuseMode": "duplicate-slide" },
    { "outputSlide": 8, "sourceSlide": 6, "narrativeRole": "technical implementation", "reuseMode": "duplicate-slide" },
    { "outputSlide": 9, "sourceSlide": 11, "narrativeRole": "future and close", "reuseMode": "duplicate-slide" }
  ],
  "omittedSourceSlides": [
    { "sourceSlide": 2, "reason": "problem framing is replaced by sourced market context" },
    { "sourceSlide": 9, "reason": "commercial model is out of scope" },
    { "sourceSlide": 10, "reason": "roadmap is folded into the future slide" },
    { "sourceSlide": 12, "reason": "future slide also serves as closing and Q&A" }
  ]
}
```

为每个 `outputSlides` 条目追加 `editTargets`：从对应 source layout JSON 读取全部 `elements[].aid`，文本元素使用 `action: "rewrite"`，需要改变尺寸/位置的形状使用 `action: "rewrite-and-reposition"`，页码统一使用 `action: "rewrite"`。这样每一个被改色、改文案或重排的继承元素都有明确来源。

- [x] **Step 3: 验证 frame map**

Run:

```bash
node /Users/a1/.codex/plugins/cache/openai-primary-runtime/presentations/26.805.11740/skills/presentations/template_following_scripts/validate_template_plan.mjs --workspace /private/tmp/guanzizai_ppt_review --pptx /Users/a1/观自在ai智能体/观自在-路演PPT.pptx --map /private/tmp/guanzizai_ppt_review/template-frame-map.json
```

Expected: exit code `0`，无 `missing-edit-targets`、`unresolved-edit-target` 或 `unhandled-placeholder`。

### Task 2: 生成并验证 9 页 starter deck

**Files:**
- Consume: `/private/tmp/guanzizai_ppt_review/template-frame-map.json`
- Create: `/private/tmp/guanzizai_ppt_review/template-starter.pptx`
- Create: `/private/tmp/guanzizai_ppt_review/template-starter-preview/`
- Create: `/private/tmp/guanzizai_ppt_review/template-starter-layout/`
- Create: `/private/tmp/guanzizai_ppt_review/template-starter-contact-sheet.png`

**Interfaces:**
- Consumes: validated frame map。
- Produces: 保留源稿 master → layout → slide 结构的 9 页编辑基线。

- [x] **Step 1: 生成 starter deck**

Run:

```bash
node /Users/a1/.codex/plugins/cache/openai-primary-runtime/presentations/26.805.11740/skills/presentations/template_following_scripts/prepare_template_starter_deck.mjs --workspace /private/tmp/guanzizai_ppt_review --pptx /Users/a1/观自在ai智能体/观自在-路演PPT.pptx --map /private/tmp/guanzizai_ppt_review/template-frame-map.json --out /private/tmp/guanzizai_ppt_review/template-starter.pptx --preview-dir /private/tmp/guanzizai_ppt_review/template-starter-preview --layout-dir /private/tmp/guanzizai_ppt_review/template-starter-layout --contact-sheet /private/tmp/guanzizai_ppt_review/template-starter-contact-sheet.png
```

Expected: 9 个预览 PNG、9 个 layout JSON 和一张 contact sheet；映射顺序为 `1,8,3,4,7,3,5,6,11`。

- [x] **Step 2: 检查 starter deck**

逐页查看 PNG，确认重复使用的源第 3 页分别出现在输出第 3、6 页，源第 4 页完整保留四列结构，源第 11 页作为结尾页；不允许出现空白页或丢失形状。

### Task 3: 固化最终文案、来源和编辑脚本

**Files:**
- Create: `/private/tmp/guanzizai_ppt_review/content.txt`
- Create: `/private/tmp/guanzizai_ppt_review/slide-edits.json`
- Create: `/private/tmp/guanzizai_ppt_review/source-notes.txt`
- Create: `/private/tmp/guanzizai_ppt_review/build-roadshow.mjs`

**Interfaces:**
- Consumes: `template-starter.pptx`、设计说明和当前 AIUI 代码事实。
- Produces: 可重复执行的 PPTX 编辑与导出脚本。

- [x] **Step 1: 写入 9 页可见文案**

`content.txt` 必须包含以下标题与核心信息：

```text
1 观自在｜Rokid AR 眼镜上的 AI 修行伴侣｜观心 · 观息 · 观自在
2 三股趋势，正在把观自在推到正确的时间点｜全球超 10 亿人面临精神健康问题｜2025 全球智能眼镜 1477.3 万台、同比 +44.2%｜AI 与 AR 正成为传统文化的新表达媒介
3 屏幕让人分心，眼镜让练习回到当下｜手机：找 App—点菜单—盯倒计时｜观自在：轻唤—选择—沉浸｜让 AI 退到背景，让注意力回到呼吸
4 四种修行方式，一套统一体验｜读经文｜敲木鱼｜冥想｜聊佛法
5 每一步都为眼镜场景减负｜语音优先｜可控选择｜固定视野｜状态可感知
6 把声音、时间和呼吸合成一个节奏｜三种练习｜5/10/20 分钟｜随机禅境音频 15% 音量｜呼吸光晕同步明暗与大小
7 克制不是少做，而是只保留必要反馈｜看得清｜听得轻｜跑得稳
8 创意建立在 AIUI 原生能力之上｜感知｜交互｜AI｜内容与服务｜5 个已注册页面｜32 项冥想与音频自动化测试
9 从四个工具，走向长期陪伴｜个性化｜多模态｜文化共创｜跨设备｜让技术更安静、更懂得何时出现
```

产品全貌页每个模块写 3 条卖点，完全使用设计说明中的已确认文案；未来页所有能力使用“下一步”“可扩展”措辞。

- [x] **Step 2: 写入来源记录**

`source-notes.txt` 必须包含：WHO 2025 新闻稿、IDC 2026 对 2025 智能眼镜市场的总结、中央网信办 2024 传统文化数字叙事文章、项目代码路径 `aiui-agent/app.json` 和 `aiui-agent/pages/*/*.ink`。声明未使用外部图片、未生成伪截图。

- [x] **Step 3: 编写 artifact-tool 编辑模块**

先对 `template-starter.pptx` 运行 `presentation.inspect({ kind: "slide,textbox,shape,notes", include: "id,slide,name,bbox,text", maxChars: 40000 })`，将每一项允许修改的 starter id 写入 `slide-edits.json`。配置格式固定为：

```json
[
  {
    "id": "starter inspect 返回的 sh/ 锚点",
    "slide": 1,
    "text": "观自在",
    "style": { "typeface": "PingFang SC", "fontSize": 64, "bold": true, "color": "#40FF5E" }
  }
]
```

实际文件必须覆盖 9 页所有被改动的继承元素；`id` 只能复制自 starter inspect，`slide` 必须与锚点所属页面一致，`text` 使用 `content.txt` 中的最终文案。非文本形状也进入配置，并通过 `fill`、`line` 和 `position` 字段记录黑绿重着色或位置微调；不允许保留示例锚点。

`build-roadshow.mjs` 使用以下入口与辅助函数：

```js
import fs from "node:fs/promises";
import { FileBlob, PresentationFile } from "@oai/artifact-tool";

const STARTER = "/private/tmp/guanzizai_ppt_review/template-starter.pptx";
const FINAL = "/Users/a1/观自在ai智能体/观自在-开发者大赛路演PPT-新版.pptx";
const RENDER_DIR = "/private/tmp/guanzizai_ppt_review/final-render";
const LAYOUT_DIR = "/private/tmp/guanzizai_ppt_review/final-layout";
const GREEN = "#40FF5E";
const BLACK = "#000000";
const WHITE = "#F4FFF6";
const MUTED = "#8CCF98";

function setText(shape, value, style = {}) {
  shape.text = value;
  shape.text.style = { typeface: "PingFang SC", color: WHITE, ...style };
}

function recolorSlide(slide) {
  slide.background.fill = BLACK;
  for (const shape of slide.shapes.items) {
    if (shape.text && String(shape.text).trim()) {
      shape.text.style = { typeface: "PingFang SC", color: WHITE };
    }
    if (shape.fill && shape.fill !== "none") shape.fill = "#07120A";
    if (shape.line) shape.line = { style: "solid", fill: "#40FF5E", width: 1 };
  }
}

async function writeBlob(path, blob) {
  await fs.writeFile(path, new Uint8Array(await blob.arrayBuffer()));
}

async function main() {
  const presentation = await PresentationFile.importPptx(await FileBlob.load(STARTER));
  await fs.mkdir(RENDER_DIR, { recursive: true });
  await fs.mkdir(LAYOUT_DIR, { recursive: true });
  for (const slide of presentation.slides.items) recolorSlide(slide);
  const edits = JSON.parse(await fs.readFile("/private/tmp/guanzizai_ppt_review/slide-edits.json", "utf8"));
  for (const edit of edits) {
    const target = presentation.resolve(edit.id);
    if (Object.hasOwn(edit, "text")) setText(target, edit.text, edit.style || {});
    if (edit.position) target.position = edit.position;
    if (edit.fill) target.fill = edit.fill;
    if (edit.line) target.line = edit.line;
  }
  presentation.slides.items[1].speakerNotes.textFrame.setText([
    "[Sources]",
    "- WHO (2025-09-02): https://www.who.int/news/item/02-09-2025-over-a-billion-people-living-with-mental-health-conditions-services-require-urgent-scale-up",
    "- IDC (2026-03-26): https://www.idc.com/resource-center/blog/2025%E5%B9%B4%E4%B8%AD%E5%9B%BD%E6%99%BA%E8%83%BD%E7%9C%BC%E9%95%9C%E5%B8%82%E5%9C%BA%E5%90%8C%E6%AF%94%E5%A2%9E%E9%95%BF87-1%EF%BC%8C%E8%A1%8C%E4%B8%9A%E4%BB%8E%E7%A1%AC%E4%BB%B6%E9%93%BA%E9%99%88%E8%B5%B0%E5%90%91%E4%BB%B7%E5%80%BC%E9%AA%8C%E8%AF%81/",
    "- 中央网信办 (2024-12-06): https://www.cac.gov.cn/2024-12/06/c_1735179270304970.htm"
  ]);
  presentation.slides.items[1].speakerNotes.setVisible(true);
  for (const [index, slide] of presentation.slides.items.entries()) {
    await writeBlob(`${RENDER_DIR}/slide-${index + 1}.png`, await presentation.export({ slide, format: "png", scale: 2 }));
    await fs.writeFile(`${LAYOUT_DIR}/slide-${index + 1}.layout.json`, await (await slide.export({ format: "layout" })).text());
  }
  const montage = await presentation.export({ format: "webp", montage: true, scale: 1 });
  await writeBlob("/private/tmp/guanzizai_ppt_review/final-montage.webp", montage);
  const pptx = await PresentationFile.exportPptx(presentation);
  await pptx.save(FINAL);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
```

`slide-edits.json` 每页配置必须明确列出 starter inspect id、最终文本、字号、位置、填充和边框。不得用宽泛文本匹配批量清空页面。

- [x] **Step 4: 运行编辑脚本**

Run:

```bash
node /private/tmp/guanzizai_ppt_review/build-roadshow.mjs
```

Expected: 生成 9 页最终 PPTX、9 张 2× PNG、9 个 layout JSON 和一张 montage。

### Task 4: 逐页视觉和内容 QA

**Files:**
- Inspect: `/private/tmp/guanzizai_ppt_review/final-render/slide-1.png` … `slide-9.png`
- Inspect: `/private/tmp/guanzizai_ppt_review/final-layout/slide-1.layout.json` … `slide-9.layout.json`
- Create: `/private/tmp/guanzizai_ppt_review/qa-ledger.txt`
- Modify: `/private/tmp/guanzizai_ppt_review/build-roadshow.mjs`

**Interfaces:**
- Consumes: first-pass final PPTX renders and layouts。
- Produces: 无溢出、无意外重叠、信息层级清晰的最终版。

- [x] **Step 1: 逐页全尺寸检查**

每页分别检查：标题不换行、正文不裁切、黑绿对比可读、页码连续、四模块卖点完整、冥想体验没有固定圆环、未来能力使用规划语气。将结论按 `slide 1` 到 `slide 9` 写入 `qa-ledger.txt`。

- [x] **Step 2: 修复所有视觉问题**

对每个发现的问题修改 `build-roadshow.mjs` 中对应元素的位置、宽高或文案长度后重新执行。不得通过将正文缩小到 16pt 以下解决拥挤；优先缩短文字或使用源页面中的其他继承框位。

- [x] **Step 3: 检查内容事实**

核对：3 部经文、4 个功能模块、3 种冥想、5/10/20 分钟、6 个随机音轨、15% 音量、5 个注册页面、32 项测试；不得保留原稿中的“白噪音独立模块”“10 部经文”“AIUI 前端调试中”“商业模式”或“月收入”文案。

### Task 5: 运行机器检查和最终导出

**Files:**
- Verify: `/Users/a1/观自在ai智能体/观自在-开发者大赛路演PPT-新版.pptx`
- Verify: `/private/tmp/guanzizai_ppt_review/template-starter.pptx`
- Verify: `/private/tmp/guanzizai_ppt_review/template-frame-map.json`

**Interfaces:**
- Consumes: 视觉 QA 完成的最终 PPTX。
- Produces: 可交付的 9 页新版路演稿。

- [x] **Step 1: 运行溢出检测**

Run:

```bash
python3 /Users/a1/.codex/plugins/cache/openai-primary-runtime/presentations/26.805.11740/skills/presentations/container_tools/slides_test.py /Users/a1/观自在ai智能体/观自在-开发者大赛路演PPT-新版.pptx
```

Expected: 无超出 1280×720 画布的内容；所有警告逐项检查并记录。

- [x] **Step 2: 运行模板保真检查**

Run:

```bash
node /Users/a1/.codex/plugins/cache/openai-primary-runtime/presentations/26.805.11740/skills/presentations/template_following_scripts/check_template_fidelity.mjs --workspace /private/tmp/guanzizai_ppt_review --starter-pptx /private/tmp/guanzizai_ppt_review/template-starter.pptx --final-pptx /Users/a1/观自在ai智能体/观自在-开发者大赛路演PPT-新版.pptx --map /private/tmp/guanzizai_ppt_review/template-frame-map.json --starter-layout-dir /private/tmp/guanzizai_ppt_review/template-starter-layout --final-layout-dir /private/tmp/guanzizai_ppt_review/final-layout --edit-dir /private/tmp/guanzizai_ppt_review
```

Expected: 9 页映射完整，所有变更都落在允许的 inherited edit targets 中，无未处理占位符或遗失模板结构。

- [x] **Step 3: 最终渲染复核**

重新渲染全部 9 页并查看 montage，再随机打开第 2、4、6、8、9 页全尺寸 PNG。确认市场数据来源备注存在、模块卖点不裁切、冥想光晕和架构链路视觉清晰、结尾页可直接进入 Q&A。

- [x] **Step 4: 提交执行文档**

```bash
git add docs/superpowers/plans/2026-08-09-roadshow-deck-redesign.md
git commit -m "docs: plan developer contest roadshow update"
```

最终 PPTX 位于工作区根目录，不纳入 `aiui-agent` 子仓库；交付时只提供最终 PPTX，不附带临时脚本、预览和 QA 文件。
