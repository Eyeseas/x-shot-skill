#!/usr/bin/env python3
"""Crop same-width vertical slices from several 8-bit RGB/RGBA PNGs and stitch
them into one tall PNG. Pure standard library (zlib + struct).

Usage:
  xstitch.py out.png innerWidth "path|cssLeft|cssTop|cssW|cssH" [more specs...]

Each spec is one screenshot tile; coordinates are CSS pixels. The per-tile scale
is derived from that image's actual pixel width / innerWidth, so tiles captured
at any device-pixel-ratio line up. All slices must share the same cssW.
"""
import sys, zlib, struct

def read_png(path):
    with open(path, "rb") as f:
        data = f.read()
    assert data[:8] == b"\x89PNG\r\n\x1a\n", "not a PNG"
    pos = 8
    width = height = bitd = colort = None
    idat = bytearray()
    while pos < len(data):
        (length,) = struct.unpack(">I", data[pos:pos+4])
        ctype = data[pos+4:pos+8]
        body = data[pos+8:pos+8+length]
        if ctype == b"IHDR":
            width, height, bitd, colort, comp, filt, inter = struct.unpack(">IIBBBBB", body)
            assert bitd == 8, f"only 8-bit supported (got {bitd})"
            assert inter == 0, "interlaced not supported"
            assert colort in (2, 6), f"only RGB/RGBA supported (got {colort})"
        elif ctype == b"IDAT":
            idat += body
        elif ctype == b"IEND":
            break
        pos += 12 + length
    raw = zlib.decompress(bytes(idat))
    channels = 4 if colort == 6 else 3
    return width, height, channels, colort, raw

def paeth(a, b, c):
    p = a + b - c
    pa, pb, pc = abs(p-a), abs(p-b), abs(p-c)
    if pa <= pb and pa <= pc: return a
    if pb <= pc: return b
    return c

def unfilter(raw, width, height, channels):
    stride = width * channels
    out = bytearray(stride * height)
    prev = bytearray(stride)
    pos = 0
    for y in range(height):
        ft = raw[pos]; pos += 1
        line = bytearray(raw[pos:pos+stride]); pos += stride
        if ft == 1:
            for i in range(channels, stride):
                line[i] = (line[i] + line[i-channels]) & 0xff
        elif ft == 2:
            for i in range(stride):
                line[i] = (line[i] + prev[i]) & 0xff
        elif ft == 3:
            for i in range(stride):
                a = line[i-channels] if i >= channels else 0
                line[i] = (line[i] + ((a + prev[i]) >> 1)) & 0xff
        elif ft == 4:
            for i in range(stride):
                a = line[i-channels] if i >= channels else 0
                c = prev[i-channels] if i >= channels else 0
                line[i] = (line[i] + paeth(a, prev[i], c)) & 0xff
        elif ft != 0:
            raise ValueError(f"bad filter {ft}")
        out[y*stride:(y+1)*stride] = line
        prev = line
    return out, stride

def region(pixels, stride, channels, left, top, w, h):
    out = bytearray(w * channels * h)
    rb = w * channels
    for y in range(h):
        src = (top + y) * stride + left * channels
        out[y*rb:(y+1)*rb] = pixels[src:src+rb]
    return out

def write_png(path, width, height, channels, colort, pixels):
    stride = width * channels
    raw = bytearray()
    for y in range(height):
        raw.append(0)
        raw += pixels[y*stride:(y+1)*stride]
    comp = zlib.compress(bytes(raw), 9)
    def chunk(ct, body):
        return struct.pack(">I", len(body)) + ct + body + struct.pack(">I", zlib.crc32(ct + body) & 0xffffffff)
    ihdr = struct.pack(">IIBBBBB", width, height, 8, colort, 0, 0, 0)
    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n")
        f.write(chunk(b"IHDR", ihdr))
        f.write(chunk(b"IDAT", comp))
        f.write(chunk(b"IEND", b""))

def main():
    out = sys.argv[1]
    iw = float(sys.argv[2])
    specs = sys.argv[3:]
    assert specs, "no tiles given"
    channels = colort = None
    target_w = None
    slices = []  # (bytes, h)
    for sp in specs:
        path, cl, ct, cw, ch = sp.split("|")
        cl, ct, cw, ch = float(cl), float(ct), float(cw), float(ch)
        W, H, chn, colt, raw = read_png(path)
        px, stride = unfilter(raw, W, H, chn)
        scale = W / iw
        left = round(cl * scale); top = round(ct * scale)
        w = round(cw * scale); h = round(ch * scale)
        left = max(0, min(left, W-1)); top = max(0, min(top, H-1))
        w = max(1, min(w, W-left)); h = max(1, min(h, H-top))
        if channels is None:
            channels, colort, target_w = chn, colt, w
        w = min(target_w, W - left)  # keep constant width across tiles
        slices.append((region(px, stride, chn, left, top, w, h), h))
    total_h = sum(h for _, h in slices)
    rb = target_w * channels
    final = bytearray(rb * total_h)
    y0 = 0
    for buf, h in slices:
        final[y0*rb:(y0+h)*rb] = buf
        y0 += h
    write_png(out, target_w, total_h, channels, colort, final)
    print(f"stitched {target_w}x{total_h} from {len(slices)} tiles -> {out}")

if __name__ == "__main__":
    main()
