const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const sharp = require('sharp');

const root = path.resolve(__dirname, '..', '..');
const productionRoot = path.join(
  root,
  'docs',
  'codex',
  '2026-07-15-synapse-medical-learning-os',
  'assets',
  'identity',
  'production',
  'mcr4-01-evidence-guide',
);
const sourceDir = path.join(productionRoot, 'source');
const renderDir = path.join(productionRoot, 'renders');
const platformDir = path.join(productionRoot, 'platforms');
const appRoot = path.join(root, 'apps', 'app');
const install = process.argv.includes('--install');

const APP_ICON = path.join(sourceDir, 'icr4-04-app-icon-master-1024.png');
const FOREGROUND = path.join(sourceDir, 'icr4-04-foreground-1024.png');
const ADAPTIVE = path.join(sourceDir, 'icr4-04-adaptive-foreground-1024.png');
const MONO = path.join(sourceDir, 'icr4-04-monochrome-foreground-1024.png');
const TINTED = path.join(sourceDir, 'icr4-04-tinted-master-1024.png');
const CANVAS = 1024;
const ADAPTIVE_SAFE_RADIUS = 304;
const SOURCE_DATE = '2026-07-17';
const outputs = [];

function ensureDir(dir) {
  fs.mkdirSync(dir, { recursive: true });
}

function rel(file) {
  return path.relative(root, file).replaceAll('\\', '/');
}

function sha256(input) {
  return crypto.createHash('sha256').update(input).digest('hex').toUpperCase();
}

function write(file, contents, metadata = {}) {
  ensureDir(path.dirname(file));
  fs.writeFileSync(file, contents);
  const bytes = fs.readFileSync(file);
  outputs.push({
    file: rel(file),
    bytes: bytes.length,
    sha256: sha256(bytes),
    ...metadata,
  });
}

function copy(file, target, metadata = {}) {
  write(target, fs.readFileSync(file), metadata);
}

async function resizePng(input, size) {
  return sharp(input)
    .resize(size, size, { fit: 'fill', kernel: sharp.kernel.lanczos3 })
    .png({ compressionLevel: 9, adaptiveFiltering: true })
    .toBuffer();
}

async function alphaMetrics(input) {
  const { data, info } = await sharp(input)
    .ensureAlpha()
    .raw()
    .toBuffer({ resolveWithObject: true });
  let minX = info.width;
  let minY = info.height;
  let maxX = -1;
  let maxY = -1;
  let maxRadius = 0;
  let alphaPixels = 0;
  const cx = (info.width - 1) / 2;
  const cy = (info.height - 1) / 2;
  for (let y = 0; y < info.height; y += 1) {
    for (let x = 0; x < info.width; x += 1) {
      const alpha = data[(y * info.width + x) * info.channels + 3];
      if (alpha <= 64) continue;
      alphaPixels += 1;
      minX = Math.min(minX, x);
      minY = Math.min(minY, y);
      maxX = Math.max(maxX, x);
      maxY = Math.max(maxY, y);
      maxRadius = Math.max(maxRadius, Math.hypot(x - cx, y - cy));
    }
  }
  return {
    width: info.width,
    height: info.height,
    alphaBounds: maxX < 0 ? null : [minX, minY, maxX, maxY],
    alphaPixels,
    maxRadius: Number(maxRadius.toFixed(3)),
  };
}

async function field(variant = 'default') {
  const palettes = {
    default: ['#143969', '#0A2447', '#030C25'],
    dark: ['#102F57', '#071A34', '#020817'],
    frost: ['#F7FAFF', '#DCE9FF', '#B9D2FA'],
  };
  const [a, b, c] = palettes[variant];
  const svg = Buffer.from(
    `<svg xmlns="http://www.w3.org/2000/svg" width="${CANVAS}" height="${CANVAS}" viewBox="0 0 ${CANVAS} ${CANVAS}">` +
      '<defs><radialGradient id="g" cx="47%" cy="43%" r="82%">' +
      `<stop offset="0" stop-color="${a}"/><stop offset="58%" stop-color="${b}"/>` +
      `<stop offset="100%" stop-color="${c}"/></radialGradient></defs>` +
      `<rect width="${CANVAS}" height="${CANVAS}" fill="url(#g)"/></svg>`,
  );
  return sharp(svg).png({ compressionLevel: 9, adaptiveFiltering: true }).toBuffer();
}

