#!/usr/bin/env python3
"""Build selected MCR4-01 mascot and ICR4-04 app-icon raster masters.

The two user-approved boards are immutable visual specifications. This script
locks their hashes, extracts the approved character art non-destructively,
removes preview-only framing, creates platform-neutral masters, and records a
manifest. It intentionally does not regenerate or reinterpret the character.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
from collections.abc import Iterable
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[2]
TASK = ROOT / "docs/codex/2026-07-15-synapse-medical-learning-os"
IDENTITY = TASK / "assets/identity"
MASCOT_BOARD = (
    IDENTITY
    / "mascot-icon-round-4/2026-07-17_mcr4-01_user-approved.png"
)
ICON_BOARD = (
    IDENTITY
    / "app-icon-round-1/2026-07-17_icr4-04_evidence-guide_user-approved.png"
)
PRODUCTION = IDENTITY / "production/mcr4-01-evidence-guide"
SOURCE = PRODUCTION / "source"
RENDERS = PRODUCTION / "renders"

EXPECTED = {
    MASCOT_BOARD: {
        "sha256": "4370396EE1193B8CE04788AF7B25809360F0C8D924EBFD6302C604F4BB748F75",
        "size": (1568, 1003),
    },
    ICON_BOARD: {
        "sha256": "3B032C99C13E21435B7CACA293D12887629992C4AD7201158E17C98FBB6FC4D5",
        "size": (1254, 1254),
    },
}

ICON_CROP = (220, 75, 1034, 889)
MASCOT_CROPS = {
    "hero_pointing": (25, 115, 485, 640),
    "encouraging": (492, 420, 694, 660),
    "thinking": (702, 420, 895, 660),
    "evidence_guide": (890, 420, 1105, 660),
    "quest_host": (1110, 410, 1330, 660),
    "recovery": (1325, 420, 1565, 660),
}

RESAMPLING = getattr(Image, "Resampling", Image)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def verify_inputs() -> list[dict[str, object]]:
    records: list[dict[str, object]] = []
    for path, expected in EXPECTED.items():
        if not path.is_file():
            raise FileNotFoundError(f"Missing approved identity evidence: {path}")
        actual_hash = sha256(path)
        with Image.open(path) as image:
            actual_size = image.size
        if actual_hash != expected["sha256"]:
            raise RuntimeError(
                f"Approved evidence hash changed for {path}: {actual_hash}"
            )
        if actual_size != expected["size"]:
            raise RuntimeError(
                f"Approved evidence dimensions changed for {path}: {actual_size}"
            )
        records.append(
            {
                "file": path.relative_to(ROOT).as_posix(),
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
    blur_radius: float = 1.2,
    edge_clear: int = 0,
    edge_clear_luminance: float = 0,
) -> Image.Image:
    """Extract an opaque character/prop group from the Night Shift board."""
    rgb = np.asarray(crop.convert("RGB"), dtype=np.float32)
    luminance = (
        rgb[:, :, 0] * 0.2126
        + rgb[:, :, 1] * 0.7152
        + rgb[:, :, 2] * 0.0722
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
    chroma_signal = (rgb[:, :, 2] - rgb[:, :, 0]) + (
        rgb[:, :, 1] - rgb[:, :, 0]
    ) * 0.35

    seed = (luminance >= luminance_floor) | (
        (distance >= color_distance_floor)
        & (luminance >= 16)
        & (chroma_signal >= 8)
    )
    if edge_clear > 0:
        height, width = luminance.shape
        yy, xx = np.mgrid[0:height, 0:width]
        side_distance = np.minimum(xx, width - 1 - xx)
        preview_frame = (
            ((side_distance < edge_clear) | (yy < edge_clear))
            & (luminance < edge_clear_luminance)
        )
        # The approved board's squircle outline is brightest at its top corner
        # tangents. Nothing from the selected character occupies this strip.
        preview_frame |= yy < 58
        preview_frame |= side_distance < 24
        seed &= ~preview_frame
    mask = Image.fromarray((seed.astype(np.uint8) * 255), mode="L")
    close_size = max(3, close_size | 1)
    mask = mask.filter(ImageFilter.MaxFilter(close_size))
    mask = mask.filter(ImageFilter.MinFilter(close_size))
    mask = _fill_holes(mask)
    mask = mask.filter(ImageFilter.GaussianBlur(blur_radius))
    if edge_clear > 0:
        matte = np.array(mask, dtype=np.uint8, copy=True)
        matte[:64, :] = 0
        matte[:, :20] = 0
        matte[:, -20:] = 0
        matte[:112, :112] = 0
        matte[:112, -112:] = 0
        mask = Image.fromarray(matte, mode="L")

    rgba = crop.convert("RGBA")
    rgba.putalpha(mask)
    return rgba


def trim_alpha(image: Image.Image, threshold: int = 4) -> Image.Image:
    alpha = image.getchannel("A").point(lambda value: 255 if value > threshold else 0)
    bounds = alpha.getbbox()
    if bounds is None:
        raise RuntimeError("Extracted subject has no alpha coverage")
    return image.crop(bounds)


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


def midnight_background(size: int, *, frost: bool = False) -> Image.Image:
    yy, xx = np.mgrid[0:size, 0:size]
    nx = xx / max(1, size - 1)
    ny = yy / max(1, size - 1)
    distance = np.sqrt(((nx - 0.47) / 0.78) ** 2 + ((ny - 0.43) / 0.82) ** 2)
    blend = np.clip(distance, 0, 1)
    blend = blend * blend * (3 - 2 * blend)
    if frost:
        center = np.array([232, 241, 255], dtype=np.float32)
        edge = np.array([185, 211, 250], dtype=np.float32)
    else:
        center = np.array([20, 57, 105], dtype=np.float32)
        edge = np.array([3, 12, 37], dtype=np.float32)
    rgb = center[None, None, :] * (1 - blend[:, :, None]) + edge[None, None, :] * blend[
        :, :, None
    ]
    cobalt = np.exp(-(((nx - 0.38) / 0.37) ** 2 + ((ny - 0.70) / 0.32) ** 2))
    if not frost:
        rgb[:, :, 2] += cobalt * 12
        rgb[:, :, 1] += cobalt * 4
    return Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8), mode="RGB")


def composite(background: Image.Image, foreground: Image.Image) -> Image.Image:
    result = background.convert("RGBA")
    result.alpha_composite(foreground)
    return result.convert("RGB")


def monochrome_from_alpha(image: Image.Image, *, ink: bool = False) -> Image.Image:
    alpha = image.getchannel("A")
    color = (7, 24, 45, 255) if ink else (255, 255, 255, 255)
    result = Image.new("RGBA", image.size, color)
    result.putalpha(alpha)
    return result


def save_png(image: Image.Image, path: Path) -> dict[str, object]:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, format="PNG", optimize=True, compress_level=9)
    return {
        "file": path.relative_to(ROOT).as_posix(),
        "bytes": path.stat().st_size,
        "sha256": sha256(path),
        "size": list(image.size),
        "mode": image.mode,
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
    for path in candidates:
        if path.exists():
            return ImageFont.truetype(str(path), size=size)
    return ImageFont.load_default()


def proof_board(
    app_icon: Image.Image,
    adaptive: Image.Image,
    mono: Image.Image,
    mascot: Image.Image,
) -> Image.Image:
    board = midnight_background(1600)
    board = board.crop((0, 0, 1600, 1000)).convert("RGBA")
    draw = ImageDraw.Draw(board)
    title_font = _font(34)
    label_font = _font(21)
    draw.text((60, 38), "SYNAPSE SELECTED IDENTITY PRODUCTION", font=title_font, fill=(236, 244, 255))
    draw.text((60, 86), "MCR4-01 SIDE CREST COMPANION  /  ICR4-04 EVIDENCE GUIDE", font=label_font, fill=(76, 178, 255))

    hero = mascot.resize((500, 500), RESAMPLING.LANCZOS)
    board.alpha_composite(hero, (40, 170))
    icon = app_icon.resize((520, 520), RESAMPLING.LANCZOS).convert("RGBA")
    board.alpha_composite(icon, (560, 160))
    draw.text((560, 690), "UNMASKED OPAQUE MASTER", font=label_font, fill=(236, 244, 255))

    previews = [
        ("CIRCLE", mask_preview(app_icon, "circle", 210)),
        ("SQUIRCLE", mask_preview(app_icon, "squircle", 210)),
        ("ADAPTIVE FG", adaptive.resize((210, 210), RESAMPLING.LANCZOS)),
        ("MONO", mono.resize((210, 210), RESAMPLING.LANCZOS)),
    ]
    x = 60
    for label, preview in previews:
        board.alpha_composite(preview.convert("RGBA"), (x, 740))
        draw.text((x, 954), label, font=label_font, fill=(174, 204, 244))
        x += 270

    for size, x, scale in [(48, 1120, 3), (24, 1300, 5), (16, 1460, 6)]:
        tiny = app_icon.resize((size, size), RESAMPLING.LANCZOS).convert("RGBA")
        tiny = tiny.resize((size * scale, size * scale), RESAMPLING.NEAREST)
        board.alpha_composite(tiny, (x, 770))
        draw.text((x, 954), f"{size} PX", font=label_font, fill=(174, 204, 244))
    return board.convert("RGB")


def build() -> dict[str, object]:
    inputs = verify_inputs()
    SOURCE.mkdir(parents=True, exist_ok=True)
    RENDERS.mkdir(parents=True, exist_ok=True)
    outputs: list[dict[str, object]] = []

    icon_board = Image.open(ICON_BOARD).convert("RGB")
    icon_crop = icon_board.crop(ICON_CROP).resize((1024, 1024), RESAMPLING.LANCZOS)
    icon_foreground = extract_subject(
        icon_crop,
        luminance_floor=74,
        color_distance_floor=999,
        close_size=9,
        blur_radius=1.35,
        edge_clear=64,
        edge_clear_luminance=132,
    )
    # Preserve the approved framing for the universal master, but replace the
    # generated board's baked squircle and border with a full opaque field.
    app_icon_master = composite(midnight_background(1024), icon_foreground)
    adaptive_foreground = contain_on_canvas(
        icon_foreground,
        1024,
        max_width=480,
        max_height=480,
        y_offset=-4,
    )
    mono_foreground = monochrome_from_alpha(adaptive_foreground)
    tinted_master = composite(midnight_background(1024, frost=True), monochrome_from_alpha(adaptive_foreground, ink=True))

    outputs.extend(
        [
            save_png(icon_crop, SOURCE / "icr4-04-approved-preview-crop-1024.png"),
            save_png(icon_foreground, SOURCE / "icr4-04-foreground-1024.png"),
            save_png(app_icon_master, SOURCE / "icr4-04-app-icon-master-1024.png"),
            save_png(adaptive_foreground, SOURCE / "icr4-04-adaptive-foreground-1024.png"),
            save_png(mono_foreground, SOURCE / "icr4-04-monochrome-foreground-1024.png"),
            save_png(tinted_master, SOURCE / "icr4-04-tinted-master-1024.png"),
        ]
    )

    mascot_board = Image.open(MASCOT_BOARD).convert("RGB")
    mascot_sources: dict[str, Image.Image] = {}
    for name, bounds in MASCOT_CROPS.items():
        crop = mascot_board.crop(bounds)
        extracted = extract_subject(
            crop,
            luminance_floor=44 if name == "recovery" else 58,
            color_distance_floor=28 if name == "recovery" else 34,
            close_size=7,
            blur_radius=1.15,
        )
        canvas = contain_on_canvas(
            extracted,
            1024,
            max_width=900 if name == "hero_pointing" else 820,
            max_height=900 if name == "hero_pointing" else 820,
            y_offset=16,
        )
        mascot_sources[name] = canvas
        outputs.append(save_png(canvas, SOURCE / f"mcr4-01-{name.replace('_', '-')}-1024.png"))

    for size in (512, 256, 128, 96, 64, 48, 32, 24, 16):
        resized = app_icon_master.resize((size, size), RESAMPLING.LANCZOS)
        if size <= 48:
            resized = resized.filter(ImageFilter.UnsharpMask(radius=0.7, percent=115, threshold=3))
        outputs.append(save_png(resized, RENDERS / f"icr4-04-app-icon-{size}.png"))

    for kind in ("circle", "squircle", "rounded"):
        outputs.append(save_png(mask_preview(app_icon_master, kind), RENDERS / f"icr4-04-{kind}-proof-512.png"))

    for name, image in mascot_sources.items():
        for size in (512, 256):
            outputs.append(
                save_png(
                    image.resize((size, size), RESAMPLING.LANCZOS),
                    RENDERS / f"mcr4-01-{name.replace('_', '-')}-{size}.png",
                )
            )

    outputs.append(
        save_png(
            proof_board(
                app_icon_master,
                adaptive_foreground,
                mono_foreground,
                mascot_sources["hero_pointing"],
            ),
            RENDERS / "mcr4-01-icr4-04-production-proof-board.png",
        )
    )

    manifest = {
        "schemaVersion": 1,
        "sourceDate": "2026-07-17",
        "identity": {
            "mascot": "MCR4-01 Sidecrest Companion",
            "appIcon": "ICR4-04 Evidence Guide",
            "publicCharacterName": None,
        },
        "inputs": inputs,
        "lockedCrops": {
            "icon": list(ICON_CROP),
            "mascot": {key: list(value) for key, value in MASCOT_CROPS.items()},
        },
        "outputs": outputs,
    }
    manifest_path = PRODUCTION / "identity-source-manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    manifest["manifest"] = {
        "file": manifest_path.relative_to(ROOT).as_posix(),
        "bytes": manifest_path.stat().st_size,
        "sha256": sha256(manifest_path),
    }
    return manifest


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--json", action="store_true", help="Print the complete manifest summary")
    args = parser.parse_args()
    manifest = build()
    result = {
        "status": "pass",
        "mascot": manifest["identity"]["mascot"],
        "appIcon": manifest["identity"]["appIcon"],
        "outputs": len(manifest["outputs"]),
        "manifest": manifest["manifest"],
    }
    print(json.dumps(manifest if args.json else result, indent=2))


if __name__ == "__main__":
    main()
