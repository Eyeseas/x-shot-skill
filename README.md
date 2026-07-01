# x-shot

**English** · [简体中文](README.zh-CN.md)

A [Claude Code](https://claude.com/claude-code) skill that screenshots **X (Twitter) tweets in their native web style** — avatar, verified badge, body text, embedded media, quoted tweets, timestamp and engagement counts — all in one crisp, retina-quality PNG.

**Two engines, chosen automatically:**

1. **Playwright (primary)** — an isolated, headless browser with **no login**. Most public tweets open fine while logged out, so this is the default. It never touches the browser you're actively using.
2. **opencli (fallback)** — drives **your own logged-in Chrome** through the [opencli](https://github.com/jackwener/opencli) browser bridge. Used automatically when a tweet needs login (protected / age-restricted / gated).

No API keys. Nothing to install — it reuses whatever Playwright is already on your machine plus your installed Chrome.

<p align="center">
  <img src="assets/demo.png" width="620" alt="x-shot capturing @jack's first tweet in native X style">
</p>

> Demo: the first tweet ever, captured at 2× via `x-shot`.

## ✨ Features

- **Native look** — captures the actual X web card, not a re-rendered mockup.
- **Non-intrusive by default** — the Playwright engine runs an isolated headless browser; your live Chrome is untouched.
- **Login when needed** — automatically falls back to your logged-in Chrome (via opencli) for gated tweets.
- **Always 2× retina** — Playwright takes a native full-element shot; the opencli path tiles long tweets and stitches them seamlessly.
- **Precise crop** — captures exactly the tweet `<article>` card, no manual cropping.
- **Zero install** — reuses an existing Playwright (npx cache / local / global) + system Chrome (`channel=chrome`); the stitch path is a pure Python-standard-library PNG codec.
- **Handles everything** — text-only, image tweets, quote tweets, and very long single tweets.

## 📋 Requirements

**Primary (Playwright) engine:**

| Dependency | Notes |
|---|---|
| Node.js | to run the Playwright engine |
| a `playwright` package | any existing copy — npx cache, local, or global. The skill installs nothing. |
| Chrome | used via `channel=chrome` (falls back to Playwright's bundled Chromium if present) |

**Fallback (opencli) engine** — only needed for login-gated tweets:

| Dependency | Notes |
|---|---|
| [opencli](https://github.com/jackwener/opencli) | `npm i -g @jackwener/opencli` — the browser bridge |
| Chrome + OpenCLI extension | must be **logged in to x.com** |
| Python 3 | standard library only — nothing to `pip install` |

Check the fallback bridge with `opencli doctor` (expect `Extension: connected` + a `connected` profile). If you never hit gated tweets, you may not need opencli at all.

## 🚀 Install (as a Claude Code skill)

Clone into your Claude Code skills directory as a folder named `x-shot`:

```bash
git clone https://github.com/Eyeseas/x-shot-skill.git ~/.claude/skills/x-shot
chmod +x ~/.claude/skills/x-shot/scripts/*.sh ~/.claude/skills/x-shot/scripts/*.cjs ~/.claude/skills/x-shot/scripts/*.py
```

> No `playwright` anywhere on your machine? Install once (browsers optional since it uses system Chrome):
> `PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 npm i -g playwright`

Then just tell Claude Code:

> 给这条推文截图 https://x.com/jack/status/20

## 🛠 Standalone usage (no Claude)

```bash
bash scripts/xshot.sh "<tweet-url>" [output.png]
```

- `<tweet-url>` — a single-tweet `/status/` link. `x.com`, `twitter.com`, `mobile.x.com` are all normalized to `x.com`.
- `[output.png]` — optional. Defaults to `~/Downloads/x-shot-<timestamp>.png`.
- The final absolute path is printed on the last line of stdout.

Force a single engine (handy for debugging):

```bash
X_SHOT_ENGINE=playwright bash scripts/xshot.sh "<url>"   # Playwright only
X_SHOT_ENGINE=opencli    bash scripts/xshot.sh "<url>"   # opencli only
X_SHOT_PLAYWRIGHT=/abs/path/to/node_modules/playwright   # override module lookup
```

## ⚙️ How it works

**Orchestrator** (`scripts/xshot.sh`): normalizes the URL, resolves an existing `playwright` package, runs the Playwright engine, and on any non-zero exit (tweet not visible / login needed / engine missing) falls back to opencli.

**Playwright engine** (`scripts/xshot-pw.cjs`): launches headless Chrome (`channel=chrome`) with `deviceScaleFactor: 2` and `zh-CN` locale, waits for the single `<article>`, hides `fixed/sticky` overlays that horizontally overlap the tweet column (bottom login banner + top "Post" bar) — leaving the side rails and layout intact — then takes a **native full-element screenshot** of the card. Exit code `3` signals "needs login → fall back".

**opencli engine** (`scripts/capture-opencli.sh` + `scripts/xstitch.py`): in your logged-in Chrome, tiles the viewport top-to-bottom at 2×, keeps only each newly revealed slice, and stitches the tiles into one tall PNG cropped to the tweet column.

## ⚠️ Notes & troubleshooting

- **Logged-out differences**: while logged out (Playwright), X omits the "Translated from …" prompt and adds a "Read replies" button at the bottom. Tweets that truly require login route to opencli automatically.
- The Playwright engine is isolated and headless — **your active Chrome is never disturbed**. The opencli engine temporarily scrolls/mutates your tab and scrolls back to the top when done.
- Both engines output 2× retina. The opencli tiling path has a 40-tile safety cap.
- Only 8-bit RGB/RGBA non-interlaced PNGs are handled (exactly what browsers produce).

## 📄 License

[MIT](LICENSE) © Eyeseas

---

*This skill only screenshots tweets. To convert a tweet to markdown/text, use a different tool. Respect X's Terms of Service and other people's copyright when sharing captured content.*