async function compositeIcon(background, foreground) {
  return sharp(background)
    .composite([{ input: foreground }])
    .png({ compressionLevel: 9, adaptiveFiltering: true })
    .toBuffer();
}

async function masked(buffer, kind) {
  const masks = {
    circle: '<circle cx="256" cy="256" r="256" fill="white"/>',
    squircle: '<rect width="512" height="512" rx="118" fill="white"/>',
    rounded: '<rect width="512" height="512" rx="82" fill="white"/>',
  };
  return sharp(buffer)
    .resize(512, 512)
    .composite([{
      input: Buffer.from(`<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512">${masks[kind]}</svg>`),
      blend: 'dest-in',
    }])
    .png({ compressionLevel: 9, adaptiveFiltering: true })
    .toBuffer();
}

function buildIco(images) {
  const header = Buffer.alloc(6);
  header.writeUInt16LE(0, 0);
  header.writeUInt16LE(1, 2);
  header.writeUInt16LE(images.length, 4);
  const entries = Buffer.alloc(images.length * 16);
  let offset = 6 + entries.length;
  images.forEach(({ size, buffer }, index) => {
    const cursor = index * 16;
    entries.writeUInt8(size >= 256 ? 0 : size, cursor);
    entries.writeUInt8(size >= 256 ? 0 : size, cursor + 1);
    entries.writeUInt8(0, cursor + 2);
    entries.writeUInt8(0, cursor + 3);
    entries.writeUInt16LE(1, cursor + 4);
    entries.writeUInt16LE(32, cursor + 6);
    entries.writeUInt32LE(buffer.length, cursor + 8);
    entries.writeUInt32LE(offset, cursor + 12);
    offset += buffer.length;
  });
  return Buffer.concat([header, entries, ...images.map((image) => image.buffer)]);
}

async function exportApple(appIcon, darkIcon, tintedIcon) {
  const appleDir = path.join(platformDir, 'apple');
  write(path.join(appleDir, 'sources', 'synapse-default-1024.png'), appIcon, {
    platform: 'apple', role: 'default-source', identity: 'ICR4-04',
  });
  write(path.join(appleDir, 'sources', 'synapse-dark-1024.png'), darkIcon, {
    platform: 'apple', role: 'dark-source-unwired', identity: 'ICR4-04',
  });
  write(path.join(appleDir, 'sources', 'synapse-tinted-1024.png'), tintedIcon, {
    platform: 'apple', role: 'tinted-source-unwired', identity: 'ICR4-04',
  });

  const iosCatalog = path.join(appRoot, 'ios', 'Runner', 'Assets.xcassets', 'AppIcon.appiconset');
  const iosContents = JSON.parse(fs.readFileSync(path.join(iosCatalog, 'Contents.json'), 'utf8'));
  const iosOut = path.join(appleDir, 'ios', 'AppIcon.appiconset');
  write(path.join(iosOut, 'Contents.json'), `${JSON.stringify(iosContents, null, 2)}\n`, {
    platform: 'ios', role: 'catalog',
  });
  const doneIos = new Set();
  for (const image of iosContents.images) {
    if (!image.filename || doneIos.has(image.filename)) continue;
    const points = Number(image.size.split('x')[0]);
    const scale = Number(image.scale.replace('x', ''));
    const pixels = Math.round(points * scale);
    const png = await resizePng(appIcon, pixels);
    write(path.join(iosOut, image.filename), png, {
      platform: 'ios', role: 'app-icon', pixels, identity: 'ICR4-04',
    });
    if (install) write(path.join(iosCatalog, image.filename), png, {
      platform: 'ios-install', role: 'app-icon', pixels, identity: 'ICR4-04',
    });
    doneIos.add(image.filename);
  }

  const macCatalog = path.join(appRoot, 'macos', 'Runner', 'Assets.xcassets', 'AppIcon.appiconset');
  const macContents = JSON.parse(fs.readFileSync(path.join(macCatalog, 'Contents.json'), 'utf8'));
  const macOut = path.join(appleDir, 'macos', 'AppIcon.appiconset');
  write(path.join(macOut, 'Contents.json'), `${JSON.stringify(macContents, null, 2)}\n`, {
    platform: 'macos', role: 'catalog',
  });
  const doneMac = new Set();
  for (const image of macContents.images) {
    if (!image.filename || doneMac.has(image.filename)) continue;
    const pixels = Number(image.filename.match(/(\d+)/)[1]);
    const png = await resizePng(appIcon, pixels);
    write(path.join(macOut, image.filename), png, {
      platform: 'macos', role: 'app-icon', pixels, identity: 'ICR4-04',
    });
    if (install) write(path.join(macCatalog, image.filename), png, {
      platform: 'macos-install', role: 'app-icon', pixels, identity: 'ICR4-04',
    });
    doneMac.add(image.filename);
  }
}

