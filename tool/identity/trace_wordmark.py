from __future__ import annotations

import argparse
import json
import math
from collections import defaultdict, deque
from pathlib import Path

import numpy as np
from PIL import Image


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Trace the user-approved WMR2-01 wordmark into deterministic SVG geometry."
    )
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--out-dir", required=True, type=Path)
    parser.add_argument("--crop", default="100,70,1440,310", help="left,top,right,bottom")
    parser.add_argument("--threshold", default=60, type=int)
    parser.add_argument("--epsilon", default=1.15, type=float)
    parser.add_argument("--tension", default=0.07, type=float)
    return parser.parse_args()


def close_mask(mask: np.ndarray, radius: int = 1) -> np.ndarray:
    padded = np.pad(mask, radius, constant_values=False)
    dilated = np.zeros_like(mask)
    for dy in range(radius * 2 + 1):
        for dx in range(radius * 2 + 1):
            dilated |= padded[dy : dy + mask.shape[0], dx : dx + mask.shape[1]]
    padded = np.pad(dilated, radius, constant_values=False)
    eroded = np.ones_like(mask)
    for dy in range(radius * 2 + 1):
        for dx in range(radius * 2 + 1):
            eroded &= padded[dy : dy + mask.shape[0], dx : dx + mask.shape[1]]
    return eroded


def components(mask: np.ndarray, min_pixels: int = 400) -> list[set[tuple[int, int]]]:
    height, width = mask.shape
    seen = np.zeros_like(mask, dtype=bool)
    found: list[set[tuple[int, int]]] = []
    for y in range(height):
        for x in range(width):
            if not mask[y, x] or seen[y, x]:
                continue
            component: set[tuple[int, int]] = set()
            queue: deque[tuple[int, int]] = deque([(x, y)])
            seen[y, x] = True
            while queue:
                px, py = queue.popleft()
                component.add((px, py))
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
            if len(component) >= min_pixels:
                found.append(component)
    return sorted(found, key=lambda item: min(point[0] for point in item))


def boundary_cycles(component: set[tuple[int, int]]) -> list[list[tuple[int, int]]]:
    edges: set[tuple[tuple[int, int], tuple[int, int]]] = set()
    for x, y in component:
        if (x, y - 1) not in component:
            edges.add(((x, y), (x + 1, y)))
        if (x + 1, y) not in component:
            edges.add(((x + 1, y), (x + 1, y + 1)))
        if (x, y + 1) not in component:
            edges.add(((x + 1, y + 1), (x, y + 1)))
        if (x - 1, y) not in component:
            edges.add(((x, y + 1), (x, y)))

    outgoing: dict[tuple[int, int], set[tuple[int, int]]] = defaultdict(set)
    for start, end in edges:
        outgoing[start].add(end)
    direction_index = {(1, 0): 0, (0, 1): 1, (-1, 0): 2, (0, -1): 3}
    remaining = set(edges)
    cycles: list[list[tuple[int, int]]] = []
    while remaining:
        start_edge = min(remaining)
        start, current = start_edge
        previous = start
        cycle = [start, current]
        remaining.remove(start_edge)
        guard = len(edges) + 8
        while current != start and guard > 0:
            candidates = [end for end in outgoing[current] if (current, end) in remaining]
            if not candidates:
                break
            prev_vector = (current[0] - previous[0], current[1] - previous[1])
            prev_index = direction_index[prev_vector]
            preference = (
                (prev_index + 1) % 4,
                prev_index,
                (prev_index - 1) % 4,
                (prev_index + 2) % 4,
            )
            candidates.sort(
                key=lambda end: preference.index(
                    direction_index[(end[0] - current[0], end[1] - current[1])]
                )
            )
            next_point = candidates[0]
            remaining.remove((current, next_point))
            previous, current = current, next_point
            cycle.append(current)
            guard -= 1
        if len(cycle) > 4 and cycle[-1] == start:
            cycles.append(cycle[:-1])
    return cycles


def polygon_area(points: list[tuple[float, float]]) -> float:
    return 0.5 * sum(
        points[index][0] * points[(index + 1) % len(points)][1]
        - points[(index + 1) % len(points)][0] * points[index][1]
        for index in range(len(points))
    )


