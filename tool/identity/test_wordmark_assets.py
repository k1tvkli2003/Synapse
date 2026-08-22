from __future__ import annotations

import hashlib
import json
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
RENDERS = (
    ROOT
    / "docs"
    / "codex"
    / "2026-07-15-synapse-medical-learning-os"
    / "assets"
    / "identity"
    / "production"
    / "wordmark"
    / "renders"
)


def sha256(file: Path) -> str:
    return hashlib.sha256(file.read_bytes()).hexdigest().upper()


def connected_components(mask: np.ndarray) -> list[list[tuple[int, int]]]:
    height, width = mask.shape
    seen = np.zeros_like(mask, dtype=bool)
    found: list[list[tuple[int, int]]] = []
    for y in range(height):
        for x in range(width):
            if not mask[y, x] or seen[y, x]:
                continue
            pixels: list[tuple[int, int]] = []
            queue: deque[tuple[int, int]] = deque([(x, y)])
            seen[y, x] = True
            while queue:
                px, py = queue.popleft()
                pixels.append((px, py))
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = px + dx, py + dy
                    if (
                        0 <= nx < width
                        and 0 <= ny < height
                        and mask[ny, nx]
                        and not seen[ny, nx]
                    ):
                        seen[ny, nx] = True
                        queue.append((nx, ny))
            found.append(pixels)
    return sorted(found, key=lambda item: min(point[0] for point in item))


def hole_count(component: list[tuple[int, int]]) -> int:
    xs = [point[0] for point in component]
    ys = [point[1] for point in component]
    min_x, max_x = min(xs), max(xs)
    min_y, max_y = min(ys), max(ys)
    width = max_x - min_x + 3
    height = max_y - min_y + 3
    solid = np.zeros((height, width), dtype=bool)
    for x, y in component:
        solid[y - min_y + 1, x - min_x + 1] = True
    exterior = np.zeros_like(solid, dtype=bool)
    queue: deque[tuple[int, int]] = deque([(0, 0)])
    exterior[0, 0] = True
    while queue:
        x, y = queue.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if (
                0 <= nx < width
                and 0 <= ny < height
                and not solid[ny, nx]
                and not exterior[ny, nx]
            ):
                exterior[ny, nx] = True
                queue.append((nx, ny))
    holes = ~solid & ~exterior
    return len(connected_components(holes))


def inspect(file: Path) -> dict[str, object]:
    rgba = np.asarray(Image.open(file).convert("RGBA"), dtype=np.uint8)
    alpha = rgba[:, :, 3]
    mask = alpha > 64
    components = [component for component in connected_components(mask) if len(component) >= 2]
    xs = np.where(mask)[1]
    ys = np.where(mask)[0]
    if len(xs) == 0:
        raise AssertionError(f"{file.name}: empty alpha")
    bounds = [int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())]
    border = int(mask[0, :].sum() + mask[-1, :].sum() + mask[:, 0].sum() + mask[:, -1].sum())
    glyph_bounds: list[list[int]] = []
    holes: list[int] = []
    for component in components:
        cxs = [point[0] for point in component]
        cys = [point[1] for point in component]
        glyph_bounds.append([min(cxs), min(cys), max(cxs), max(cys)])
        holes.append(hole_count(component))
    mean_rgb = rgba[:, :, :3][mask].mean(axis=0)
    blue_accents = int(((rgba[:, :, 2].astype(int) - rgba[:, :, 0].astype(int) > 20) & mask).sum())
    return {
        "file": file.name,
        "canvas": [int(rgba.shape[1]), int(rgba.shape[0])],
        "bounds": bounds,
        "ratio": round((bounds[2] - bounds[0] + 1) / (bounds[3] - bounds[1] + 1), 4),
        "components": len(components),
        "glyphBounds": glyph_bounds,
        "holes": holes,
        "borderPixels": border,
        "meanRgb": [round(float(value), 2) for value in mean_rgb],
        "blueAccentPixels": blue_accents,
    }


def main() -> None:
    manifest_file = RENDERS / "render-manifest.json"
    manifest = json.loads(manifest_file.read_text(encoding="utf-8"))
    failures: list[str] = []
    for entry in manifest["outputs"]:
        file = ROOT / entry["file"]
        if not file.exists():
            failures.append(f"missing manifest output: {entry['file']}")
            continue
        if file.stat().st_size != entry["bytes"] or sha256(file) != entry["sha256"]:
            failures.append(f"manifest mismatch: {entry['file']}")

    cases = [
        "synapse-wordmark-frost-240h.png",
        "synapse-wordmark-frost-96h.png",
        "synapse-wordmark-one-color-frost-96h.png",
        "synapse-wordmark-one-color-frost-48h.png",
        "synapse-wordmark-one-color-frost-24h.png",
        "synapse-wordmark-one-color-ink-96h.png",
        "synapse-wordmark-one-color-ink-24h.png",
    ]
    results: list[dict[str, object]] = []
    for name in cases:
        result = inspect(RENDERS / name)
        results.append(result)
        if result["components"] != 7:
            failures.append(f"{name}: expected seven separate glyphs, found {result['components']}")
        if result["borderPixels"] != 0:
            failures.append(f"{name}: alpha clips the canvas")
        if not 6.5 <= float(result["ratio"]) <= 7.5:
            failures.append(f"{name}: unexpected wordmark ratio {result['ratio']}")
        holes = result["holes"]
        if len(holes) == 7 and holes[3] < 1:  # type: ignore[arg-type]
            failures.append(f"{name}: A counter disappeared")
        if len(holes) == 7 and holes[4] != 0:  # type: ignore[arg-type]
            failures.append(f"{name}: P open counter accidentally closed")

    frost = next(result for result in results if result["file"] == "synapse-wordmark-frost-240h.png")
    if int(frost["blueAccentPixels"]) < 500:
        failures.append("material wordmark lost its living-fold accents")
    light = next(result for result in results if result["file"] == "synapse-wordmark-one-color-frost-96h.png")
    ink = next(result for result in results if result["file"] == "synapse-wordmark-one-color-ink-96h.png")
    if min(light["meanRgb"]) < 220:  # type: ignore[arg-type]
        failures.append("frost one-color proof is unexpectedly dark")
    if max(ink["meanRgb"]) > 50:  # type: ignore[arg-type]
        failures.append("ink one-color proof is unexpectedly light")

    report = {
        "status": "pass" if not failures else "fail",
        "failures": failures,
        "results": results,
    }
    output = RENDERS / "verification.json"
    output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2))
    if failures:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
