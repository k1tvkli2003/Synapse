const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const sharp = require('sharp');

const root = path.resolve(__dirname, '..', '..');
const sourceDir = path.join(
  root,
  'docs',
  'codex',
  '2026-07-15-synapse-medical-learning-os',
  'assets',
  'identity',
  'production',
  'mascot-icon',
  'source',
);
const outDir = path.join(path.dirname(sourceDir), 'renders');

const sizesBySource = {
  'luma-foldkin-master.svg': [1024, 256, 96, 48, 32, 24, 16],
  'luma-foldkin-flat.svg': [1024, 256, 96, 48, 32, 24, 16],
  'luma-foldkin-mark-monochrome.svg': [1024, 256, 96, 48, 32, 24, 16],
  'luma-foldkin-app-icon.svg': [1024, 512, 256, 192, 96, 48, 32, 24, 16],
  'luma-foldkin-optical-24.svg': [24],
  'luma-foldkin-optical-16.svg': [16],
  'luma-foldkin-app-icon-optical-24.svg': [24],
  'luma-foldkin-app-icon-optical-16.svg': [16],
};

function sha256(file) {
  return crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex').toUpperCase();
}

async function alphaMetrics(file) {
  const { data, info } = await sharp(file).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
  let minX = info.width;
  let minY = info.height;
  let maxX = -1;
  let maxY = -1;
  let opaqueish = 0;
  let borderPixels = 0;
  const pixelCount = info.width * info.height;
  for (let y = 0; y < info.height; y += 1) {
    for (let x = 0; x < info.width; x += 1) {
      const alpha = data[(y * info.width + x) * info.channels + 3];
      if (alpha <= 8) continue;
      opaqueish += 1;
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
      if (x === 0 || y === 0 || x === info.width - 1 || y === info.height - 1) borderPixels += 1;
    }
  }
  return {
    width: info.width,
    height: info.height,
    alphaBounds: maxX < 0 ? null : { minX, minY, maxX, maxY, width: maxX - minX + 1, height: maxY - minY + 1 },
    alphaCoverage: Number((opaqueish / pixelCount).toFixed(6)),
    borderPixels,
  };
}

async function main() {
  fs.mkdirSync(outDir, { recursive: true });
  const manifest = {
    generatedAt: new Date().toISOString(),
    renderer: `sharp ${sharp.versions.sharp}; librsvg ${sharp.versions.svg || 'bundled'}`,
    sourceDir: path.relative(root, sourceDir).replaceAll('\\', '/'),
    outputs: [],
  };

  for (const [sourceName, sizes] of Object.entries(sizesBySource)) {
    const source = path.join(sourceDir, sourceName);
    if (!fs.existsSync(source)) throw new Error(`Missing source: ${source}`);
    const svg = fs.readFileSync(source);
    const stem = path.basename(sourceName, '.svg');
    for (const size of sizes) {
      const output = path.join(outDir, `${stem}-${size}.png`);
      await sharp(svg, { density: 384 })
        .resize(size, size, { fit: 'contain', kernel: sharp.kernel.lanczos3 })
        .png({ compressionLevel: 9, adaptiveFiltering: true })
        .toFile(output);
      const metrics = await alphaMetrics(output);
      const isOpaqueField = sourceName.includes('app-icon');
      if (!isOpaqueField && metrics.borderPixels !== 0) {
        throw new Error(`${path.basename(output)} clips ${metrics.borderPixels} non-transparent border pixels`);
      }
      manifest.outputs.push({
        source: sourceName,
        size,
        file: path.relative(root, output).replaceAll('\\', '/'),
        bytes: fs.statSync(output).size,
        sha256: sha256(output),
        ...metrics,
      });
    }
  }

  const manifestFile = path.join(outDir, 'render-manifest.json');
  fs.writeFileSync(manifestFile, `${JSON.stringify(manifest, null, 2)}\n`);
  process.stdout.write(`${JSON.stringify({ manifest: manifestFile, count: manifest.outputs.length }, null, 2)}\n`);
}

main().catch((error) => {
  process.stderr.write(`${error.stack || error}\n`);
  process.exitCode = 1;
});
