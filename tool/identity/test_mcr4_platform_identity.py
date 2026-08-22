from __future__ import annotations

import argparse
import hashlib
import json
import math
import struct
from pathlib import Path

import numpy as np
from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
PLATFORM_DIR = (
    ROOT
    / "docs/codex/2026-07-15-synapse-medical-learning-os/assets/identity/production/mcr4-01-evidence-guide/platforms"
)
MANIFEST = PLATFORM_DIR / "platform-manifest.json"
APP = ROOT / "apps/app"


def sha256(file: Path) -> str:
    return hashlib.sha256(file.read_bytes()).hexdigest().upper()


def image_metrics(file: Path) -> dict[str, int | float | list[int] | bool]:
    rgba = np.asarray(Image.open(file).convert("RGBA"), dtype=np.uint8)
    alpha = rgba[:, :, 3]
    mask = alpha > 64
    ys, xs = np.where(mask)
    if len(xs) == 0:
        raise AssertionError(f"{file.name}: empty alpha mask")
    cx = (rgba.shape[1] - 1) / 2
    cy = (rgba.shape[0] - 1) / 2
    radius = np.sqrt((xs - cx) ** 2 + (ys - cy) ** 2).max()
    border = int(
        mask[0, :].sum()
        + mask[-1, :].sum()
        + mask[:, 0].sum()
        + mask[:, -1].sum()
    )
    return {
        "width": int(rgba.shape[1]),
        "height": int(rgba.shape[0]),
        "bounds": [int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())],
        "maxRadius": round(float(radius), 3),
        "borderPixels": border,
        "opaque": bool(np.all(alpha == 255)),
    }


def inspect_ico(file: Path) -> dict[str, int | list[int]]:
    data = file.read_bytes()
    reserved, kind, count = struct.unpack_from("<HHH", data, 0)
    if reserved != 0 or kind != 1:
        raise AssertionError("invalid ICO header")
    sizes: list[int] = []
    for index in range(count):
        width, height = struct.unpack_from("<BB", data, 6 + index * 16)
        size = 256 if width == 0 else width
        sizes.append(size)
        if (256 if height == 0 else height) != size:
            raise AssertionError("non-square ICO entry")
    return {"entries": count, "sizes": sizes}


