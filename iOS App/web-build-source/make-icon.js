/* Generates the app icon as a base64 PNG data URI (no deps beyond zlib). */
const zlib = require('zlib');

const CRC_TABLE = (() => {
  const t = new Int32Array(256);
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    t[n] = c;
  }
  return t;
})();

function crc32(buf) {
  let c = 0xffffffff;
  for (let i = 0; i < buf.length; i++) c = CRC_TABLE[(c ^ buf[i]) & 0xff] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
}

function chunk(type, data) {
  const len = Buffer.alloc(4);
  len.writeUInt32BE(data.length);
  const body = Buffer.concat([Buffer.from(type, 'ascii'), data]);
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(body));
  return Buffer.concat([len, body, crc]);
}

function encodePNG(w, h, rgba) {
  const raw = Buffer.alloc((w * 4 + 1) * h);
  for (let y = 0; y < h; y++) {
    raw[y * (w * 4 + 1)] = 0; // filter: none
    rgba.copy(raw, y * (w * 4 + 1) + 1, y * w * 4, (y + 1) * w * 4);
  }
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(w, 0);
  ihdr.writeUInt32BE(h, 4);
  ihdr[8] = 8;  // bit depth
  ihdr[9] = 6;  // colour type RGBA
  return Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk('IHDR', ihdr),
    chunk('IDAT', zlib.deflateSync(raw, { level: 9 })),
    chunk('IEND', Buffer.alloc(0)),
  ]);
}

/* ---- The mark: a cyan system-window diamond over a deep navy field ---- */
const S = 180;
const buf = Buffer.alloc(S * S * 4);
const CX = S / 2, CY = S / 2;

const clamp01 = v => (v < 0 ? 0 : v > 1 ? 1 : v);
// Coverage of a stroke of half-width hw centred on distance `d` from the edge,
// antialiased across one pixel.
const band = (d, hw) => clamp01(hw + 0.7 - Math.abs(d));
const fill = (d) => clamp01(0.7 - d);

function mix(dst, i, r, g, b, a) {
  dst[i]     = Math.round(dst[i]     * (1 - a) + r * a);
  dst[i + 1] = Math.round(dst[i + 1] * (1 - a) + g * a);
  dst[i + 2] = Math.round(dst[i + 2] * (1 - a) + b * a);
  dst[i + 3] = 255;
}

for (let y = 0; y < S; y++) {
  for (let x = 0; x < S; x++) {
    const i = (y * S + x) * 4;
    const dx = x - CX, dy = y - CY;
    const r = Math.hypot(dx, dy);

    // Background: deep navy, lifting toward blue at the top-left.
    const glow = clamp01(1 - Math.hypot(x - 46, y - 40) / 150);
    let R = 5 + 12 * glow * glow;
    let G = 6 + 22 * glow * glow;
    let B = 12 + 46 * glow * glow;
    // Vignette toward the corners.
    const vig = clamp01(1 - r / (S * 0.72));
    R *= 0.45 + 0.55 * vig; G *= 0.45 + 0.55 * vig; B *= 0.45 + 0.55 * vig;
    buf[i] = Math.round(R); buf[i + 1] = Math.round(G); buf[i + 2] = Math.round(B); buf[i + 3] = 255;

    // Ambient bloom behind the mark.
    mix(buf, i, 0, 140, 190, clamp01(1 - r / 70) * 0.16);

    const l1 = Math.abs(dx) + Math.abs(dy); // rotated-square (diamond) metric

    // Outer diamond ring.
    mix(buf, i, 0, 212, 255, band(l1 - 62, 2.1) * 0.95);
    // Inner hairline diamond.
    mix(buf, i, 0, 212, 255, band(l1 - 50, 0.7) * 0.5);
    // Solid core diamond.
    mix(buf, i, 120, 235, 255, fill(l1 - 20) * 0.92);
    mix(buf, i, 255, 255, 255, fill(l1 - 11) * 0.85);

    // Corner brackets, echoing the app's panel chrome.
    const m = 16, len = 34, t = 3.2;
    const nearL = x >= m && x <= m + len, nearR = x >= S - m - len && x <= S - m;
    const nearT = y >= m && y <= m + len, nearB = y >= S - m - len && y <= S - m;
    let br = 0;
    if (nearT && (Math.abs(x - m) < t || Math.abs(x - (S - m)) < t)) br = 1;
    if (nearB && (Math.abs(x - m) < t || Math.abs(x - (S - m)) < t)) br = 1;
    if (nearL && (Math.abs(y - m) < t || Math.abs(y - (S - m)) < t)) br = 1;
    if (nearR && (Math.abs(y - m) < t || Math.abs(y - (S - m)) < t)) br = 1;
    mix(buf, i, 0, 212, 255, br * 0.72);
  }
}

process.stdout.write(encodePNG(S, S, buf).toString('base64'));