def point_line_distance(
    point: tuple[float, float], start: tuple[float, float], end: tuple[float, float]
) -> float:
    sx, sy = start
    ex, ey = end
    px, py = point
    dx, dy = ex - sx, ey - sy
    if dx == 0 and dy == 0:
        return math.hypot(px - sx, py - sy)
    return abs(dy * px - dx * py + ex * sy - ey * sx) / math.hypot(dx, dy)


def rdp_open(points: list[tuple[float, float]], epsilon: float) -> list[tuple[float, float]]:
    if len(points) <= 2:
        return points
    distances = [point_line_distance(point, points[0], points[-1]) for point in points[1:-1]]
    if not distances:
        return [points[0], points[-1]]
    maximum = max(distances)
    index = distances.index(maximum) + 1
    if maximum <= epsilon:
        return [points[0], points[-1]]
    left = rdp_open(points[: index + 1], epsilon)
    right = rdp_open(points[index:], epsilon)
    return left[:-1] + right


def simplify_closed(points: list[tuple[float, float]], epsilon: float) -> list[tuple[float, float]]:
    start = points[0]
    split = max(range(1, len(points)), key=lambda index: math.dist(start, points[index]))
    first = rdp_open(points[: split + 1], epsilon)
    second = rdp_open(points[split:] + [points[0]], epsilon)
    simplified = first[:-1] + second[:-1]
    return simplified if len(simplified) >= 6 else points


def catmull_rom_path(points: list[tuple[float, float]], tension: float) -> str:
    def fmt(value: float) -> str:
        return f"{value:.2f}".rstrip("0").rstrip(".")

    count = len(points)
    commands = [f"M{fmt(points[0][0])} {fmt(points[0][1])}"]
    for index in range(count):
        p0 = points[(index - 1) % count]
        p1 = points[index]
        p2 = points[(index + 1) % count]
        p3 = points[(index + 2) % count]
        c1 = (
            p1[0] + (p2[0] - p0[0]) * tension,
            p1[1] + (p2[1] - p0[1]) * tension,
        )
        c2 = (
            p2[0] - (p3[0] - p1[0]) * tension,
            p2[1] - (p3[1] - p1[1]) * tension,
        )
        commands.append(
            f"C{fmt(c1[0])} {fmt(c1[1])} {fmt(c2[0])} {fmt(c2[1])} "
            f"{fmt(p2[0])} {fmt(p2[1])}"
        )
    commands.append("Z")
    return "".join(commands)


def bbox(component: set[tuple[int, int]]) -> list[int]:
    xs = [point[0] for point in component]
    ys = [point[1] for point in component]
    return [min(xs), min(ys), max(xs), max(ys)]


def word_svg(
    width: int,
    height: int,
    word_path: str,
    title: str,
    description: str,
    material: bool,
) -> str:
    if not material:
        return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {width} {height}" role="img" aria-labelledby="title desc">
  <title id="title">{title}</title>
  <desc id="desc">{description}</desc>
  <path d="{word_path}" fill="currentColor" fill-rule="evenodd" clip-rule="evenodd"/>
</svg>
'''

    fold_paths = [
        "M82 165C112 143 145 142 174 161C153 184 116 193 84 184Z",
        "M248 78C272 91 294 92 318 76C309 105 286 119 262 111Z",
        "M426 88C452 75 486 92 512 122C491 137 460 127 438 109Z",
        "M674 144C689 131 713 131 730 144C716 159 691 163 675 155Z",
        "M874 121C890 110 910 116 923 132C909 147 891 152 875 146Z",
        "M1016 162C1046 143 1080 143 1111 160C1091 184 1052 192 1018 182Z",
    ]
    folds = "\n".join(
        f'    <path d="{path}" fill="url(#fold)" opacity="0.86"/>' for path in fold_paths
    )
    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {width} {height}" role="img" aria-labelledby="title desc">
  <title id="title">{title}</title>
  <desc id="desc">{description}</desc>
  <defs>
    <linearGradient id="frost" x1="0" y1="0" x2="0.82" y2="1">
      <stop offset="0" stop-color="#F9FBFF"/>
      <stop offset="0.5" stop-color="#E8F0FF"/>
      <stop offset="1" stop-color="#BFD5FF"/>
    </linearGradient>
    <linearGradient id="fold" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#F7FAFF"/>
      <stop offset="0.42" stop-color="#A8CBFF"/>
      <stop offset="1" stop-color="#66E4FF"/>
    </linearGradient>
    <clipPath id="word-clip" clipPathUnits="userSpaceOnUse">
      <path d="{word_path}" fill-rule="evenodd" clip-rule="evenodd"/>
    </clipPath>
  </defs>
  <path d="{word_path}" fill="url(#frost)" fill-rule="evenodd" clip-rule="evenodd"/>
  <g clip-path="url(#word-clip)">
{folds}
  </g>
</svg>
'''