def compare_installed(package: Path, installed: Path, failures: list[str]) -> None:
    if not installed.exists():
        failures.append(f"missing installed asset: {installed.relative_to(ROOT)}")
    elif sha256(package) != sha256(installed):
        failures.append(f"installed asset differs: {installed.relative_to(ROOT)}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--require-install", action="store_true")
    args = parser.parse_args()

    failures: list[str] = []
    if not MANIFEST.exists():
        raise SystemExit(f"missing {MANIFEST}")
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    if manifest.get("selectedIdentity") != {
        "mascot": "MCR4-01 Sidecrest Companion",
        "appIcon": "ICR4-04 Evidence Guide",
    }:
        failures.append("platform manifest does not identify the selected identity")
    entries = manifest.get("outputs", [])
    if len(entries) < 100:
        failures.append(f"expected at least 100 outputs, found {len(entries)}")

    seen: set[str] = set()
    for entry in entries:
        relative = entry["file"]
        if relative in seen:
            failures.append(f"duplicate manifest entry: {relative}")
            continue
        seen.add(relative)
        file = ROOT / relative
        if not file.exists():
            failures.append(f"missing output: {relative}")
            continue
        if file.stat().st_size != entry["bytes"]:
            failures.append(f"byte mismatch: {relative}")
        if sha256(file) != entry["sha256"]:
            failures.append(f"hash mismatch: {relative}")

    safe = manifest["safeZone"]
    for key in ("foreground", "monochrome"):
        measured = float(safe[key]["maxRadius"])
        if measured > float(safe["radius"]):
            failures.append(
                f"{key} exceeds safe radius: {measured} > {safe['radius']}"
            )

    checks: dict[str, object] = {}
    apple = PLATFORM_DIR / "apple/sources/synapse-default-1024.png"
    checks["appleDefault"] = image_metrics(apple)
    if (
        checks["appleDefault"]["width"] != 1024  # type: ignore[index]
        or not checks["appleDefault"]["opaque"]  # type: ignore[index]
    ):
        failures.append("Apple default source must be opaque 1024x1024")

    ios_entries = [
        entry
        for entry in entries
        if entry.get("platform") == "ios" and entry.get("role") == "app-icon"
    ]
    for entry in ios_entries:
        metrics = image_metrics(ROOT / entry["file"])
        if metrics["width"] != entry["pixels"] or metrics["height"] != entry["pixels"]:
            failures.append(f"iOS pixel mismatch: {entry['file']}")
        if not metrics["opaque"]:
            failures.append(f"iOS icon has alpha: {entry['file']}")

    adaptive = PLATFORM_DIR / "android/res/mipmap-xxxhdpi/ic_launcher_foreground.png"
    adaptive_metrics = image_metrics(adaptive)
    checks["androidAdaptiveForeground"] = adaptive_metrics
    expected_radius = math.ceil(
        432 * float(safe["radius"]) / float(safe["canvas"])
    ) + 1
    if adaptive_metrics["maxRadius"] > expected_radius:
        failures.append(
            "Android adaptive foreground exceeds scaled safe radius: "
            f"{adaptive_metrics['maxRadius']} > {expected_radius}"
        )
    if adaptive_metrics["borderPixels"]:
        failures.append("Android adaptive foreground touches its layer boundary")

    v33 = (
        PLATFORM_DIR / "android/res/mipmap-anydpi-v33/ic_launcher.xml"
    ).read_text(encoding="utf-8")
    if "<monochrome" not in v33 or "ic_launcher_monochrome" not in v33:
        failures.append("Android v33 themed icon layer missing")

    web_maskable = PLATFORM_DIR / "web/icons/Icon-maskable-512.png"
    checks["webMaskable"] = image_metrics(web_maskable)
    if not checks["webMaskable"]["opaque"]:  # type: ignore[index]
        failures.append("PWA maskable icon must be fully opaque")
    for kind in ("circle", "squircle", "rounded"):
        proof = PLATFORM_DIR / f"web/proofs/{kind}-mask.png"
        metrics = image_metrics(proof)
        checks[f"webProof.{kind}"] = metrics
        if kind == "circle" and metrics["opaque"]:
            failures.append("circle proof did not apply a transparent mask")

    ico = PLATFORM_DIR / "windows/app_icon.ico"
    checks["windowsIco"] = inspect_ico(ico)
    expected_ico = [16, 24, 32, 48, 64, 128, 256]
    if checks["windowsIco"]["sizes"] != expected_ico:  # type: ignore[index]
        failures.append(f"unexpected ICO sizes: {checks['windowsIco']}")

    linux = PLATFORM_DIR / "linux/hicolor/512x512/apps/synapse.png"
    checks["linux512"] = image_metrics(linux)
    if checks["linux512"]["width"] != 512:  # type: ignore[index]
        failures.append("Linux 512 icon has wrong dimensions")

    flutter_icon = PLATFORM_DIR / "flutter/assets/identity/mcr4_companion/app_icon_1024.png"
    checks["flutterIcon"] = image_metrics(flutter_icon)
    if not checks["flutterIcon"]["opaque"]:  # type: ignore[index]
        failures.append("Flutter app-icon fallback must be opaque")
    pose_entries = [
        entry
        for entry in entries
        if entry.get("platform") == "flutter" and entry.get("role") == "mascot-pose"
    ]
    if len(pose_entries) != 18:
        failures.append(f"expected 18 Flutter pose assets, found {len(pose_entries)}")

    if args.require_install:
        if not manifest.get("installedIntoFlutterProject"):
            failures.append("manifest does not record an install run")
        install_pairs = [
            (
                PLATFORM_DIR / "windows/app_icon.ico",
                APP / "windows/runner/resources/app_icon.ico",
            ),
            (
                PLATFORM_DIR / "web/icons/Icon-512.png",
                APP / "web/icons/Icon-512.png",
            ),
            (
                PLATFORM_DIR / "web/icons/Icon-maskable-512.png",
                APP / "web/icons/Icon-maskable-512.png",
            ),
            (
                PLATFORM_DIR
                / "android/res/mipmap-xxxhdpi/ic_launcher_foreground.png",
                APP
                / "android/app/src/main/res/mipmap-xxxhdpi/ic_launcher_foreground.png",
            ),
            (
                PLATFORM_DIR
                / "apple/ios/AppIcon.appiconset/Icon-App-1024x1024@1x.png",
                APP
                / "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png",
            ),
            (
                PLATFORM_DIR
                / "apple/macos/AppIcon.appiconset/app_icon_1024.png",
                APP
                / "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png",
            ),
            (
                PLATFORM_DIR
                / "flutter/assets/identity/mcr4_companion/app_icon_1024.png",
                APP / "assets/identity/mcr4_companion/app_icon_1024.png",
            ),
            (
                PLATFORM_DIR
                / "flutter/assets/identity/mcr4_companion/mascot_hero_pointing_1024.png",
                APP
                / "assets/identity/mcr4_companion/mascot_hero_pointing_1024.png",
            ),
        ]
        for package, installed in install_pairs:
            compare_installed(package, installed, failures)

    report = {
        "status": "pass" if not failures else "fail",
        "requireInstall": args.require_install,
        "selectedIdentity": manifest.get("selectedIdentity"),
        "manifestOutputs": len(entries),
        "safeZone": safe,
        "checks": checks,
        "failures": failures,
    }
    report_file = PLATFORM_DIR / "platform-verification.json"
    report_file.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2))
    if failures:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
