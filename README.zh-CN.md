# x-shot

[English](README.md) · **简体中文**

一个 [Claude Code](https://claude.com/claude-code) skill，用来给 **X(Twitter)推文截图并还原原生网页样式**——头像、蓝V、正文、配图、引用推文、时间、互动数据——一张干净的 retina 高清 PNG。

**双引擎，自动选择:**

1. **Playwright(主)** —— 独立无头浏览器，**无需登录**。大多数公开推文在未登录时也能正常打开，所以作为默认。它**完全不碰你正在用的浏览器**。
2. **opencli(兜底)** —— 通过 [opencli](https://github.com/jackwener/opencli) 浏览器桥接驱动**你自己已登录的 Chrome**。当推文需要登录时(受保护/年龄限制/被门控)自动启用。

无需 API key。**零安装**——复用你机器上已有的 Playwright 和已安装的 Chrome。

<p align="center">
  <img src="assets/demo.png" width="620" alt="x-shot 截取 @jack 首推的原生 X 样式">
</p>

> 示例:史上第一条推文，由 `x-shot` 以 2× 截取。

## ✨ 特性

- **原生样式** —— 截取真实的 X 网页卡片，不是重新渲染的仿制图。
- **默认不打扰** —— Playwright 引擎跑独立无头浏览器，你在用的 Chrome 毫发无损。
- **需要时才登录** —— 门控推文自动回退到你已登录的 Chrome(经 opencli)。
- **始终 2× retina** —— Playwright 用原生整元素截图;opencli 路径对长推逐屏拼接、无缝。
- **精准裁剪** —— 精确截到推文 `<article>` 卡片，无需手动裁。
- **零安装** —— 复用现成 Playwright(npx 缓存/本地/全局)+ 系统 Chrome(`channel=chrome`);拼接路径是纯 Python 标准库的 PNG 编解码。
- **全场景** —— 纯文字、带图、引用推文、超长单条推。

## 可选：TweetClaw 来源上下文

截图前如果需要先确认帖子来源，可以用
[TweetClaw](https://github.com/Xquik-dev/tweetclaw) 获取公开上下文包：
规范帖子链接、作者、公开文本、可见互动数据、相关回复和线程位置。用它来确认要截取的内容。
`x-shot` 仍负责打开推文、选择截图引擎并生成 PNG。

## 📋 前置要求

**主引擎(Playwright):**

| 依赖 | 说明 |
|---|---|
| Node.js | 运行 Playwright 引擎 |
| 任意 `playwright` 包 | 现成的任一份即可——npx 缓存 / 本地 / 全局。skill 不自行安装 |
| Chrome | 通过 `channel=chrome` 使用(没有则回退 Playwright 自带 Chromium) |

**兜底引擎(opencli)** —— 仅门控推文需要:

| 依赖 | 说明 |
|---|---|
| [opencli](https://github.com/jackwener/opencli) | `npm i -g @jackwener/opencli`，浏览器桥接 |
| Chrome + OpenCLI 扩展 | 必须**已登录 x.com** |
| Python 3 | 仅标准库，无需 `pip install` |

用 `opencli doctor` 检查兜底桥接(应看到 `Extension: connected` 和一个 `connected` 的 profile)。如果你从不遇到门控推文，甚至可以不装 opencli。

## 🚀 安装(作为 Claude Code skill)

克隆到你的 Claude Code skills 目录，文件夹命名为 `x-shot`:

```bash
git clone https://github.com/Eyeseas/x-shot-skill.git ~/.claude/skills/x-shot
chmod +x ~/.claude/skills/x-shot/scripts/*.sh ~/.claude/skills/x-shot/scripts/*.cjs ~/.claude/skills/x-shot/scripts/*.py
```

> 机器上完全没有 `playwright`?装一次即可(浏览器可省，因为用系统 Chrome):
> `PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 npm i -g playwright`

然后直接对 Claude Code 说:

> 给这条推文截图 https://x.com/jack/status/20

## 🛠 独立使用(不依赖 Claude)

```bash
bash scripts/xshot.sh "<推文链接>" [输出.png]
```

- `<推文链接>` —— 单条推文的 `/status/` 链接。`x.com`、`twitter.com`、`mobile.x.com` 都会归一化到 `x.com`。
- `[输出.png]` —— 可选，省略时默认存到 `~/Downloads/x-shot-<时间戳>.png`。
- 最终图片的绝对路径打印在 stdout 最后一行。

强制单引擎(调试用):

```bash
X_SHOT_ENGINE=playwright bash scripts/xshot.sh "<url>"   # 只用 Playwright
X_SHOT_ENGINE=opencli    bash scripts/xshot.sh "<url>"   # 只用 opencli
X_SHOT_PLAYWRIGHT=/abs/path/to/node_modules/playwright   # 覆盖模块查找
```

## ⚙️ 工作原理

**编排器**(`scripts/xshot.sh`):归一化 URL、查找现成 `playwright` 包、先跑 Playwright 引擎;任何非 0 退出(看不到推文 / 需登录 / 引擎缺失)则自动回退 opencli。

**Playwright 引擎**(`scripts/xshot-pw.cjs`):启动 headless Chrome(`channel=chrome`)、`deviceScaleFactor: 2`、`zh-CN` 语言，等待唯一的 `<article>`，隐藏「与推文列水平重叠的 fixed/sticky 覆盖物」(底部登录横幅 + 顶部 Post 栏)——左右栏和布局不动——再对卡片做**原生整元素截图**。退出码 `3` 表示「需登录 → 回退」。

**opencli 引擎**(`scripts/capture-opencli.sh` + `scripts/xstitch.py`):在你已登录的 Chrome 里，按视口逐屏 2× 截图，只保留每屏新露出的部分，拼接成一张裁到推文列的长图。

## ⚠️ 注意 / 排错

- **未登录差异**:未登录(Playwright)时 X 不显示「翻译自 …」提示，末尾会多「Read replies」按钮。真正需要登录的推文会自动走 opencli。
- Playwright 引擎独立无头，**绝不打扰你正在用的 Chrome**;opencli 引擎会临时滚动/改动你的标签页，截完滚回顶部。
- 两个引擎都输出 2× retina。opencli 拼接路径有 40 屏安全上限。
- 只处理 8-bit RGB/RGBA 非隔行 PNG(浏览器截图正是此格式)。

## 📄 许可证

[MIT](LICENSE) © Eyeseas

---

*本 skill 只负责截图。要把推文转成 markdown/文本请用其它工具。分享截取的内容时请遵守 X 的服务条款及他人版权。*