def main() -> None:
    args = parse_args()
    crop = tuple(int(value) for value in args.crop.split(","))
    if len(crop) != 4:
        raise ValueError("--crop must be left,top,right,bottom")
    image = Image.open(args.input).convert("RGB")
    cropped = image.crop(crop)
    pixels = np.asarray(cropped, dtype=np.uint8)
    luminance = 0.2126 * pixels[:, :, 0] + 0.7152 * pixels[:, :, 1] + 0.0722 * pixels[:, :, 2]
    mask = close_mask(luminance >= args.threshold, radius=1)
    glyphs = components(mask)
    if len(glyphs) != 7:
        raise RuntimeError(f"Expected seven glyph components, found {len(glyphs)}; adjust crop/threshold.")

    glyph_paths: list[str] = []
    reports: list[dict[str, object]] = []
    for letter, component in zip("SYNAPSE", glyphs, strict=True):
        cycles = boundary_cycles(component)
        kept = [cycle for cycle in cycles if abs(polygon_area(cycle)) >= 18]
        if not kept:
            raise RuntimeError(f"No usable cycles for {letter}")
        paths: list[str] = []
        cycle_report: list[dict[str, object]] = []
        for cycle in kept:
            raw = [(float(x), float(y)) for x, y in cycle]
            simplified = simplify_closed(raw, args.epsilon)
            paths.append(catmull_rom_path(simplified, args.tension))
            cycle_report.append(
                {
                    "rawPoints": len(raw),
                    "simplifiedPoints": len(simplified),
                    "signedArea": round(polygon_area(raw), 3),
                }
            )
        glyph_paths.append("".join(paths))
        reports.append(
            {
                "letter": letter,
                "pixels": len(component),
                "bbox": bbox(component),
                "cycles": cycle_report,
            }
        )

    args.out_dir.mkdir(parents=True, exist_ok=True)
    cropped.save(args.out_dir / "approved-wordmark-crop.png")
    mask_rgba = np.zeros((*mask.shape, 4), dtype=np.uint8)
    mask_rgba[mask] = (255, 255, 255, 255)
    Image.fromarray(mask_rgba, mode="RGBA").save(args.out_dir / "approved-wordmark-mask.png")

    word_path = "".join(glyph_paths)
    width, height = cropped.size
    one_color = word_svg(
        width,
        height,
        word_path,
        "Synapse one-color wordmark",
        "Deterministic one-color reconstruction of the user-approved Warm Living Fold wordmark.",
        material=False,
    )
    frost = word_svg(
        width,
        height,
        word_path,
        "Synapse Warm Living Fold wordmark",
        "Frost and cyan material reconstruction of the user-approved Synapse wordmark.",
        material=True,
    )
    (args.out_dir / "synapse-wordmark-one-color.svg").write_text(one_color, encoding="utf-8")
    (args.out_dir / "synapse-wordmark-frost.svg").write_text(frost, encoding="utf-8")
    (args.out_dir / "trace-report.json").write_text(
        json.dumps(
            {
                "input": str(args.input),
                "crop": crop,
                "viewBox": [0, 0, width, height],
                "threshold": args.threshold,
                "epsilon": args.epsilon,
                "tension": args.tension,
                "glyphs": reports,
                "wordPath": word_path,
            },
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )
    print(json.dumps({"glyphs": reports, "viewBox": [0, 0, width, height]}, indent=2))


if __name__ == "__main__":
    main()
