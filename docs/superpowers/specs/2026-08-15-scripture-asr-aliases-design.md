# 经书 ASR 简称映射设计

## 目标

用户在读经页说常用简称时，打开对应的完整经书：

| 语音简称 | 经书名称 | 经书 ID |
| --- | --- | --- |
| 华严经 | 大方广佛华严经（三品节选） | `huayan-selections` |
| 法华经 | 妙法莲华经 | `lotus-sutra` |
| 药师经 | 药师琉璃光如来本愿功德经 | `medicine-buddha-sutra` |
| 楞严经 | 大佛顶首楞严经 | `shurangama-sutra` |

“莲华经”不作为语音简称，不新增对应映射。

## 变更范围

- 在 `pages/scripture/scripture.ink` 的现有 `aliases` 中新增 `华严经 → huayan-selections`。
- 保留已有的 `法华经`、`药师经`、`楞严经` 映射。
- 不修改 ASR 生命周期、经书加载、触摸导航或其他简称。

## 验证

- 扩展读经页语音测试，分别输入“打开华严经”“打开法华经”“打开药师经”“打开楞严经”。
- 断言依次加载 `huayan-selections`、`lotus-sutra`、`medicine-buddha-sutra`、`shurangama-sutra`。
- 断言源码没有新增“莲华经”别名。
- 运行全部现有 Node 回归测试和 `git diff --check`。
