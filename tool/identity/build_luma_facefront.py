#!/usr/bin/env python3
"""Restore the user-selected LUMA Facefront identity from approved boards.

The two supplied boards are immutable visual evidence. This builder locks their
hashes, derives a clean production asset package without board labels or frames,
and installs a byte-identical launcher/runtime set for the six Flutter targets.
It intentionally extracts rather than redraws or reinterprets LUMA.
"""

from __future__ import annotations

import argparse
import hashlib
import io
import json
import math
import re
import shutil
import struct
from collections.abc import Iterable
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[2]
TASK = ROOT / "docs/codex/2026-07-15-synapse-medical-learning-os"
IDENTITY = TASK / "assets/identity"
ICON_BOARD = IDENTITY / "icons-round-2/2026-07-16_icr2-01_luma-facefront_concept.png"
MASCOT_BOARD = TASK / "assets/previews/2026-07-15_refine-01_luma-character-system.png"
PRODUCTION = IDENTITY / "production/luma-facefront-restored"
SOURCE = PRODUCTION / "source"
RENDERS = PRODUCTION / "renders"
PLATFORMS = PRODUCTION / "platforms"
APP = ROOT / "apps/app"

EXPECTED_INPUTS = {
    ICON_BOARD: {
        "sha256": "352FC04100F77A4203115BAE9DD090D8D0116AEDC541466DFB3656D33727FD19",
        "size": (1536, 1024),
    },
    MASCOT_BOARD: {
        "sha256": "939F98A302D269A03CBFC08995D7A62A5E4939896FDE212D8D56AA63CA99CD94",
        "size": (1536, 1024),
    },
}

# These crops deliberately avoid all board labels, panel frames, and specimen
# annotations. They are recorded in the source manifest as reproducible evidence.
ICON_CROP = (52, 48, 480, 456)
MASCOT_CROPS = {
    "hero_pointing": (18, 210, 330, 458),
    "encouraging": (143, 570, 247, 685),
    "thinking": (262, 570, 370, 685),
    "evidence_guide": (1128, 255, 1252, 420),
    "quest_host": (1252, 255, 1378, 423),
    "recovery": (1380, 282, 1535, 423),
}

CANVAS = 1024
ADAPTIVE_SAFE_RADIUS = 304.0
IDENTITY_RECORD = {
    "mascot": "LUMA Character System",
    "appIcon": "ICR2-01 LUMA Facefront",
    "conceptId": "ICR2-01",
    "status": "restored-by-latest-direct-user-decision",
}
RESAMPLING = getattr(Image, "Resampling", Image)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def rel(path: Path) -> str:
    return path.relative_to(ROOT).as_posix()


def verify_inputs() -> list[dict[str, object]]:
    records: list[dict[str, object]] = []
    for path, expected in EXPECTED_INPUTS.items():
        if not path.is_file():
            raise FileNotFoundError(f"Missing selected identity evidence: {path}")
        actual_hash = sha256(path)
        with Image.open(path) as image:
            actual_size = image.size
        if actual_hash != expected["sha256"]:
            raise RuntimeError(
                f"Selected evidence hash changed for {path}: {actual_hash}"
            )
        if actual_size != expected["size"]:
            raise RuntimeError(
                f"Selected evidence dimensions changed for {path}: {actual_size}"
            )
        records.append(
            {
                "file": rel(path),
                "sha256": actual_hash,
                "size": list(actual_size),
            }
        )
    return records


def _fill_holes(mask: Image.Image) -> Image.Image:
    binary = mask.convert("L").point(lambda value: 255 if value >= 128 else 0)
    bordered = Image.new("L", (binary.width + 2, binary.height + 2), 0)
    bordered.paste(binary, (1, 1))
    ImageDraw.floodfill(bordered, (0, 0), 128, thresh=0)
    values = np.asarray(bordered, dtype=np.uint8)[1:-1, 1:-1]
    filled = np.where(values == 0, 255, np.where(values == 255, 255, 0)).astype(
        np.uint8
    )
    return Image.fromarray(filled, mode="L")