async function exportAndroid(appIcon, adaptiveForeground, monoForeground) {
  const androidDir = path.join(platformDir, 'android', 'res');
  const densities = { mdpi: 48, hdpi: 72, xhdpi: 96, xxhdpi: 144, xxxhdpi: 192 };
  const foregroundSizes = { mdpi: 108, hdpi: 162, xhdpi: 216, xxhdpi: 324, xxxhdpi: 432 };
  for (const [density, size] of Object.entries(densities)) {
    const dir = path.join(androidDir, `mipmap-${density}`);
    const legacy = await resizePng(appIcon, size);
    const roundMask = Buffer.from(
      `<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}">` +
      `<circle cx="${size / 2}" cy="${size / 2}" r="${size / 2}" fill="white"/></svg>`,
    );
    const round = await sharp(legacy)
      .composite([{ input: roundMask, blend: 'dest-in' }])
      .png({ compressionLevel: 9 })
      .toBuffer();
    const foreground = await resizePng(adaptiveForeground, foregroundSizes[density]);
    const monochrome = await resizePng(monoForeground, foregroundSizes[density]);
    const files = [
      ['ic_launcher.png', legacy, 'legacy'],
      ['ic_launcher_round.png', round, 'legacy-round'],
      ['ic_launcher_foreground.png', foreground, 'adaptive-foreground'],
      ['ic_launcher_monochrome.png', monochrome, 'themed-monochrome'],
    ];
    for (const [name, buffer, role] of files) {
      write(path.join(dir, name), buffer, {
        platform: 'android', role, density, identity: 'ICR4-04',
      });
      if (install) write(
        path.join(appRoot, 'android', 'app', 'src', 'main', 'res', `mipmap-${density}`, name),
        buffer,
        { platform: 'android-install', role, density, identity: 'ICR4-04' },
      );
    }
  }

  const v26 = '<?xml version="1.0" encoding="utf-8"?>\n' +
    '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n' +
    '    <background android:drawable="@color/synapse_launcher_background" />\n' +
    '    <foreground android:drawable="@mipmap/ic_launcher_foreground" />\n' +
    '</adaptive-icon>\n';
  const v33 = '<?xml version="1.0" encoding="utf-8"?>\n' +
    '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n' +
    '    <background android:drawable="@color/synapse_launcher_background" />\n' +
    '    <foreground android:drawable="@mipmap/ic_launcher_foreground" />\n' +
    '    <monochrome android:drawable="@mipmap/ic_launcher_monochrome" />\n' +
    '</adaptive-icon>\n';
  const colors = '<?xml version="1.0" encoding="utf-8"?>\n' +
    '<resources>\n    <color name="synapse_launcher_background">#07182D</color>\n</resources>\n';
  for (const [qualifier, xml] of [['mipmap-anydpi-v26', v26], ['mipmap-anydpi-v33', v33]]) {
    for (const name of ['ic_launcher.xml', 'ic_launcher_round.xml']) {
      write(path.join(androidDir, qualifier, name), xml, {
        platform: 'android', role: qualifier, identity: 'ICR4-04',
      });
      if (install) write(
        path.join(appRoot, 'android', 'app', 'src', 'main', 'res', qualifier, name),
        xml,
        { platform: 'android-install', role: qualifier, identity: 'ICR4-04' },
      );
    }
  }
  write(path.join(androidDir, 'values', 'synapse_launcher_colors.xml'), colors, {
    platform: 'android', role: 'launcher-color',
  });
  if (install) write(
    path.join(appRoot, 'android', 'app', 'src', 'main', 'res', 'values', 'synapse_launcher_colors.xml'),
    colors,
    { platform: 'android-install', role: 'launcher-color' },
  );
}

