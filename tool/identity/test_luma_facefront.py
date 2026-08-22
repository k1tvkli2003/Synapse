#!/usr/bin/env python3
"""Verify the restored LUMA Facefront source and six-platform package."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import struct
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[2]
PRODUCTION = ROOT / "docs/codex/2026-07-15-synapse-medical-learning-os/assets/identity/production/luma-facefront-restored"
SOURCE = PRODUCTION / "source"
RENDERS = PRODUCTION / "renders"
PLATFORMS = PRODUCTION / "platforms"
APP = ROOT / "apps/app"
RUNTIME_IDENTITY = APP / "lib/brand/synapse_identity.dart"
FLUTTER_PUBSPEC = APP / "pubspec.yaml"
SOURCE_MANIFEST = PRODUCTION / "identity-source-manifest.json"
PLATFORM_MANIFEST = PLATFORMS / "platform-manifest.json"
EXPECTED_IDENTITY = {
    "mascot": "LUMA Character System",
    "appIcon": "ICR2-01 LUMA Facefront",
    "conceptId": "ICR2-01",
    "status": "restored-by-latest-direct-user-decision",
}
EXPECTED_INPUTS = {
    "docs/codex/2026-07-15-synapse-medical-learning-os/assets/identity/icons-round-2/2026-07-16_icr2-01_luma-facefront_concept.png": "352FC04100F77A4203115BAE9DD090D8D0116AEDC541466DFB3656D33727FD19",
    "docs/codex/2026-07-15-synapse-medical-learning-os/assets/previews/2026-07-15_refine-01_luma-character-system.png": "939F98A302D269A03CBFC08995D7A62A5E4939896FDE212D8D56AA63CA99CD94",
}
SAFE_RADIUS = 304.0


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def image_metrics(path: Path) -> dict[str, object]:
    rgba = np.asarray(Image.open(path).convert("RGBA"), dtype=np.uint8)
    alpha = rgba[:, :, 3]
    ys, xs = np.where(alpha > 64)
    if not len(xs):
        raise AssertionError(f"{path.name}: empty alpha mask")
    cx = (rgba.shape[1] - 1) / 2
    cy = (rgba.shape[0] - 1) / 2
    return {
        "width": int(rgba.shape[1]),
        "height": int(rgba.shape[0]),
        "bounds": [int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())],
        "maxRadius": round(float(np.sqrt((xs - cx) ** 2 + (ys - cy) ** 2).max()), 3),
        "borderPixels": int((alpha[0, :] > 64).sum() + (alpha[-1, :] > 64).sum() + (alpha[:, 0] > 64).sum() + (alpha[:, -1] > 64).sum()),
        "opaque": bool(np.all(alpha == 255)),
        "cornerAlpha": [int(alpha[0, 0]), int(alpha[0, -1]), int(alpha[-1, 0]), int(alpha[-1, -1])],
    }


def component_count(path: Path, size: int = 256) -> int:
    alpha = Image.open(path).convert("RGBA").getchannel("A").resize((size, size))
    mask = alpha.point(lambda value: 255 if value > 64 else 0)
    count = 0
    while mask.getbbox() is not None:
        points = np.argwhere(np.asarray(mask, dtype=np.uint8) == 255)
        if not len(points):
            break
        y, x = points[0]
        ImageDraw.floodfill(mask, (int(x), int(y)), 0, thresh=0)
        count += 1
        if count > 20:
            break
    return count


def signal(path: Path) -> dict[str, int | float]:
    rgb = np.asarray(Image.open(path).convert("RGB"), dtype=np.uint8)
    luminance = rgb[:, :, 0].astype(np.float32) * 0.2126 + rgb[:, :, 1].astype(np.float32) * 0.7152 + rgb[:, :, 2].astype(np.float32) * 0.0722
    cyan = (rgb[:, :, 2] > 100) & (rgb[:, :, 1] > 70) & (rgb[:, :, 2].astype(np.int16) - rgb[:, :, 0].astype(np.int16) > 35)
    dark = luminance < 50
    return {"meanLuminance": round(float(luminance.mean()), 3), "cyanPixels": int(cyan.sum()), "darkPixels": int(dark.sum())}


def inspect_ico(path: Path) -> dict[str, object]:
    data = path.read_bytes()
    if len(data) < 6:
        raise AssertionError("ICO is too short")
    reserved, kind, count = struct.unpack_from("<HHH", data, 0)
    if reserved != 0 or kind != 1:
        raise AssertionError("invalid ICO header")
    sizes: list[int] = []
    for index in range(count):
        width, height = struct.unpack_from("<BB", data, 6 + index * 16)
        width = 256 if width == 0 else width
        height = 256 if height == 0 else height
        if width != height:
            raise AssertionError("ICO entry is not square")
        sizes.append(width)
    return {"entries": count, "sizes": sizes}


def manifest_integrity(manifest: dict[str, object], failures: list[str]) -> None:
    for output in manifest.get("outputs", []):
        path = ROOT / output["file"]
        if not path.is_file():
            failures.append(f"missing manifest output: {output['file']}")
            continue
        if path.stat().st_size != output["bytes"]:
            failures.append(f"byte mismatch: {output['file']}")
        if sha256(path) != output["sha256"]:
            failures.append(f"hash mismatch: {output['file']}")


def write_report(path: Path, report: dict[str, object]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")


def verify_source() -> dict[str, object]:
    failures: list[str] = []
    if not SOURCE_MANIFEST.is_file():
        failures.append("missing source manifest")
        manifest: dict[str, object] = {"outputs": []}
    else:
        manifest = json.loads(SOURCE_MANIFEST.read_text(encoding="utf-8"))
    if manifest.get("identity") != EXPECTED_IDENTITY:
        failures.append("source manifest does not bind the restored LUMA identity")
    inputs = {entry["file"]: entry["sha256"] for entry in manifest.get("inputs", [])}
    if inputs != EXPECTED_INPUTS:
        failures.append("selected evidence hashes do not match the approved LUMA boards")
    manifest_integrity(manifest, failures)

    app_master = SOURCE / "luma-facefront-app-icon-master-1024.png"
    foreground = SOURCE / "luma-facefront-foreground-1024.png"
    adaptive = SOURCE / "luma-facefront-adaptive-foreground-1024.png"
    monochrome = SOURCE / "luma-facefront-monochrome-foreground-1024.png"
    required = [app_master, foreground, adaptive, monochrome]
    required += [SOURCE / f"luma-{pose.replace('_', '-')}-1024.png" for pose in ("hero_pointing", "encouraging", "thinking", "evidence_guide", "quest_host", "recovery")]
    for path in required:
        if not path.is_file():
            failures.append(f"missing LUMA source asset: {path.name}")

    app = image_metrics(app_master)
    if app["width"] != 1024 or app["height"] != 1024 or not app["opaque"]:
        failures.append("launcher master must be opaque 1024x1024")
    adaptive_metrics = image_metrics(adaptive)
    mono_metrics = image_metrics(monochrome)
    if adaptive_metrics["maxRadius"] > SAFE_RADIUS:
        failures.append(f"adaptive foreground exceeds safe radius: {adaptive_metrics['maxRadius']}")
    if mono_metrics["maxRadius"] > SAFE_RADIUS:
        failures.append(f"monochrome foreground exceeds safe radius: {mono_metrics['maxRadius']}")
    if any(adaptive_metrics["cornerAlpha"]) or any(mono_metrics["cornerAlpha"]):
        failures.append("adaptive or monochrome foreground touches a corner")
    components = component_count(monochrome)
    if components != 1:
        failures.append(f"monochrome foreground has {components} components, expected 1")

    optical: dict[str, object] = {}
    for pixels in (48, 24, 16):
        path = RENDERS / f"luma-facefront-app-icon-{pixels}.png"
        metrics = image_metrics(path)
        optical[str(pixels)] = {**metrics, **signal(path)}
        if metrics["width"] != pixels or metrics["height"] != pixels:
            failures.append(f"optical icon has wrong size: {pixels}")
        if optical[str(pixels)]["darkPixels"] < (5 if pixels == 16 else 15):
            failures.append(f"optical icon lost facial dark detail at {pixels}px")
        if optical[str(pixels)]["cyanPixels"] < 1:
            failures.append(f"optical icon lost cyan fold cue at {pixels}px")

    poses: dict[str, object] = {}
    for path in required[4:]:
        metrics = image_metrics(path)
        poses[path.name] = metrics
        if any(metrics["cornerAlpha"]):
            failures.append(f"mascot pose is clipped at canvas corner: {path.name}")
    report = {
        "status": "pass" if not failures else "fail",
        "selectedIdentity": manifest.get("identity"),
        "appMaster": app,
        "adaptive": adaptive_metrics,
        "monochrome": {**mono_metrics, "components": components},
        "optical": optical,
        "poses": poses,
        "failures": failures,
    }
    write_report(PRODUCTION / "identity-source-verification.json", report)
    return report


def verify_platform(require_install: bool) -> dict[str, object]:
    failures: list[str] = []
    if not PLATFORM_MANIFEST.is_file():
        return {"status": "fail", "failures": ["missing platform manifest"]}
    manifest = json.loads(PLATFORM_MANIFEST.read_text(encoding="utf-8"))
    if manifest.get("selectedIdentity") != EXPECTED_IDENTITY:
        failures.append("platform manifest does not bind the restored LUMA identity")
    outputs = manifest.get("outputs", [])
    if len(outputs) < 150:
        failures.append(f"expected at least 150 platform outputs, found {len(outputs)}")
    manifest_integrity(manifest, failures)
    safe = manifest.get("safeZone", {})
    for key in ("foreground", "monochrome"):
        if float(safe.get(key, {}).get("maxRadius", math.inf)) > float(safe.get("radius", 0)):
            failures.append(f"{key} exceeds declared adaptive safe zone")

    checks: dict[str, object] = {}
    apple = PLATFORMS / "apple/sources/synapse-default-1024.png"
    checks["appleDefault"] = image_metrics(apple)
    if not checks["appleDefault"]["opaque"]:
        failures.append("Apple source is not opaque")
    adaptive = PLATFORMS / "android/res/mipmap-xxxhdpi/ic_launcher_foreground.png"
    checks["androidAdaptive"] = image_metrics(adaptive)
    allowed_radius = math.ceil(432 * SAFE_RADIUS / 1024) + 1
    if checks["androidAdaptive"]["maxRadius"] > allowed_radius:
        failures.append("Android adaptive foreground exceeds scaled safe zone")
    if checks["androidAdaptive"]["borderPixels"]:
        failures.append("Android adaptive foreground touches layer boundary")
    checks["webMaskable"] = image_metrics(PLATFORMS / "web/icons/Icon-maskable-512.png")
    if not checks["webMaskable"]["opaque"]:
        failures.append("PWA maskable icon is not opaque")
    checks["windowsIco"] = inspect_ico(PLATFORMS / "windows/app_icon.ico")
    if checks["windowsIco"]["sizes"] != [16, 24, 32, 48, 64, 128, 256]:
        failures.append("Windows ICO ladder is incomplete")
    checks["linux512"] = image_metrics(PLATFORMS / "linux/hicolor/512x512/apps/synapse.png")
    runtime_icon = PLATFORMS / "flutter/assets/identity/luma_facefront/app_icon_1024.png"
    checks["flutterIcon"] = image_metrics(runtime_icon)
    pose_outputs = [entry for entry in outputs if entry.get("platform") == "flutter" and entry.get("role") == "mascot-pose"]
    if len(pose_outputs) != 18:
        failures.append(f"expected 18 Flutter pose assets, found {len(pose_outputs)}")

    if require_install:
        if not manifest.get("installedIntoFlutterProject"):
            failures.append("platform manifest does not record an install run")
        pairs = (
            (PLATFORMS / "windows/app_icon.ico", APP / "windows/runner/resources/app_icon.ico"),
            (PLATFORMS / "web/icons/Icon-512.png", APP / "web/icons/Icon-512.png"),
            (PLATFORMS / "web/icons/Icon-maskable-512.png", APP / "web/icons/Icon-maskable-512.png"),
            (PLATFORMS / "android/res/mipmap-xxxhdpi/ic_launcher_foreground.png", APP / "android/app/src/main/res/mipmap-xxxhdpi/ic_launcher_foreground.png"),
            (PLATFORMS / "apple/ios/AppIcon.appiconset/Icon-App-1024x1024@1x.png", APP / "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png"),
            (PLATFORMS / "apple/macos/AppIcon.appiconset/app_icon_1024.png", APP / "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png"),
            (PLATFORMS / "flutter/assets/identity/luma_facefront/app_icon_1024.png", APP / "assets/identity/luma_facefront/app_icon_1024.png"),
            (PLATFORMS / "flutter/assets/identity/luma_facefront/mascot_hero_pointing_1024.png", APP / "assets/identity/luma_facefront/mascot_hero_pointing_1024.png"),
        )
        for package, installed in pairs:
            if not installed.is_file():
                failures.append(f"missing installed LUMA asset: {installed.relative_to(ROOT)}")
            elif sha256(package) != sha256(installed):
                failures.append(f"installed asset differs: {installed.relative_to(ROOT)}")
        pubspec = FLUTTER_PUBSPEC.read_text(encoding="utf-8")
        if "assets/identity/luma_facefront/" not in pubspec:
            failures.append("Flutter pubspec does not declare restored LUMA runtime assets")
        if "assets/identity/mcr4_companion/" in pubspec:
            failures.append("Flutter pubspec still declares the superseded MCR4 runtime assets")

        runtime_identity = RUNTIME_IDENTITY.read_text(encoding="utf-8")
        if "assets/identity/luma_facefront" not in runtime_identity:
            failures.append("Flutter identity API does not point to restored LUMA runtime assets")
        if "assets/identity/mcr4_companion" in runtime_identity:
            failures.append("Flutter identity API still points to superseded MCR4 runtime assets")

    report = {
        "status": "pass" if not failures else "fail",
        "requireInstall": require_install,
        "selectedIdentity": manifest.get("selectedIdentity"),
        "manifestOutputs": len(outputs),
        "safeZone": safe,
        "checks": checks,
        "failures": failures,
    }
    write_report(PLATFORMS / "platform-verification.json", report)
    return report


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--require-install", action="store_true")
    args = parser.parse_args()
    source = verify_source()
    platform = verify_platform(args.require_install) if PLATFORM_MANIFEST.is_file() else {"status": "skipped", "reason": "platform package not built"}
    status = "pass" if source["status"] == "pass" and platform["status"] in {"pass", "skipped"} else "fail"
    result = {"status": status, "source": source, "platform": platform}
    print(json.dumps(result, indent=2))
    if status != "pass":
        sys.exit(1)


if __name__ == "__main__":
    main()