def extract_subject(
    crop: Image.Image,
    *,
    luminance_floor: float,
    color_distance_floor: float,
    close_size: int = 7,
    blur_radius: float = 1.05,
) -> Image.Image:
    """Convert a text-free Night Shift crop into transparent character art."""
    rgb = np.asarray(crop.convert("RGB"), dtype=np.float32)
    luminance = (
        rgb[:, :, 0] * 0.2126 + rgb[:, :, 1] * 0.7152 + rgb[:, :, 2] * 0.0722
    )
    border = np.concatenate(
        [
            rgb[:8].reshape(-1, 3),
            rgb[-8:].reshape(-1, 3),
            rgb[:, :8].reshape(-1, 3),
            rgb[:, -8:].reshape(-1, 3),
        ],
        axis=0,
    )
    background = np.median(border, axis=0)
    distance = np.linalg.norm(rgb - background[None, None, :], axis=2)
    cyan_signal = (rgb[:, :, 2] - rgb[:, :, 0]) + (
        rgb[:, :, 1] - rgb[:, :, 0]
    ) * 0.35
    seed = (luminance >= luminance_floor) | (
        (distance >= color_distance_floor)
        & (luminance >= 15)
        & (cyan_signal >= 7)
    )
    mask = Image.fromarray((seed.astype(np.uint8) * 255), mode="L")
    close_size = max(3, close_size | 1)
    mask = mask.filter(ImageFilter.MaxFilter(close_size))
    mask = mask.filter(ImageFilter.MinFilter(close_size))
    mask = _fill_holes(mask).filter(ImageFilter.GaussianBlur(blur_radius))
    result = crop.convert("RGBA")
    result.putalpha(mask)
    return result


def trim_alpha(image: Image.Image, threshold: int = 4) -> Image.Image:
    alpha = image.getchannel("A").point(lambda value: 255 if value > threshold else 0)
    bounds = alpha.getbbox()
    if bounds is None:
        raise RuntimeError("Extracted LUMA subject has no alpha coverage")
    return image.crop(bounds)


def clear_alpha_regions(image: Image.Image, regions: Iterable[tuple[int, int, int, int]]) -> Image.Image:
    """Remove known board-only regions without repainting selected character pixels."""
    alpha = np.asarray(image.getchannel("A"), dtype=np.uint8).copy()
    for left, top, right, bottom in regions:
        alpha[max(0, top) : min(alpha.shape[0], bottom), max(0, left) : min(alpha.shape[1], right)] = 0
    result = image.copy()
    result.putalpha(Image.fromarray(alpha, mode="L"))
    return result


def contain_on_canvas(
    image: Image.Image,
    size: int,
    *,
    max_width: int,
    max_height: int,
    y_offset: int = 0,
) -> Image.Image:
    subject = trim_alpha(image)
    scale = min(max_width / subject.width, max_height / subject.height)
    width = max(1, round(subject.width * scale))
    height = max(1, round(subject.height * scale))
    subject = subject.resize((width, height), RESAMPLING.LANCZOS)
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    left = round((size - width) / 2)
    top = round((size - height) / 2) + y_offset
    canvas.alpha_composite(subject, (left, top))
    return canvas


def midnight_field(size: int, *, variant: str = "default") -> Image.Image:
    palettes = {
        "default": ((20, 57, 105), (3, 12, 37)),
        "dark": ((16, 47, 87), (2, 8, 23)),
        "frost": ((247, 250, 255), (185, 210, 248)),
    }
    center, edge = palettes[variant]
    yy, xx = np.mgrid[0:size, 0:size]
    nx = xx / max(1, size - 1)
    ny = yy / max(1, size - 1)
    distance = np.sqrt(((nx - 0.47) / 0.78) ** 2 + ((ny - 0.43) / 0.82) ** 2)
    blend = np.clip(distance, 0, 1)
    blend = blend * blend * (3 - 2 * blend)
    start = np.array(center, dtype=np.float32)
    finish = np.array(edge, dtype=np.float32)
    rgb = start[None, None, :] * (1 - blend[:, :, None]) + finish[None, None, :] * blend[
        :, :, None
    ]
    if variant != "frost":
        cobalt = np.exp(-(((nx - 0.38) / 0.37) ** 2 + ((ny - 0.70) / 0.32) ** 2))
        rgb[:, :, 2] += cobalt * 12
        rgb[:, :, 1] += cobalt * 4
    return Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8), mode="RGB")