async function exportWeb(appIcon, maskableIcon) {
  const webDir = path.join(platformDir, 'web');
  const files = [
    ['icons/Icon-192.png', await resizePng(appIcon, 192), 'regular'],
    ['icons/Icon-512.png', await resizePng(appIcon, 512), 'regular'],
    ['icons/Icon-maskable-192.png', await resizePng(maskableIcon, 192), 'maskable'],
    ['icons/Icon-maskable-512.png', await resizePng(maskableIcon, 512), 'maskable'],
    ['favicon-16.png', await resizePng(appIcon, 16), 'favicon'],
    ['favicon-24.png', await resizePng(appIcon, 24), 'favicon'],
    ['favicon-32.png', await resizePng(appIcon, 32), 'favicon'],
    ['favicon-48.png', await resizePng(appIcon, 48), 'favicon'],
  ];
  for (const [name, buffer, role] of files) {
    write(path.join(webDir, name), buffer, {
      platform: 'web', role, identity: 'ICR4-04',
    });
    if (install) {
      const target = role === 'favicon' && name === 'favicon-32.png'
        ? path.join(appRoot, 'web', 'favicon.png')
        : role === 'favicon' ? null : path.join(appRoot, 'web', name);
      if (target) write(target, buffer, {
        platform: 'web-install', role, identity: 'ICR4-04',
      });
    }
  }
  const maskable512 = await resizePng(maskableIcon, 512);
  for (const kind of ['circle', 'squircle', 'rounded']) {
    write(path.join(webDir, 'proofs', `${kind}-mask.png`), await masked(maskable512, kind), {
      platform: 'web', role: 'mask-proof', mask: kind, identity: 'ICR4-04',
    });
  }
}

async function exportWindowsLinux(appIcon) {
  const winDir = path.join(platformDir, 'windows');
  const icoSizes = [16, 24, 32, 48, 64, 128, 256];
  const icoImages = [];
  for (const size of icoSizes) {
    const buffer = await resizePng(appIcon, size);
    write(path.join(winDir, `synapse-${size}.png`), buffer, {
      platform: 'windows', role: 'ico-source', pixels: size, identity: 'ICR4-04',
    });
    icoImages.push({ size, buffer });
  }
  const ico = buildIco(icoImages);
  write(path.join(winDir, 'app_icon.ico'), ico, {
    platform: 'windows', role: 'multi-size-ico', sizes: icoSizes, identity: 'ICR4-04',
  });
  if (install) write(path.join(appRoot, 'windows', 'runner', 'resources', 'app_icon.ico'), ico, {
    platform: 'windows-install', role: 'multi-size-ico', sizes: icoSizes, identity: 'ICR4-04',
  });

  const linuxDir = path.join(platformDir, 'linux', 'hicolor');
  for (const size of [16, 24, 32, 48, 64, 128, 256, 512, 1024]) {
    write(
      path.join(linuxDir, `${size}x${size}`, 'apps', 'synapse.png'),
      await resizePng(appIcon, size),
      { platform: 'linux', role: 'hicolor', pixels: size, identity: 'ICR4-04' },
    );
  }
  copy(APP_ICON, path.join(platformDir, 'linux', 'source', 'synapse-1024.png'), {
    platform: 'linux', role: 'raster-source', identity: 'ICR4-04',
  });
}

async function exportFlutterRuntime() {
  const runtimeDir = path.join(platformDir, 'flutter', 'assets', 'identity', 'mcr4_companion');
  const appAssets = path.join(appRoot, 'assets', 'identity', 'mcr4_companion');
  const iconSizes = [1024, 512, 256, 96, 48, 24, 16];
  for (const size of iconSizes) {
    const source = size <= 48
      ? path.join(renderDir, `icr4-04-app-icon-${size}.png`)
      : APP_ICON;
    const png = size <= 48 ? fs.readFileSync(source) : await resizePng(APP_ICON, size);
    const name = `app_icon_${size}.png`;
    write(path.join(runtimeDir, name), png, {
      platform: 'flutter', role: 'app-icon', pixels: size, identity: 'ICR4-04',
    });
    if (install) write(path.join(appAssets, name), png, {
      platform: 'flutter-install', role: 'app-icon', pixels: size, identity: 'ICR4-04',
    });
  }

  const poses = [
    'hero-pointing',
    'encouraging',
    'thinking',
    'evidence-guide',
    'quest-host',
    'recovery',
  ];
  for (const pose of poses) {
    const source = path.join(sourceDir, `mcr4-01-${pose}-1024.png`);
    for (const size of [1024, 512, 256]) {
      const png = size === 1024 ? fs.readFileSync(source) : await resizePng(source, size);
      const name = `mascot_${pose.replaceAll('-', '_')}_${size}.png`;
      write(path.join(runtimeDir, name), png, {
        platform: 'flutter', role: 'mascot-pose', pose, pixels: size, identity: 'MCR4-01',
      });
      if (install) write(path.join(appAssets, name), png, {
        platform: 'flutter-install', role: 'mascot-pose', pose, pixels: size, identity: 'MCR4-01',
      });
    }
  }
  for (const [name, source, role] of [
    ['app_icon_adaptive_foreground_1024.png', ADAPTIVE, 'adaptive-foreground'],
    ['app_icon_monochrome_1024.png', MONO, 'monochrome'],
  ]) {
    copy(source, path.join(runtimeDir, name), {
      platform: 'flutter', role, identity: 'ICR4-04',
    });
    if (install) copy(source, path.join(appAssets, name), {
      platform: 'flutter-install', role, identity: 'ICR4-04',
    });
  }
}

