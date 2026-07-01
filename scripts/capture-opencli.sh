#!/usr/bin/env bash
# x-shot opencli engine (fallback): capture a tweet through the user's logged-in
# Chrome via the opencli browser bridge. Tiles the viewport at 2x and stitches.
# Used when the Playwright (logged-out) engine can't see the tweet — e.g. it is
# protected, age-restricted, or otherwise requires login.
#
# Usage: capture-opencli.sh <tweet-url> <output-abs.png>
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SESSION="xshot"
URL="${1:?url required}"
OUT="${2:?output path required}"

SEL='article[data-testid="tweet"]'
TILEDIR="$(mktemp -d -t xshot)"
cleanup() { rm -rf "$TILEDIR"; }
trap cleanup EXIT

echo "[x-shot/opencli] opening $URL" >&2
opencli browser "$SESSION" open "$URL" >/dev/null 2>&1

echo "[x-shot/opencli] waiting for tweet to render..." >&2
if ! opencli browser "$SESSION" wait selector "$SEL" --timeout 20000 >/dev/null 2>&1; then
  echo "[x-shot/opencli] ERROR: tweet card did not appear. Is Chrome logged in to X? Is the URL a single-tweet /status/ link?" >&2
  exit 1
fi
opencli browser "$SESSION" wait time 1.5 >/dev/null 2>&1 || true

# neutralize sticky/fixed chrome so nothing occludes scrolled tiles
opencli browser "$SESSION" eval '(function(){var n=document.querySelectorAll("*");for(var i=0;i<n.length;i++){var p=getComputedStyle(n[i]).position;if(p==="fixed"||p==="sticky"){n[i].style.setProperty("position","static","important");}}return "ok";})()' >/dev/null 2>&1

# measure the tweet card (CSS pixels, at scroll top)
JS='(function(){window.scrollTo(0,0);var el=document.querySelector("article[data-testid=\"tweet\"]");var r=el.getBoundingClientRect();return JSON.stringify({left:r.left,top:r.top+window.scrollY,width:r.width,height:r.height,iw:window.innerWidth,ih:window.innerHeight});})()'
RECT="$(opencli browser "$SESSION" eval "$JS" 2>/dev/null | grep -m1 -oE '\{.*\}')"
if [ -z "$RECT" ]; then
  echo "[x-shot/opencli] ERROR: could not measure the tweet card." >&2
  exit 1
fi
read -r L DOCTOP W H IW IH < <(python3 -c "
import json
d=json.loads('''$RECT''')
print(d['left'],d['top'],d['width'],d['height'],d['iw'],d['ih'])
")

echo "[x-shot/opencli] capturing at 2x (card ${W%.*}x${H%.*} css)..." >&2

# tile top-to-bottom in document space, 2x each
SPECS=()
covered="$DOCTOP"
target="$DOCTOP"
docbottom="$(python3 -c "print($DOCTOP+$H)")"
i=0
while :; do
  actualY="$(opencli browser "$SESSION" eval "(function(){window.scrollTo(0,$target);return String(window.scrollY);})()" 2>/dev/null | grep -m1 -oE '[0-9]+([.][0-9]+)?' | head -1)"
  [ -z "$actualY" ] && actualY="$target"
  opencli browser "$SESSION" wait time 0.4 >/dev/null 2>&1 || true
  tile="$TILEDIR/tile_$i.png"
  opencli browser "$SESSION" screenshot "$tile" >/dev/null 2>&1
  if [ ! -s "$tile" ]; then
    echo "[x-shot/opencli] ERROR: screenshot failed on tile $i." >&2
    exit 1
  fi
  read -r NEWTOP NEWBOT DONE NEXT < <(python3 -c "
a=$actualY; ih=$IH; cov=$covered; db=$docbottom
top=max($DOCTOP, cov, a)
bot=min(db, a+ih)
done=1 if bot>=db-0.5 else 0
nxt=a+ih
print(top,bot,done,nxt)
")
  HAS_SLICE="$(python3 -c "print(1 if $NEWBOT-$NEWTOP>0.5 else 0)")"
  if [ "$HAS_SLICE" = "1" ]; then
    read -r TILETOP SLICEH < <(python3 -c "print($NEWTOP-$actualY, $NEWBOT-$NEWTOP)")
    SPECS+=("$tile|$L|$TILETOP|$W|$SLICEH")
    covered="$NEWBOT"
  fi
  [ "$DONE" = "1" ] && break
  ADV="$(python3 -c "print(1 if $NEXT>$target+0.5 else 0)")"
  [ "$ADV" = "0" ] && break
  target="$NEXT"
  i=$((i+1))
  [ "$i" -gt 40 ] && break
done

if [ "${#SPECS[@]}" -eq 0 ]; then
  echo "[x-shot/opencli] ERROR: nothing to stitch." >&2
  exit 1
fi

python3 "$DIR/xstitch.py" "$OUT" "$IW" "${SPECS[@]}" >/dev/null
opencli browser "$SESSION" eval "(function(){window.scrollTo(0,0);return 'ok';})()" >/dev/null 2>&1 || true

echo "[x-shot/opencli] saved: $OUT" >&2
echo "$OUT"