def composite(background: Image.Image, foreground: Image.Image) -> Image.Image:
    result = background.convert("RGBA")
    result.alpha_composite(foreground)
    return result.convert("RGB")


def monochrome_from_alpha(image: Image.Image, *, ink: bool = False) -> Image.Image:
    result = Image.new("RGBA", image.size, (7, 24, 45, 255) if ink else (255, 255, 255, 255))
    result.putalpha(image.getchannel("A"))
    return result


def save_png(image: Image.Image, path: Path, outputs: list[dict[str, object]], **metadata: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, format="PNG", optimize=True, compress_level=9)
    outputs.append(
        {
            "file": rel(path),
            "bytes": path.stat().st_size,
            "sha256": sha256(path),
            "size": list(image.size),
            "mode": image.mode,
            **metadata,
        }
    )


def save_bytes(data: bytes, path: Path, outputs: list[dict[str, object]], **metadata: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)
    outputs.append(
        {
            "file": rel(path),
            "bytes": len(data),
            "sha256": hashlib.sha256(data).hexdigest().upper(),
            **metadata,
        }
    )


def png_bytes(image: Image.Image) -> bytes:
    target = io.BytesIO()
    image.save(target, format="PNG", optimize=True, compress_level=9)
    return target.getvalue()


def alpha_metrics(image: Image.Image) -> dict[str, object]:
    rgba = np.asarray(image.convert("RGBA"), dtype=np.uint8)
    alpha = rgba[:, :, 3]
    ys, xs = np.where(alpha > 64)
    if not len(xs):
        return {"bounds": None, "pixels": 0, "maxRadius": None, "cornerAlpha": [0] * 4}
    cx = (rgba.shape[1] - 1) / 2
    cy = (rgba.shape[0] - 1) / 2
    return {
        "bounds": [int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())],
        "pixels": int(len(xs)),
        "maxRadius": round(float(np.sqrt((xs - cx) ** 2 + (ys - cy) ** 2).max()), 3),
        "cornerAlpha": [
            int(alpha[0, 0]),
            int(alpha[0, -1]),
            int(alpha[-1, 0]),
            int(alpha[-1, -1]),
        ],
    }


def mask_preview(image: Image.Image, kind: str, size: int = 512) -> Image.Image:
    sample = image.resize((size, size), RESAMPLING.LANCZOS).convert("RGBA")
    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)
    if kind == "circle":
        draw.ellipse((0, 0, size - 1, size - 1), fill=255)
    elif kind == "squircle":
        draw.rounded_rectangle((0, 0, size - 1, size - 1), radius=round(size * 0.23), fill=255)
    elif kind == "rounded":
        draw.rounded_rectangle((0, 0, size - 1, size - 1), radius=round(size * 0.16), fill=255)
    else:
        raise ValueError(kind)
    sample.putalpha(mask)
    return sample


def _font(size: int) -> ImageFont.ImageFont:
    candidates: Iterable[Path] = (
        Path("C:/Windows/Fonts/segoeuib.ttf"),
        Path("C:/Windows/Fonts/arialbd.ttf"),
    )
    for candidate in candidates:
        if candidate.is_file():
            return ImageFont.truetype(str(candidate), size=size)
    return ImageFont.load_default()


