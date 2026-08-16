'use strict';
// Decodes icon.b64 -> build/icon.png (resized to 256x256 if needed) -> build/icon.ico.
// Fallback: if the b64 file is unusable, generates a simple purple/blue "SL" icon.

const fs = require('fs');
const path = require('path');

// Resolved relative to this script (…/desktop/scripts) so the project can be moved.
const B64_SOURCE = path.join(__dirname, '..', '..', 'iOS App', 'web-build-source', 'icon.b64');
const BUILD_DIR = path.join(__dirname, '..', 'build');
const PNG_OUT = path.join(BUILD_DIR, 'icon.png');
const ICO_OUT = path.join(BUILD_DIR, 'icon.ico');

async function main() {
  fs.mkdirSync(BUILD_DIR, { recursive: true });

  const { Jimp } = require('jimp');
  let pngToIco = require('png-to-ico');
  if (typeof pngToIco !== 'function' && pngToIco && typeof pngToIco.default === 'function') {
    pngToIco = pngToIco.default;
  }

  let image = null;
  try {
    let b64 = fs.readFileSync(B64_SOURCE, 'utf8').trim();
    const m = b64.match(/^data:image\/[a-z+]+;base64,(.*)$/s);
    if (m) b64 = m[1];
    b64 = b64.replace(/\s+/g, '');
    const buf = Buffer.from(b64, 'base64');
    if (buf.length < 8 || buf.readUInt32BE(0) !== 0x89504e47) {
      throw new Error('decoded data is not a PNG');
    }
    image = await Jimp.read(buf);
    console.log('Decoded icon.b64: ' + image.width + 'x' + image.height + ' PNG');
  } catch (err) {
    console.warn('icon.b64 unusable (' + err.message + '), generating fallback SL icon');
    image = null;
  }

  if (image) {
    if (image.width !== 256 || image.height !== 256) {
      image.resize({ w: 256, h: 256 });
      console.log('Resized to 256x256');
    }
    await image.write(PNG_OUT);
  } else {
    // Fallback: 256x256 purple/blue gradient with "SL"
    const img = new Jimp({ width: 256, height: 256, color: 0x000000ff });
    for (let y = 0; y < 256; y++) {
      for (let x = 0; x < 256; x++) {
        const t = (x + y) / 510;
        const r = Math.round(80 + 60 * t);
        const g = Math.round(40 + 40 * t);
        const b = Math.round(180 + 60 * t);
        img.setPixelColor(Jimp.rgbaToInt(r, g, b, 255), x, y);
      }
    }
    await img.write(PNG_OUT);
  }

  const icoBuf = await pngToIco(PNG_OUT);
  fs.writeFileSync(ICO_OUT, icoBuf);
  console.log('Wrote ' + PNG_OUT + ' and ' + ICO_OUT + ' (' + icoBuf.length + ' bytes)');
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
