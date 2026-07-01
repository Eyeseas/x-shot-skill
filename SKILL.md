---
name: x-shot
description: >
  给 X(Twitter)推文截图,还原原生网页样式(头像/蓝V/翻译提示/正文/配图/时间/互动数据)。
  当用户说「给这条推文截图」「截个图」「x-shot」「screenshot this tweet」「把这条推做成图」,
  或提供 x.com / twitter.com 的 /status/ 推文链接并想要图片时使用。
  通过 opencli 浏览器桥接复用用户【已登录的 Chrome】,所以能拿到只有登录态才有的原生元素。
  仅负责截图;不发帖、不转 markdown(转文字用 baoyu-danger-x-to-markdown)。
metadata:
  requires:
    - opencli (browser bridge, https://github.com/jackwener/opencli)
    - Chrome + OpenCLI 扩展,且已登录 X
    - python3 (标准库即可,零第三方依赖)
    - bash
  platforms: [macOS, Linux]
---

# x-shot — X 推文原生截图

用用户自己**已登录的 Chrome**(经 opencli 浏览器桥接)打开推文,精准截取推文
`<article>` 卡片,输出干净的原生样式 PNG。

## 前置检查

动手前先确认桥接在线:

```bash
opencli doctor
```

需要看到 `Extension: connected` 且至少一个 profile `connected`。若未连接,提示用户:
打开 Chrome、确认装了 OpenCLI 扩展、并已登录 x.com,然后重试。

## 用法

```bash
bash ~/.claude/skills/x-shot/scripts/xshot.sh "<推文链接>" [输出路径.png]
```

- 第一个参数:推文链接(`x.com` / `twitter.com` / `mobile.x.com` 的 `/status/` 单条推文页;
  域名会自动归一化到 x.com)。
- 第二个参数(可选):输出 PNG 路径。省略时默认存到 `~/Downloads/x-shot-<时间戳>.png`。
- 脚本会把最终图片的绝对路径打印到 stdout 最后一行。

示例:

```bash
bash ~/.claude/skills/x-shot/scripts/xshot.sh "https://x.com/jack/status/20" ~/Desktop/tweet.png
```

截完后用 Read 工具查看生成的 PNG 确认效果,再把路径告诉用户。

## 工作原理

1. `opencli browser xshot open <url>` —— 在登录态标签页打开推文。
2. `wait selector 'article[data-testid="tweet"]'` —— 等推文卡片渲染。
3. `eval` 把所有 `position:fixed/sticky` 的元素改成 `static` —— **中和 X 的悬浮顶栏**,
   否则滚动截图时它会遮住内容。
4. `eval`(IIFE 隔离作用域)量出卡片的**文档坐标**(`top+scrollY`)+ `innerWidth/innerHeight`。
5. **2x 逐屏拼接**:始终用默认截图(2x retina),按视口高度从上到下滚动分段截图,
   每段按文档坐标只取「新出现的部分」,自动去重底部越界的重叠。宽度全程不变,避免响应式重排。
6. `scripts/xstitch.py`(纯 Python 标准库,**零依赖**)从各段截图的实际像素宽反推缩放比,
   裁出推文列并竖向拼接成一张完整高清 PNG。

## 注意 / 排错

- **必须是登录态**:未登录会拿不到「订阅/翻译提示/阅读量」等元素,甚至看不到推文。报
  "tweet card did not appear" 多半是没登录或链接不是单条推文页。
- **始终 2x 高清**:无论推文多长都是 retina 清晰度(短推 1 段、长推自动多段拼接,无可见拼缝)。
- 截图前会临时改动页面(去 sticky + 滚动),截完会滚回顶部;live 标签页样式属临时状态,刷新即恢复。
- 每次复用同一个 `xshot` 会话标签页,不会堆积标签、也保持登录。
- 只处理 8-bit RGB/RGBA 非隔行 PNG(浏览器截图正是此格式)。安全上限 40 段。