def proof_board(
    app_master: Image.Image,
    adaptive: Image.Image,
    monochrome: Image.Image,
    hero: Image.Image,
) -> Image.Image:
    board = midnight_field(1600).crop((0, 0, 1600, 1000)).convert("RGBA")
    draw = ImageDraw.Draw(board)
    title = _font(34)
    label = _font(20)
    draw.text((58, 36), "SYNAPSE LUMA FACEFRONT — RESTORED PRODUCTION", font=title, fill=(236, 244, 255))
    draw.text((58, 84), "ICR2-01 ICON + APPROVED LUMA CHARACTER SYSTEM", font=label, fill=(76, 178, 255))
    board.alpha_composite(hero.resize((500, 500), RESAMPLING.LANCZOS), (40, 168))
    board.alpha_composite(app_master.resize((520, 520), RESAMPLING.LANCZOS).convert("RGBA"), (558, 160))
    draw.text((558, 692), "OPAQUE LAUNCHER MASTER", font=label, fill=(236, 244, 255))
    x = 60
    for name, image in (
        ("CIRCLE", mask_preview(app_master, "circle", 210)),
        ("SQUIRCLE", mask_preview(app_master, "squircle", 210)),
        ("ADAPTIVE FG", adaptive.resize((210, 210), RESAMPLING.LANCZOS)),
        ("MONO", monochrome.resize((210, 210), RESAMPLING.LANCZOS)),
    ):
        board.alpha_composite(image.convert("RGBA"), (x, 740))
        draw.text((x, 954), name, font=label, fill=(174, 204, 244))
        x += 270
    for size, x, scale in ((48, 1120, 3), (24, 1300, 5), (16, 1460, 6)):
        tiny = app_master.resize((size, size), RESAMPLING.LANCZOS)
        board.alpha_composite(tiny.resize((size * scale, size * scale), RESAMPLING.NEAREST).convert("RGBA"), (x, 770))
        draw.text((x, 954), f"{size} PX", font=label, fill=(174, 204, 244))
    return board.convert("RGB")


