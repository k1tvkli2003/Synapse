#!/usr/bin/env python3
"""Verify selected MCR4-01 / ICR4-04 source and optical assets."""

from __future__ import annotations

import hashlib
import json
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[2]
PRODUCTION = (
    ROOT
    / "docs/codex/2026-07-15-synapse-medical-learning-os/assets/identity/production/mcr4-01-evidence-guide"
)
SOURCE = PRODUCTION / "source"
RENDERS = PRODUCTION / "renders"
MANIFEST = PRODUCTION / "identity-source-manifest.json"
VERIFICATION = PRODUCTION / "identity-source-verification.json"
SAFE_RADIUS = 304.0


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def alpha_metrics(path: Path) -> dict[str, object]:
    with Image.open(path) as image:
        rgba = np.asarray(image.convert("RGBA"), dtype=np.uint8)
    alpha = rgba[:, :, 3]
    ys, xs = np.where(alpha > 64)
    if not len(xs):
        return {"bounds": None, "pixels": 0, "maxRadius": None}
    cx = (rgba.shape[1] - 1) / 2
    cy = (rgba.shape[0] - 1) / 2
    radius = np.sqrt((xs - cx) ** 2 + (ys - cy) ** 2).max()
    return {
        "bounds": [int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())],
        "pixels": int(len(xs)),
        "maxRadius": round(float(radius), 3),
        "cornerAlpha": [
            int(alpha[0, 0]),
            int(alpha[0, -1]),
            int(alpha[-1, 0]),
            int(alpha[-1, -1]),
        ],
    }


def component_count(path: Path, size: int = 256) -> int:
    with Image.open(path) as image:
        alpha = image.convert("RGBA").getchannel("A").resize((size, size))
    mask = alpha.point(lambda value: 255 if value > 64 else 0)
    count = 0
    while mask.getbbox() is not None:
        values = np.asarray(mask, dtype=np.uint8)
        points = np.argwhere(values == 255)
        if not len(points):
            break
        y, x = points[0]
        ImageDraw.floodfill(mask, (int(x), int(y)), 0, thresh=0)
        count += 1
        if count > 20:
            break
    return count


def image_signal(path: Path) -> dict[str, object]:
    with Image.open(path) as image:
        rgb = np.asarray(image.convert("RGB"), dtype=np.uint8)
    luminance = (
        rgb[:, :, 0].astype(np.float32) * 0.2126
        + rgb[:, :, 1].astype(np.float32) * 0.7152
        + rgb[:, :, 2].astype(np.float32) * 0.0722
    )
    cyan = (
        (rgb[:, :, 2] > 105)
        & (rgb[:, :, 1] > 70)
        & (rgb[:, :, 2].astype(np.int16) - rgb[:, :, 0].astype(np.int16) > 35)
    )
    dark_detail = luminance < 45
    return {
        "meanLuminance": round(float(luminance.mean()), 3),
        "cyanPixels": int(cyan.sum()),
        "darkDetailPixels": int(dark_detail.sum()),
    }