async function main() {
  const required = [APP_ICON, FOREGROUND, ADAPTIVE, MONO, TINTED];
  for (const pose of ['hero-pointing', 'encouraging', 'thinking', 'evidence-guide', 'quest-host', 'recovery']) {
    required.push(path.join(sourceDir, `mcr4-01-${pose}-1024.png`));
  }
  for (const file of required) {
    if (!fs.existsSync(file)) throw new Error(`Missing selected identity source: ${file}`);
  }
  fs.rmSync(platformDir, { recursive: true, force: true });
  ensureDir(platformDir);

  const appIcon = fs.readFileSync(APP_ICON);
  const foreground = fs.readFileSync(FOREGROUND);
  const adaptive = fs.readFileSync(ADAPTIVE);
  const monochrome = fs.readFileSync(MONO);
  const tinted = fs.readFileSync(TINTED);
  const defaultField = await field('default');
  const darkField = await field('dark');
  const maskableIcon = await compositeIcon(defaultField, adaptive);
  const darkIcon = await compositeIcon(darkField, foreground);

  const adaptiveMetrics = await alphaMetrics(adaptive);
  const monoMetrics = await alphaMetrics(monochrome);
  if (adaptiveMetrics.maxRadius > ADAPTIVE_SAFE_RADIUS) {
    throw new Error(`Adaptive foreground exceeds safe radius: ${adaptiveMetrics.maxRadius}`);
  }
  if (monoMetrics.maxRadius > ADAPTIVE_SAFE_RADIUS) {
    throw new Error(`Monochrome foreground exceeds safe radius: ${monoMetrics.maxRadius}`);
  }

  await exportApple(appIcon, darkIcon, tinted);
  await exportAndroid(appIcon, adaptive, monochrome);
  await exportWeb(appIcon, maskableIcon);
  await exportWindowsLinux(appIcon);
  await exportFlutterRuntime();

  const manifest = {
    schemaVersion: 1,
    sourceDate: SOURCE_DATE,
    selectedIdentity: {
      mascot: 'MCR4-01 Sidecrest Companion',
      appIcon: 'ICR4-04 Evidence Guide',
    },
    installedIntoFlutterProject: install,
    renderer: `sharp ${sharp.versions.sharp}; libvips ${sharp.versions.vips}`,
    inputs: required.map((file) => ({ file: rel(file), sha256: sha256(fs.readFileSync(file)) })),
    safeZone: {
      canvas: CANVAS,
      radius: ADAPTIVE_SAFE_RADIUS,
      ratio: ADAPTIVE_SAFE_RADIUS / CANVAS,
      foreground: adaptiveMetrics,
      monochrome: monoMetrics,
    },
    outputs,
  };
  const manifestFile = path.join(platformDir, 'platform-manifest.json');
  fs.writeFileSync(manifestFile, `${JSON.stringify(manifest, null, 2)}\n`);
  process.stdout.write(`${JSON.stringify({
    manifest: rel(manifestFile),
    outputs: outputs.length,
    install,
    safeZone: manifest.safeZone,
  }, null, 2)}\n`);
}

main().catch((error) => {
  process.stderr.write(`${error.stack || error}\n`);
  process.exitCode = 1;
});