def build_source() -> tuple[dict[str, object], dict[str, Image.Image]]:
    inputs = verify_inputs()
    if PRODUCTION.exists():
        shutil.rmtree(PRODUCTION)
    SOURCE.mkdir(parents=True, exist_ok=True)
    RENDERS.mkdir(parents=True, exist_ok=True)
    outputs: list[dict[str, object]] = []

    icon_crop = Image.open(ICON_BOARD).convert("RGB").crop(ICON_CROP).resize((CANVAS, CANVAS), RESAMPLING.LANCZOS)
    icon_subject = extract_subject(
        icon_crop,
        luminance_floor=63,
        color_distance_floor=30,
        close_size=9,
        blur_radius=1.2,
    )
    icon_foreground = contain_on_canvas(icon_subject, CANVAS, max_width=840, max_height=840, y_offset=0)
    app_master = composite(midnight_field(CANVAS), icon_foreground)
    adaptive = contain_on_canvas(icon_foreground, CANVAS, max_width=480, max_height=480, y_offset=-4)
    monochrome = monochrome_from_alpha(adaptive)
    tinted = composite(midnight_field(CANVAS, variant="frost"), monochrome_from_alpha(adaptive, ink=True))

    for image, name in (
        (icon_crop, "icr2-01-approved-preview-crop-1024.png"),
        (icon_foreground, "luma-facefront-foreground-1024.png"),
        (app_master, "luma-facefront-app-icon-master-1024.png"),
        (adaptive, "luma-facefront-adaptive-foreground-1024.png"),
        (monochrome, "luma-facefront-monochrome-foreground-1024.png"),
        (tinted, "luma-facefront-tinted-master-1024.png"),
    ):
        save_png(image, SOURCE / name, outputs, surface="source")

    mascot_board = Image.open(MASCOT_BOARD).convert("RGB")
    poses: dict[str, Image.Image] = {}
    for name, crop_bounds in MASCOT_CROPS.items():
        raw = mascot_board.crop(crop_bounds)
        extracted = extract_subject(
            raw,
            luminance_floor=43 if name == "recovery" else 54,
            color_distance_floor=25 if name == "recovery" else 30,
            close_size=7,
            blur_radius=1.0,
        )
        if name == "hero_pointing":
            # The original character-system board puts its section label just
            # above LUMA's head and silhouette-rule dots just beyond the hand.
            # These two text-free cutouts keep the approved character intact.
            extracted = clear_alpha_regions(
                extracted,
                ((0, 0, 250, 34), (292, 0, raw.width, raw.height)),
            )
        canvas = contain_on_canvas(
            extracted,
            CANVAS,
            max_width=900 if name == "hero_pointing" else 820,
            max_height=900 if name == "hero_pointing" else 820,
            y_offset=12,
        )
        poses[name] = canvas
        save_png(canvas, SOURCE / f"luma-{name.replace('_', '-')}-1024.png", outputs, surface="source", pose=name)

    for size in (512, 256, 128, 96, 64, 48, 32, 24, 16):
        icon = app_master.resize((size, size), RESAMPLING.LANCZOS)
        if size <= 48:
            icon = icon.filter(ImageFilter.UnsharpMask(radius=0.7, percent=110, threshold=3))
        save_png(icon, RENDERS / f"luma-facefront-app-icon-{size}.png", outputs, surface="render", pixels=size)
    for kind in ("circle", "squircle", "rounded"):
        save_png(mask_preview(app_master, kind), RENDERS / f"luma-facefront-{kind}-proof-512.png", outputs, surface="proof", mask=kind)
    for name, image in poses.items():
        for size in (512, 256):
            save_png(image.resize((size, size), RESAMPLING.LANCZOS), RENDERS / f"luma-{name.replace('_', '-')}-{size}.png", outputs, surface="render", pose=name, pixels=size)
    save_png(proof_board(app_master, adaptive, monochrome, poses["hero_pointing"]), RENDERS / "luma-facefront-production-proof-board.png", outputs, surface="proof")

    manifest = {
        "schemaVersion": 1,
        "sourceDate": "2026-07-17",
        "identity": IDENTITY_RECORD,
        "inputs": inputs,
        "lockedCrops": {
            "icon": list(ICON_CROP),
            "mascot": {name: list(bounds) for name, bounds in MASCOT_CROPS.items()},
        },
        "safeZone": {
            "canvas": CANVAS,
            "radius": ADAPTIVE_SAFE_RADIUS,
            "foreground": alpha_metrics(adaptive),
            "monochrome": alpha_metrics(monochrome),
        },
        "outputs": outputs,
    }
    manifest_path = PRODUCTION / "identity-source-manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    manifest["manifest"] = {"file": rel(manifest_path), "bytes": manifest_path.stat().st_size, "sha256": sha256(manifest_path)}
    return manifest, {"app_master": app_master, "foreground": icon_foreground, "adaptive": adaptive, "monochrome": monochrome, "tinted": tinted, **{f"pose:{name}": image for name, image in poses.items()}}


def parse_apple_catalog(path: Path, *, macos: bool) -> list[tuple[str, int]]:
    catalog = json.loads(path.read_text(encoding="utf-8"))
    targets: list[tuple[str, int]] = []
    seen: set[str] = set()
    for item in catalog.get("images", []):
        filename = item.get("filename")
        if not filename or filename in seen:
            continue
        if macos:
            match = re.search(r"(\d+)", filename)
            if not match:
                raise RuntimeError(f"Cannot determine macOS icon pixels from {filename}")
            pixels = int(match.group(1))
        else:
            pixels = round(float(item["size"].split("x")[0]) * float(item["scale"].replace("x", "")))
        targets.append((filename, pixels))
        seen.add(filename)
    return targets


def build_ico(images: list[tuple[int, bytes]]) -> bytes:
    header = struct.pack("<HHH", 0, 1, len(images))
    entries = bytearray()
    offset = 6 + len(images) * 16
    body = bytearray()
    for size, data in images:
        entries.extend(struct.pack("<BBBBHHII", 0 if size >= 256 else size, 0 if size >= 256 else size, 0, 0, 1, 32, len(data), offset))
        body.extend(data)
        offset += len(data)
    return header + bytes(entries) + bytes(body)


def install_or_package(image: Image.Image, package: Path, install_target: Path | None, outputs: list[dict[str, object]], *, metadata: dict[str, object]) -> None:
    save_png(image, package, outputs, **metadata)
    if install_target is not None:
        save_png(image, install_target, outputs, **{**metadata, "platform": f"{metadata['platform']}-install"})


