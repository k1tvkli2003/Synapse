from __future__ import annotations

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
    / "mascot-icon"
    / "renders"
)


def components(mask: np.ndarray) -> int:
    height, width = mask.shape
    seen = np.zeros_like(mask, dtype=bool)
    count = 0
    for y in range(height):
        for x in range(width):
            if not mask[y, x] or seen[y, x]:
                continue
            count += 1
            queue: deque[tuple[int, int]] = deque([(x, y)])
            seen[y, x] = True
            while queue:
                px, py = queue.popleft()
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = px + dx, py + dy
                    if 0 <= nx < width and 0 <= ny < height and mask[ny, nx] and not seen[ny, nx]:
                        seen[ny, nx] = True
                        queue.append((nx, ny))
    return count


def run_count(row: np.ndarray) -> int:
    if row.size == 0:
        return 0
    starts = row & np.concatenate(([True], ~row[:-1]))
    return int(starts.sum())


def inspect(file: Path, require_transparent_border: bool) -> dict[str, int | float | str | list[int]]:
    rgba = np.asarray(Image.open(file).convert("RGBA"), dtype=np.uint8)
    alpha = rgba[:, :, 3]
    mask = alpha > 64
    ys, xs = np.where(mask)
    if len(xs) == 0:
        raise AssertionError(f"{file.name}: empty alpha mask")
    bounds = [int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())]
    min_x, min_y, max_x, max_y = bounds
    border_pixels = int(
        mask[0, :].sum() + mask[-1, :].sum() + mask[:, 0].sum() + mask[:, -1].sum()
    )
    if require_transparent_border and border_pixels:
        raise AssertionError(f"{file.name}: {border_pixels} alpha pixels touch the border")
    cropped = mask[min_y : max_y + 1, min_x : max_x + 1]
    split_rows = sum(run_count(row) >= 2 for row in cropped)
    ratio = cropped.shape[1] / cropped.shape[0]
    # Antialiased optical facial pixels are intentionally counted when they remain
    # materially darker than frost, not only when they are nearly pure ink.
    dark = (rgba[:, :, :3].mean(axis=2) < 120) & (alpha > 128)
    return {
        "file": file.name,
        "size": int(rgba.shape[0]),
        "bounds": bounds,
        "ratio": round(float(ratio), 4),
        "alphaComponents": components(mask),
        "splitRows": int(split_rows),
        "darkDetailPixels": int(dark.sum()),
        "borderPixels": border_pixels,
    }


def main() -> None:
    cases = [
        ("luma-foldkin-mark-monochrome-16.png", True),
        ("luma-foldkin-mark-monochrome-24.png", True),
        ("luma-foldkin-mark-monochrome-48.png", True),
        ("luma-foldkin-optical-24-24.png", True),
        ("luma-foldkin-optical-16-16.png", True),
        ("luma-foldkin-flat-48.png", True),
        ("luma-foldkin-master-1024.png", True),
        ("luma-foldkin-app-icon-16.png", False),
        ("luma-foldkin-app-icon-optical-16-16.png", False),
        ("luma-foldkin-app-icon-optical-24-24.png", False),
        ("luma-foldkin-app-icon-48.png", False),
        ("luma-foldkin-app-icon-1024.png", False),
    ]
    results = []
    failures = []
    for name, transparent_border in cases:
        file = RENDERS / name
        if not file.exists():
            failures.append(f"missing {name}")
            continue
        result = inspect(file, transparent_border)
        results.append(result)
        if "mark-monochrome" in name:
            if result["alphaComponents"] != 1:
                failures.append(f"{name}: expected one connected silhouette")
            if result["splitRows"] < 1:
                failures.append(f"{name}: support pocket closed or disappeared")
            if not 1.0 <= float(result["ratio"]) <= 1.25:
                failures.append(f"{name}: unexpected optical ratio {result['ratio']}")
        if "optical-24-24" in name and "app-icon" not in name and result["darkDetailPixels"] < 3:
            failures.append(f"{name}: face details disappeared")
        if "optical-16-16" in name and "app-icon" not in name and result["darkDetailPixels"] < 2:
            failures.append(f"{name}: optical eyes/smile disappeared")
        if "app-icon" in name and result["borderPixels"] == 0:
            failures.append(f"{name}: opaque app-icon field does not cover the canvas")

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
