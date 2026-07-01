# x-shot

[English](README.md) · **简体中文**

一个 [Claude Code](https://claude.com/claude-code) skill，用来给 **X(Twitter)推文截图并还原原生网页样式**——头像、蓝V、翻译提示、正文、配图、引用推文、时间、互动数据——一张干净的 retina 高清 PNG 全搞定。

它通过 [opencli](https://github.com/jackwener/opencli) 浏览器桥接，驱动**你自己已登录的 Chrome**，所以截图里能包含只有登录后才出现的元素(订阅按钮、阅读量、翻译提示等)。无需 API key、无需无头登录、无需导出 cookie。

<p align="center">
  <img src="assets/demo.png" width="620" alt="x-shot 截取 @jack 首推的原生 X 样式">
</p>

> 示例:史上第一条推文，由 `x-shot` 以 2× 截取。

## ✨ 特性

- **原生样式** —— 截取的是真实的 X 网页卡片，不是重新渲染的仿制图。
- **登录态** —— 复用你真实的 Chrome 会话，订阅/阅读量/翻译等 UI 都在。
- **始终 2× retina** —— 短推一次截完;长推自动从上到下分屏截图并无缝拼接。
- **精准裁剪** —— 量出推文 `<article>` 卡片，精确裁到卡片边界，无需手动裁。
- **零第三方依赖** —— 裁剪与拼接由纯 Python 标准库实现的 PNG 编解码完成。
- **全场景** —— 纯文字、带图、引用推文、以及超长的「单条长推」都能处理。

## 📋 前置要求

| 依赖 | 说明 |
|---|---|
| [opencli](https://github.com/jackwener/opencli) | `npm i -g @jackwener/opencli`，提供浏览器桥接 |
| Chrome + OpenCLI 扩展 | 必须**已登录 x.com** |
| Python 3 | 仅用标准库，无需 `pip install` |
| bash | macOS 与 Linux |

使用前先确认桥接在线:

```bash
opencli doctor
```

应看到 `Extension: connected`，且至少一个 profile `connected`。

## 🚀 安装(作为 Claude Code skill)

克隆到你的 Claude Code skills 目录，文件夹命名为 `x-shot`:

```bash
git clone https://github.com/Eyeseas/x-shot-skill.git ~/.claude/skills/x-shot
chmod +x ~/.claude/skills/x-shot/scripts/*.sh ~/.claude/skills/x-shot/scripts/*.py
```

然后直接对 Claude Code 说:

> 给这条推文截图 https://x.com/jack/status/20

## 🛠 独立使用(不依赖 Claude)

```bash
bash scripts/xshot.sh "<推文链接>" [输出.png]
```

- `<推文链接>` —— 单条推文的 `/status/` 链接。`x.com`、`twitter.com`、`mobile.x.com` 都会归一化到 `x.com`。
- `[输出.png]` —— 可选，省略时默认存到 `~/Downloads/x-shot-<时间戳>.png`。
- 最终图片的绝对路径会打印在 stdout 最后一行。

示例:

```bash
bash scripts/xshot.sh "https://x.com/jack/status/20" ~/Desktop/tweet.png
```

## ⚙️ 工作原理

1. `opencli browser open <url>` 在你的登录态标签页打开推文。
2. 等待 `article[data-testid="tweet"]` 渲染。
3. 把所有 `position: fixed/sticky` 元素改成 `static`，这样 X 的悬浮顶栏就不会在滚动分屏时遮挡内容。
4. 用隔离作用域的 `eval` 量出推文卡片的**文档坐标**，以及 `innerWidth/innerHeight`。
5. **2× 分屏拼接**:按视口高度逐屏滚动截图，每屏只保留推文「新露出的部分」(自动去重底部越界的重叠)。宽度全程不变，所以不会触发 X 的响应式重排。
6. `scripts/xstitch.py` 从每屏截图的实际像素宽 ÷ `innerWidth` 反推缩放比，裁出推文列并竖向拼接成一张完整长图。

## ⚠️ 注意 / 排错

- **必须登录**。未登录会拿不到订阅/阅读量/翻译等元素，甚至看不到推文。报 `tweet card did not appear` 通常是没登录，或链接不是单条推文页。
- 截图过程中页面会被临时改动(去 sticky + 滚动)，截完会滚回顶部。live 标签页的样式是临时状态，刷新即恢复。
- 复用同一个 `xshot` 会话标签页，不堆积标签，也保持登录。
- 只处理 8-bit RGB/RGBA 非隔行 PNG(浏览器截图正是此格式)。安全上限 40 屏。

## 📄 许可证

[MIT](LICENSE) © Eyeseas

---

*本 skill 只负责截图。要把推文转成 markdown/文本请用其它工具。分享截取的内容时请遵守 X 的服务条款及他人版权。*