def verify() -> dict[str, object]:
    failures: list[str] = []
    if not MANIFEST.is_file():
        failures.append("missing identity-source-manifest.json")
        manifest = {"outputs": []}
    else:
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))

    for output in manifest.get("outputs", []):
        path = ROOT / output["file"]
        if not path.is_file():
            failures.append(f"missing manifest output: {output['file']}")
            continue
        if path.stat().st_size != output["bytes"]:
            failures.append(f"byte mismatch: {output['file']}")
        if sha256(path) != output["sha256"]:
            failures.append(f"hash mismatch: {output['file']}")

    app_master = SOURCE / "icr4-04-app-icon-master-1024.png"
    foreground = SOURCE / "icr4-04-foreground-1024.png"
    adaptive = SOURCE / "icr4-04-adaptive-foreground-1024.png"
    monochrome = SOURCE / "icr4-04-monochrome-foreground-1024.png"
    required = [app_master, foreground, adaptive, monochrome]
    required.extend(SOURCE.glob("mcr4-01-*-1024.png"))
    for path in required:
        if not path.is_file():
            failures.append(f"missing required source: {path.name}")

    with Image.open(app_master) as image:
        if image.size != (1024, 1024):
            failures.append(f"app master size is {image.size}")
        if image.mode not in {"RGB", "RGBA"}:
            failures.append(f"app master mode is {image.mode}")
        rgba = np.asarray(image.convert("RGBA"), dtype=np.uint8)
        if int(rgba[:, :, 3].min()) != 255:
            failures.append("app master is not fully opaque")
        for label, corner in {
            "top-left": rgba[:112, :112, :3],
            "top-right": rgba[:112, -112:, :3],
        }.items():
            lum = (
                corner[:, :, 0].astype(np.float32) * 0.2126
                + corner[:, :, 1].astype(np.float32) * 0.7152
                + corner[:, :, 2].astype(np.float32) * 0.0722
            )
            if float(lum.max()) > 48:
                failures.append(f"preview-frame residue in {label}: max luminance {lum.max():.2f}")

    adaptive_metrics = alpha_metrics(adaptive)
    mono_metrics = alpha_metrics(monochrome)
    if adaptive_metrics["maxRadius"] is None or adaptive_metrics["maxRadius"] > SAFE_RADIUS:
        failures.append(
            f"adaptive foreground radius {adaptive_metrics['maxRadius']} exceeds {SAFE_RADIUS}"
        )
    if mono_metrics["maxRadius"] is None or mono_metrics["maxRadius"] > SAFE_RADIUS:
        failures.append(
            f"monochrome foreground radius {mono_metrics['maxRadius']} exceeds {SAFE_RADIUS}"
        )
    if any(adaptive_metrics.get("cornerAlpha", [])):
        failures.append("adaptive foreground has opaque corners")
    components = component_count(monochrome)
    if components != 1:
        failures.append(f"monochrome foreground has {components} components, expected 1")

    optical: dict[str, object] = {}
    for size in (48, 24, 16):
        path = RENDERS / f"icr4-04-app-icon-{size}.png"
        with Image.open(path) as image:
            if image.size != (size, size):
                failures.append(f"optical {size} size is {image.size}")
        signal = image_signal(path)
        optical[str(size)] = signal
        minimum_dark = 8 if size == 16 else 20
        minimum_cyan = 1 if size == 16 else 3
        if signal["darkDetailPixels"] < minimum_dark:
            failures.append(f"optical {size} lost face/card dark detail")
        if signal["cyanPixels"] < minimum_cyan:
            failures.append(f"optical {size} lost cyan crest/evidence cue")

    mascot_metrics: dict[str, object] = {}
    for path in sorted(SOURCE.glob("mcr4-01-*-1024.png")):
        metrics = alpha_metrics(path)
        mascot_metrics[path.name] = metrics
        if metrics["bounds"] is None:
            failures.append(f"empty mascot asset: {path.name}")
        if any(metrics.get("cornerAlpha", [])):
            failures.append(f"clipped mascot corner: {path.name}")

    result = {
        "status": "pass" if not failures else "fail",
        "failures": failures,
        "appMaster": {
            "file": app_master.relative_to(ROOT).as_posix(),
            "sha256": sha256(app_master) if app_master.is_file() else None,
        },
        "foreground": alpha_metrics(foreground) if foreground.is_file() else None,
        "adaptive": adaptive_metrics,
        "monochrome": {**mono_metrics, "components": components},
        "optical": optical,
        "mascot": mascot_metrics,
    }
    VERIFICATION.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    return result


def main() -> None:
    result = verify()
    print(json.dumps(result, indent=2))
    if result["status"] != "pass":
        sys.exit(1)


if __name__ == "__main__":
    main()
