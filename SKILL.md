---
name: x-shot
description: >
  给 X(Twitter)推文截图,还原原生网页样式(头像/蓝V/正文/配图/引用/时间/互动数据)。
  当用户说「给这条推文截图」「截个图」「x-shot」「screenshot this tweet」「把这条推做成图」,
  或提供 x.com / twitter.com 的 /status/ 推文链接并想要图片时使用。
  双引擎:优先 Playwright(无登录、独立无头浏览器,大多数公开推文可用,不打扰你的浏览器);
  需要登录的推文(受保护/年龄限制/被门控)自动 fallback 到 opencli(复用你登录态的 Chrome)。
  仅负责截图;不发帖、不转 markdown(转文字用 baoyu-danger-x-to-markdown)。
metadata:
  engines:
    - playwright (primary; logged-out, isolated headless Chrome)
    - opencli (fallback; logged-in Chrome via browser bridge)
  requires:
    - node + 任意已存在的 playwright 包(npx 缓存/本地/全局均可,skill 不自行安装)
    - Chrome(供 Playwright channel=chrome 使用)
    - opencli + OpenCLI 扩展 + 已登录 X(仅 fallback 时需要)
    - python3(仅 opencli 拼接路径用,标准库,零第三方依赖)
    - bash
  platforms: [macOS, Linux]
---

# x-shot — X 推文原生截图(Playwright 优先 / opencli 兜底)

一条命令搞定,自动选引擎:

```bash
bash ~/.claude/skills/x-shot/scripts/xshot.sh "<推文链接>" [输出路径.png]
```

- 参数1:推文链接(`x.com`/`twitter.com`/`mobile.x.com` 的 `/status/` 单条推文页,自动归一化到 x.com)。
- 参数2(可选):输出 PNG 路径。省略默认存到 `~/Downloads/x-shot-<时间戳>.png`。
- 最终图片绝对路径打印在 stdout 最后一行。截完用 Read 查看确认,再把路径给用户。

## 双引擎与选择逻辑

| 引擎 | 何时用 | 特点 |
|---|---|---|
| **Playwright**(主) | 默认先试。大多数**公开**推文无需登录即可打开 | 独立无头 Chrome,**不碰你在用的浏览器**;原生元素截图,一次成图 |
| **opencli**(兜底) | Playwright 看不到推文时(登录墙/受保护/年龄限制) | 复用你**已登录**的 Chrome;逐屏 2x 拼接 |

`xshot.sh` 是编排器:先跑 Playwright,退出码非 0(找不到推文/需登录/引擎不可用)就自动回退 opencli。

用环境变量可强制单引擎(调试用):

```bash
X_SHOT_ENGINE=playwright bash .../xshot.sh "<url>"   # 只用 Playwright
X_SHOT_ENGINE=opencli    bash .../xshot.sh "<url>"   # 只用 opencli
```

## 零安装:复用现成 Playwright

skill **不自行安装**任何东西。`xshot.sh` 按顺序查找已存在的 playwright 包:
`$X_SHOT_PLAYWRIGHT` → skill 本地 `node_modules` → `~/.npm/_npx/*/`(npx 缓存)→ 全局 npm root。
浏览器优先用 **`channel=chrome`(系统 Chrome)**,无需版本匹配、无需下载 Chromium;
没有系统 Chrome 时再回退到 Playwright 自带 Chromium。

若机器上确实没有任何 playwright 包 → 直接走 opencli 兜底。

## 前置检查

- Playwright 路径:有 node + 任意 playwright 包 + 系统 Chrome 即可(本机已满足)。
- opencli 兜底路径:`opencli doctor` 应显示 `Extension: connected` 且有 profile `connected`,且 Chrome 已登录 X。

## 各脚本职责

- `scripts/xshot.sh` —— 编排器:归一化 URL、定输出、选引擎、PW→opencli 回退。
- `scripts/xshot-pw.cjs` —— Playwright 引擎:headless Chrome、zh-CN、DSF=2、隐藏与推文列水平重叠的 fixed/sticky 覆盖物(底部登录横幅 + 顶部 Post 栏)、`article` 元素原生截图。退出码 3 = 需回退。
- `scripts/capture-opencli.sh` —— opencli 引擎:登录态 Chrome 逐屏 2x + `xstitch.py` 拼接。
- `scripts/xstitch.py` —— 纯标准库 PNG 裁剪+竖向拼接(仅 opencli 路径用)。

## 注意 / 排错

- **登录态差异**:未登录(Playwright)时 X 不显示「翻译自 英语」提示,末尾会多「Read replies」按钮;需要这些元素或推文本身需登录时,走 opencli(会自动)。
- Playwright 引擎独立无头,**不影响你正在用的 Chrome**;opencli 引擎会临时操作你的标签页(滚动/去 sticky),截完滚回顶部。
- 两个引擎都输出 2x retina。opencli 路径安全上限 40 屏。
- 只处理 8-bit RGB/RGBA 非隔行 PNG(浏览器截图正是此格式)。
