#!/usr/bin/env node
// x-shot Playwright engine: screenshot a public X tweet without login, reusing
// an already-present Playwright install + cached Chromium (nothing to install).
//
// Usage: node xshot-pw.cjs <tweet-url> <output.png>
// Env:   X_SHOT_PW_MODULE = absolute path to a resolvable `playwright` package.
//
// Exit codes:
//   0  success (path printed to stdout)
//   3  needs login / tweet gated / not visible  -> caller should fall back
//   1  hard error                               -> caller should fall back

const PW_MODULE = process.env.X_SHOT_PW_MODULE || "playwright";
let chromium;
try {
  ({ chromium } = require(PW_MODULE));
} catch (e) {
  console.error("[pw] cannot load playwright:", e.message);
  process.exit(1);
}

const [url, out] = process.argv.slice(2);
if (!url || !out) {
  console.error("usage: xshot-pw.cjs <tweet-url> <output.png>");
  process.exit(1);
}

const UA =
  "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " +
  "(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36";

async function launch() {
  // Prefer the system Chrome channel (always present, no version-matched download
  // needed). Fall back to Playwright's bundled Chromium if the channel is absent.
  try {
    return await chromium.launch({ headless: true, channel: "chrome" });
  } catch (e) {
    console.error("[pw] channel=chrome unavailable, trying bundled chromium:", e.message);
    return await chromium.launch({ headless: true });
  }
}

(async () => {
  const browser = await launch();
  try {
    const ctx = await browser.newContext({
      viewport: { width: 1280, height: 1000 },
      deviceScaleFactor: 2,
      locale: "zh-CN",
      userAgent: UA,
      extraHTTPHeaders: { "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8" },
    });
    const page = await ctx.newPage();
    await page.goto(url, { waitUntil: "domcontentloaded", timeout: 30000 });

    // Logged-out status pages render exactly one <article> (no data-testid).
    const card = page.locator("article").first();
    try {
      await card.waitFor({ state: "visible", timeout: 15000 });
    } catch {
      const finalUrl = page.url();
      console.error("[pw] tweet article not visible (login/gate?). url=" + finalUrl);
      process.exit(3); // let caller fall back to opencli
    }

    await card.scrollIntoViewIfNeeded();

    // Hide fixed/sticky overlays that horizontally overlap the tweet column
    // (bottom login banner + top "Post" bar) without disturbing side rails/layout.
    await page.evaluate(() => {
      const art = document.querySelector("article");
      const a = art.getBoundingClientRect();
      for (const el of document.querySelectorAll("body *")) {
        if (el === art || el.contains(art) || art.contains(el)) continue;
        const pos = getComputedStyle(el).position;
        if (pos !== "fixed" && pos !== "sticky") continue;
        const r = el.getBoundingClientRect();
        if (r.left < a.right && r.right > a.left) {
          el.style.setProperty("display", "none", "important");
        }
      }
    });

    await page.waitForTimeout(1200); // let media settle
    await card.screenshot({ path: out });
    console.log(out);
    process.exit(0);
  } catch (e) {
    console.error("[pw] error:", e.message);
    process.exit(1);
  } finally {
    await browser.close().catch(() => {});
  }
})();
