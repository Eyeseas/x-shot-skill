#!/usr/bin/env bash
# x-shot: screenshot an X (Twitter) tweet in native web style.
#
#   Primary engine : Playwright (logged-out, isolated headless Chromium) — works
#                    for most public tweets, never touches your live browser.
#   Fallback engine: opencli browser bridge (your logged-in Chrome) — used when
#                    the tweet needs login (protected / age-restricted / gated).
#
# Reuses whatever Playwright is already on the machine (npx cache, local, or
# global) plus the already-downloaded Chromium — it installs nothing.
#
# Usage: xshot.sh <tweet-url> [output.png]
# Env:   X_SHOT_ENGINE = auto (default) | playwright | opencli
#        X_SHOT_PLAYWRIGHT = absolute path to a `playwright` package dir (override)
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

URL="${1:-}"
if [ -z "$URL" ]; then
  echo "usage: xshot.sh <tweet-url> [output.png]" >&2
  exit 2
fi
OUT="${2:-}"
ENGINE="${X_SHOT_ENGINE:-auto}"

# --- normalize URL ---------------------------------------------------------
URL="${URL//twitter.com/x.com}"
URL="${URL//mobile.x.com/x.com}"
URL="${URL//nitter.net/x.com}"

# --- default output path ---------------------------------------------------
if [ -z "$OUT" ]; then
  ts="$(date +%Y%m%d-%H%M%S)"
  mkdir -p "$HOME/Downloads"
  OUT="$HOME/Downloads/x-shot-$ts.png"
fi
case "$OUT" in
  /*) ;;
  *) OUT="$PWD/$OUT" ;;
esac

# --- locate an existing Playwright package (install nothing) ---------------
resolve_playwright() {
  local c
  for c in \
    "${X_SHOT_PLAYWRIGHT:-}" \
    "$DIR/../node_modules/playwright" \
    "$DIR/node_modules/playwright"; do
    [ -n "$c" ] && [ -f "$c/package.json" ] && { echo "$c"; return 0; }
  done
  # newest npx cache copy
  c="$(ls -dt "$HOME"/.npm/_npx/*/node_modules/playwright 2>/dev/null | head -1)"
  [ -n "$c" ] && [ -f "$c/package.json" ] && { echo "$c"; return 0; }
  # global npm root
  local groot; groot="$(npm root -g 2>/dev/null)"
  [ -n "$groot" ] && [ -f "$groot/playwright/package.json" ] && { echo "$groot/playwright"; return 0; }
  return 1
}

run_playwright() {
  local pw; pw="$(resolve_playwright)" || return 3   # 3 => unavailable, fall back
  echo "[x-shot] engine: playwright (reusing $pw)" >&2
  X_SHOT_PW_MODULE="$pw" node "$DIR/xshot-pw.cjs" "$URL" "$OUT"
}

run_opencli() {
  bash "$DIR/capture-opencli.sh" "$URL" "$OUT"
}

case "$ENGINE" in
  opencli)
    run_opencli
    ;;
  playwright)
    run_playwright
    ;;
  auto|*)
    if run_playwright; then
      :
    else
      code=$?
      echo "[x-shot] playwright engine unavailable/failed (code $code) — falling back to opencli" >&2
      run_opencli
    fi
    ;;
esac