def export_platforms(source: dict[str, Image.Image], *, install: bool) -> dict[str, object]:
    PLATFORMS.mkdir(parents=True, exist_ok=True)
    outputs: list[dict[str, object]] = []
    app_master = source["app_master"]
    foreground = source["foreground"]
    adaptive = source["adaptive"]
    monochrome = source["monochrome"]
    tinted = source["tinted"]
    poses = {name: source[f"pose:{name}"] for name in MASCOT_CROPS}
    source_files = [
        SOURCE / "luma-facefront-app-icon-master-1024.png",
        SOURCE / "luma-facefront-foreground-1024.png",
        SOURCE / "luma-facefront-adaptive-foreground-1024.png",
        SOURCE / "luma-facefront-monochrome-foreground-1024.png",
        SOURCE / "luma-facefront-tinted-master-1024.png",
        *(SOURCE / f"luma-{name.replace('_', '-')}-1024.png" for name in MASCOT_CROPS),
    ]

    default_field = midnight_field(CANVAS)
    dark_master = composite(midnight_field(CANVAS, variant="dark"), foreground)
    maskable = composite(default_field, adaptive)
    apple = PLATFORMS / "apple"
    for name, image, role in (
        ("synapse-default-1024.png", app_master, "default-source"),
        ("synapse-dark-1024.png", dark_master, "dark-source-unwired"),
        ("synapse-tinted-1024.png", tinted, "tinted-source-unwired"),
    ):
        save_png(image, apple / "sources" / name, outputs, platform="apple", role=role, identity="ICR2-01")
    for platform, catalog, macos in (
        ("ios", APP / "ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json", False),
        ("macos", APP / "macos/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json", True),
    ):
        target_dir = apple / platform / "AppIcon.appiconset"
        contents = catalog.read_bytes()
        save_bytes(contents, target_dir / "Contents.json", outputs, platform=platform, role="catalog", identity="ICR2-01")
        installed_dir = catalog.parent
        for filename, pixels in parse_apple_catalog(catalog, macos=macos):
            icon = app_master.resize((pixels, pixels), RESAMPLING.LANCZOS)
            save_png(icon, target_dir / filename, outputs, platform=platform, role="app-icon", pixels=pixels, identity="ICR2-01")
            if install:
                save_png(icon, installed_dir / filename, outputs, platform=f"{platform}-install", role="app-icon", pixels=pixels, identity="ICR2-01")

    android = PLATFORMS / "android/res"
    densities = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
    foreground_sizes = {"mdpi": 108, "hdpi": 162, "xhdpi": 216, "xxhdpi": 324, "xxxhdpi": 432}
    for density, pixels in densities.items():
        legacy = app_master.resize((pixels, pixels), RESAMPLING.LANCZOS)
        round_icon = mask_preview(legacy, "circle", pixels)
        fg = adaptive.resize((foreground_sizes[density], foreground_sizes[density]), RESAMPLING.LANCZOS)
        mono = monochrome.resize((foreground_sizes[density], foreground_sizes[density]), RESAMPLING.LANCZOS)
        for filename, image, role in (
            ("ic_launcher.png", legacy, "legacy"),
            ("ic_launcher_round.png", round_icon, "legacy-round"),
            ("ic_launcher_foreground.png", fg, "adaptive-foreground"),
            ("ic_launcher_monochrome.png", mono, "themed-monochrome"),
        ):
            package = android / f"mipmap-{density}" / filename
            installed = APP / "android/app/src/main/res" / f"mipmap-{density}" / filename if install else None
            install_or_package(image, package, installed, outputs, metadata={"platform": "android", "role": role, "density": density, "identity": "ICR2-01"})
    adaptive_xml = '<?xml version="1.0" encoding="utf-8"?>\n<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n    <background android:drawable="@color/synapse_launcher_background" />\n    <foreground android:drawable="@mipmap/ic_launcher_foreground" />\n</adaptive-icon>\n'
    themed_xml = '<?xml version="1.0" encoding="utf-8"?>\n<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n    <background android:drawable="@color/synapse_launcher_background" />\n    <foreground android:drawable="@mipmap/ic_launcher_foreground" />\n    <monochrome android:drawable="@mipmap/ic_launcher_monochrome" />\n</adaptive-icon>\n'
    for qualifier, xml in (("mipmap-anydpi-v26", adaptive_xml), ("mipmap-anydpi-v33", themed_xml)):
        for filename in ("ic_launcher.xml", "ic_launcher_round.xml"):
            package = android / qualifier / filename
            save_bytes(xml.encode("utf-8"), package, outputs, platform="android", role=qualifier, identity="ICR2-01")
            if install:
                save_bytes(xml.encode("utf-8"), APP / "android/app/src/main/res" / qualifier / filename, outputs, platform="android-install", role=qualifier, identity="ICR2-01")
    color_xml = '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n    <color name="synapse_launcher_background">#07182D</color>\n</resources>\n'.encode("utf-8")
    save_bytes(color_xml, android / "values/synapse_launcher_colors.xml", outputs, platform="android", role="launcher-color", identity="ICR2-01")
    if install:
        save_bytes(color_xml, APP / "android/app/src/main/res/values/synapse_launcher_colors.xml", outputs, platform="android-install", role="launcher-color", identity="ICR2-01")

    web = PLATFORMS / "web"
    web_files = (
        ("icons/Icon-192.png", app_master.resize((192, 192), RESAMPLING.LANCZOS), "regular"),
        ("icons/Icon-512.png", app_master.resize((512, 512), RESAMPLING.LANCZOS), "regular"),
        ("icons/Icon-maskable-192.png", maskable.resize((192, 192), RESAMPLING.LANCZOS), "maskable"),
        ("icons/Icon-maskable-512.png", maskable.resize((512, 512), RESAMPLING.LANCZOS), "maskable"),
        ("favicon-16.png", app_master.resize((16, 16), RESAMPLING.LANCZOS), "favicon"),
        ("favicon-24.png", app_master.resize((24, 24), RESAMPLING.LANCZOS), "favicon"),
        ("favicon-32.png", app_master.resize((32, 32), RESAMPLING.LANCZOS), "favicon"),
        ("favicon-48.png", app_master.resize((48, 48), RESAMPLING.LANCZOS), "favicon"),
    )
    for name, image, role in web_files:
        save_png(image, web / name, outputs, platform="web", role=role, identity="ICR2-01")
        if install and (role != "favicon" or name == "favicon-32.png"):
            installed = APP / "web" / ("favicon.png" if role == "favicon" else name)
            save_png(image, installed, outputs, platform="web-install", role=role, identity="ICR2-01")
    for kind in ("circle", "squircle", "rounded"):
        save_png(mask_preview(maskable, kind), web / "proofs" / f"{kind}-mask.png", outputs, platform="web", role="mask-proof", mask=kind, identity="ICR2-01")

    windows = PLATFORMS / "windows"
    ico_sources: list[tuple[int, bytes]] = []
    for pixels in (16, 24, 32, 48, 64, 128, 256):
        icon = app_master.resize((pixels, pixels), RESAMPLING.LANCZOS)
        data = png_bytes(icon)
        save_bytes(data, windows / f"synapse-{pixels}.png", outputs, platform="windows", role="ico-source", pixels=pixels, identity="ICR2-01")
        ico_sources.append((pixels, data))
    ico = build_ico(ico_sources)
    save_bytes(ico, windows / "app_icon.ico", outputs, platform="windows", role="multi-size-ico", sizes=[16, 24, 32, 48, 64, 128, 256], identity="ICR2-01")
    if install:
        save_bytes(ico, APP / "windows/runner/resources/app_icon.ico", outputs, platform="windows-install", role="multi-size-ico", sizes=[16, 24, 32, 48, 64, 128, 256], identity="ICR2-01")
    linux = PLATFORMS / "linux/hicolor"
    for pixels in (16, 24, 32, 48, 64, 128, 256, 512, 1024):
        save_png(app_master.resize((pixels, pixels), RESAMPLING.LANCZOS), linux / f"{pixels}x{pixels}/apps/synapse.png", outputs, platform="linux", role="hicolor", pixels=pixels, identity="ICR2-01")
    save_png(app_master, PLATFORMS / "linux/source/synapse-1024.png", outputs, platform="linux", role="raster-source", identity="ICR2-01")

    runtime = PLATFORMS / "flutter/assets/identity/luma_facefront"
    installed_runtime = APP / "assets/identity/luma_facefront"
    for pixels in (1024, 512, 256, 96, 48, 24, 16):
        image = app_master.resize((pixels, pixels), RESAMPLING.LANCZOS)
        if pixels <= 48:
            image = image.filter(ImageFilter.UnsharpMask(radius=0.7, percent=110, threshold=3))
        name = f"app_icon_{pixels}.png"
        save_png(image, runtime / name, outputs, platform="flutter", role="app-icon", pixels=pixels, identity="ICR2-01")
        if install:
            save_png(image, installed_runtime / name, outputs, platform="flutter-install", role="app-icon", pixels=pixels, identity="ICR2-01")
    for pose, image in poses.items():
        for pixels in (1024, 512, 256):
            name = f"mascot_{pose}_{pixels}.png"
            output = image if pixels == 1024 else image.resize((pixels, pixels), RESAMPLING.LANCZOS)
            save_png(output, runtime / name, outputs, platform="flutter", role="mascot-pose", pose=pose, pixels=pixels, identity="LUMA")
            if install:
                save_png(output, installed_runtime / name, outputs, platform="flutter-install", role="mascot-pose", pose=pose, pixels=pixels, identity="LUMA")
    for name, image, role in (
        ("app_icon_adaptive_foreground_1024.png", adaptive, "adaptive-foreground"),
        ("app_icon_monochrome_1024.png", monochrome, "monochrome"),
    ):
        save_png(image, runtime / name, outputs, platform="flutter", role=role, identity="ICR2-01")
        if install:
            save_png(image, installed_runtime / name, outputs, platform="flutter-install", role=role, identity="ICR2-01")

    manifest = {
        "schemaVersion": 1,
        "sourceDate": "2026-07-17",
        "selectedIdentity": IDENTITY_RECORD,
        "installedIntoFlutterProject": install,
        "inputs": [{"file": rel(path), "sha256": sha256(path)} for path in source_files],
        "safeZone": {"canvas": CANVAS, "radius": ADAPTIVE_SAFE_RADIUS, "ratio": ADAPTIVE_SAFE_RADIUS / CANVAS, "foreground": alpha_metrics(adaptive), "monochrome": alpha_metrics(monochrome)},
        "outputs": outputs,
    }
    manifest_path = PLATFORMS / "platform-manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    return {"manifest": {"file": rel(manifest_path), "bytes": manifest_path.stat().st_size, "sha256": sha256(manifest_path)}, "outputs": len(outputs), "safeZone": manifest["safeZone"]}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--install", action="store_true", help="Install the generated assets into apps/app.")
    parser.add_argument("--source-only", action="store_true", help="Build source/renders only for crop inspection.")
    parser.add_argument("--json", action="store_true", help="Print complete receipts rather than a compact summary.")
    args = parser.parse_args()
    if args.install and args.source_only:
        raise SystemExit("--install cannot be combined with --source-only")
    source_manifest, source_images = build_source()
    platform_receipt: dict[str, object] | None = None
    if not args.source_only:
        platform_receipt = export_platforms(source_images, install=args.install)
    result = {
        "status": "pass",
        "selectedIdentity": IDENTITY_RECORD,
        "sourceManifest": source_manifest["manifest"],
        "sourceOutputs": len(source_manifest["outputs"]),
        "platform": platform_receipt,
        "installed": args.install,
    }
    print(json.dumps({"source": source_manifest, "result": result} if args.json else result, indent=2))


if __name__ == "__main__":
    main()
