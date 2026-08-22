const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const sharp = require('sharp');

const root = path.resolve(__dirname, '..', '..');
const production = path.join(
  root,
  'docs',
  'codex',
  '2026-07-15-synapse-medical-learning-os',
  'assets',
  'identity',
  'production',
  'wordmark',
);
const sourceDir = path.join(production, 'source');
const outDir = path.join(production, 'renders');
const frostSource = path.join(sourceDir, 'synapse-wordmark-frost.svg');
const oneColorSource = path.join(sourceDir, 'synapse-wordmark-one-color.svg');
const sourceDate = '2026-07-17';
const install = process.argv.includes('--install');
const appAssetDir = path.join(root, 'apps', 'app', 'assets', 'identity', 'wordmark');

function sha256(input) {
  return crypto.createHash('sha256').update(input).digest('hex').toUpperCase();
}

function themedSvg(file, color) {
  const source = fs.readFileSync(file, 'utf8');
  return Buffer.from(source.replace('<svg ', `<svg style="color:${color}" `));
}

async function metrics(buffer) {
  const { data, info } = await sharp(buffer).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
  let minX = info.width;
  let minY = info.height;
  let maxX = -1;
  let maxY = -1;
  let borderPixels = 0;
  for (let y = 0; y < info.height; y += 1) {
    for (let x = 0; x < info.width; x += 1) {
      const alpha = data[(y * info.width + x) * info.channels + 3];
      if (alpha <= 8) continue;
      minX = Math.min(minX, x);
      minY = Math.min(minY, y);
      maxX = Math.max(maxX, x);
      maxY = Math.max(maxY, y);
      if (x === 0 || y === 0 || x === info.width - 1 || y === info.height - 1) borderPixels += 1;
    }
  }
  return {
    width: info.width,
    height: info.height,
    alphaBounds: maxX < 0 ? null : [minX, minY, maxX, maxY],
    borderPixels,
  };
}

async function render(svg, height) {
  return sharp(svg, { density: 384 })
    .resize({ height, fit: 'contain', kernel: sharp.kernel.lanczos3 })
    .png({ compressionLevel: 9, adaptiveFiltering: true })
    .toBuffer();
}

async function main() {
  for (const file of [frostSource, oneColorSource]) {
    if (!fs.existsSync(file)) throw new Error(`Missing wordmark source: ${file}`);
  }
  fs.rmSync(outDir, { recursive: true, force: true });
  fs.mkdirSync(outDir, { recursive: true });
  const variants = [
    ['frost', fs.readFileSync(frostSource)],
    ['one-color-frost', themedSvg(oneColorSource, '#F7FAFF')],
    ['one-color-ink', themedSvg(oneColorSource, '#07182D')],
  ];
  const heights = [240, 96, 48, 24];
  const outputs = [];
  const buffers = new Map();
  for (const [name, svg] of variants) {
    for (const height of heights) {
      const buffer = await render(svg, height);
      const file = path.join(outDir, `synapse-wordmark-${name}-${height}h.png`);
      fs.writeFileSync(file, buffer);
      const measured = await metrics(buffer);
      if (measured.borderPixels !== 0) throw new Error(`${path.basename(file)} clips at canvas border`);
      outputs.push({
        variant: name,
        height,
        file: path.relative(root, file).replaceAll('\\', '/'),
        bytes: buffer.length,
        sha256: sha256(buffer),
        ...measured,
      });
      buffers.set(`${name}-${height}`, buffer);
    }
  }

  const midnight = { r: 7, g: 24, b: 45, alpha: 1 };
  const paper = { r: 249, g: 240, b: 218, alpha: 1 };
  const proofWidth = 1500;
  const proofHeight = 620;
  const material = buffers.get('frost-240');
  const white = buffers.get('one-color-frost-96');
  const ink = buffers.get('one-color-ink-96');
  const materialMeta = await sharp(material).metadata();
  const whiteMeta = await sharp(white).metadata();
  const inkMeta = await sharp(ink).metadata();
  const paperPlate = await sharp({ create: { width: 1360, height: 150, channels: 4, background: paper } })
    .composite([{ input: ink, left: Math.round((1360 - inkMeta.width) / 2), top: Math.round((150 - inkMeta.height) / 2) }])
    .png()
    .toBuffer();
  const proof = await sharp({ create: { width: proofWidth, height: proofHeight, channels: 4, background: midnight } })
    .composite([
      { input: material, left: Math.round((proofWidth - materialMeta.width) / 2), top: 36 },
      { input: white, left: Math.round((proofWidth - whiteMeta.width) / 2), top: 330 },
      { input: paperPlate, left: 70, top: 440 },
    ])
    .png({ compressionLevel: 9, adaptiveFiltering: true })
    .toBuffer();
  const proofFile = path.join(outDir, 'synapse-wordmark-proof-board.png');
  fs.writeFileSync(proofFile, proof);
  outputs.push({
    variant: 'proof-board',
    file: path.relative(root, proofFile).replaceAll('\\', '/'),
    bytes: proof.length,
    sha256: sha256(proof),
    width: proofWidth,
    height: proofHeight,
  });

  if (install) {
    fs.mkdirSync(appAssetDir, { recursive: true });
    const runtime = [
      ['wordmark_frost_240.png', 'frost-240'],
      ['wordmark_frost_96.png', 'frost-96'],
      ['wordmark_one_color_frost_96.png', 'one-color-frost-96'],
      ['wordmark_one_color_frost_48.png', 'one-color-frost-48'],
      ['wordmark_one_color_frost_24.png', 'one-color-frost-24'],
      ['wordmark_one_color_ink_96.png', 'one-color-ink-96'],
      ['wordmark_one_color_ink_48.png', 'one-color-ink-48'],
      ['wordmark_one_color_ink_24.png', 'one-color-ink-24'],
    ];
    for (const [name, key] of runtime) {
      const buffer = buffers.get(key);
      const file = path.join(appAssetDir, name);
      fs.writeFileSync(file, buffer);
      const measured = await metrics(buffer);
      outputs.push({
        variant: 'flutter-install',
        role: key,
        file: path.relative(root, file).replaceAll('\\', '/'),
        bytes: buffer.length,
        sha256: sha256(buffer),
        ...measured,
      });
    }
  }

  const manifest = {
    sourceDate,
    installedIntoFlutterProject: install,
    renderer: `sharp ${sharp.versions.sharp}; librsvg ${sharp.versions.svg || 'bundled'}`,
    sources: [frostSource, oneColorSource].map((file) => ({
      file: path.relative(root, file).replaceAll('\\', '/'),
      sha256: sha256(fs.readFileSync(file)),
    })),
    outputs,
  };
  const manifestFile = path.join(outDir, 'render-manifest.json');
  fs.writeFileSync(manifestFile, `${JSON.stringify(manifest, null, 2)}\n`);
  process.stdout.write(`${JSON.stringify({ manifest: path.relative(root, manifestFile), outputs: outputs.length, install }, null, 2)}\n`);
}

main().catch((error) => {
  process.stderr.write(`${error.stack || error}\n`);
  process.exitCode = 1;
});
