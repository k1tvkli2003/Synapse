from __future__ import annotations

import argparse
import json
import math
from collections import defaultdict, deque
from pathlib import Path

import numpy as np
from PIL import Image


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Trace the MCR3-04 flat-master silhouette without network dependencies.")
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--out-dir", required=True, type=Path)
    parser.add_argument("--crop", default="400,45,760,430", help="left,top,right,bottom in source pixels")
    parser.add_argument("--threshold", default=170, type=int)
    parser.add_argument("--epsilon", default=3.2, type=float)
    parser.add_argument("--tension", default=0.11, type=float)
    return parser.parse_args()


def largest_component(mask: np.ndarray) -> set[tuple[int, int]]:
    height, width = mask.shape
    seen = np.zeros_like(mask, dtype=bool)
    largest: set[tuple[int, int]] = set()
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
                    if 0 <= nx < width and 0 <= ny < height and mask[ny, nx] and not seen[ny, nx]:
                        seen[ny, nx] = True
                        queue.append((nx, ny))
            if len(component) > len(largest):
                largest = component
    if not largest:
        raise RuntimeError("No foreground component found; adjust crop or threshold.")
    return largest


def enclosed_holes(
    component: set[tuple[int, int]], shape: tuple[int, int]
) -> list[dict[str, float | int | list[int]]]:
    height, width = shape
    component_mask = np.zeros((height, width), dtype=bool)
    for x, y in component:
        component_mask[y, x] = True
    exterior = np.zeros((height, width), dtype=bool)
    queue: deque[tuple[int, int]] = deque()
    for x in range(width):
        for y in (0, height - 1):
            if not component_mask[y, x] and not exterior[y, x]:
                exterior[y, x] = True
                queue.append((x, y))
    for y in range(height):
        for x in (0, width - 1):
            if not component_mask[y, x] and not exterior[y, x]:
                exterior[y, x] = True
                queue.append((x, y))
    while queue:
        x, y = queue.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if (
                0 <= nx < width
                and 0 <= ny < height
                and not component_mask[ny, nx]
                and not exterior[ny, nx]
            ):
                exterior[ny, nx] = True
                queue.append((nx, ny))

    holes_mask = ~component_mask & ~exterior
    seen = np.zeros((height, width), dtype=bool)
    holes: list[dict[str, float | int | list[int]]] = []
    for y in range(height):
        for x in range(width):
            if not holes_mask[y, x] or seen[y, x]:
                continue
            pixels: list[tuple[int, int]] = []
            queue = deque([(x, y)])
            seen[y, x] = True
            while queue:
                px, py = queue.popleft()
                pixels.append((px, py))
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = px + dx, py + dy
                    if (
                        0 <= nx < width
                        and 0 <= ny < height
                        and holes_mask[ny, nx]
                        and not seen[ny, nx]
                    ):
                        seen[ny, nx] = True
                        queue.append((nx, ny))
            if len(pixels) < 4:
                continue
            xs = [pixel[0] for pixel in pixels]
            ys = [pixel[1] for pixel in pixels]
            holes.append(
                {
                    "pixels": len(pixels),
                    "bbox": [min(xs), min(ys), max(xs), max(ys)],
                    "centroid": [sum(xs) / len(xs), sum(ys) / len(ys)],
                }
            )
    return sorted(holes, key=lambda item: int(item["pixels"]), reverse=True)


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
            preference = ((prev_index + 1) % 4, prev_index, (prev_index - 1) % 4, (prev_index + 2) % 4)
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
    if not cycles:
        raise RuntimeError("No closed boundary cycle found.")
    return cycles


def polygon_area(points: list[tuple[float, float]]) -> float:
    return 0.5 * sum(
        points[i][0] * points[(i + 1) % len(points)][1]
        - points[(i + 1) % len(points)][0] * points[i][1]
        for i in range(len(points))
    )


def point_line_distance(point: tuple[float, float], start: tuple[float, float], end: tuple[float, float]) -> float:
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
    max_distance = max(distances)
    index = distances.index(max_distance) + 1
    if max_distance <= epsilon:
        return [points[0], points[-1]]
    left = rdp_open(points[: index + 1], epsilon)
    right = rdp_open(points[index:], epsilon)
    return left[:-1] + right


def simplify_closed(points: list[tuple[float, float]], epsilon: float) -> list[tuple[float, float]]:
    start = points[0]
    split = max(range(1, len(points)), key=lambda i: math.dist(start, points[i]))
    first = rdp_open(points[: split + 1], epsilon)
    second = rdp_open(points[split:] + [points[0]], epsilon)
    simplified = first[:-1] + second[:-1]
    if len(simplified) < 8:
        raise RuntimeError(f"Contour oversimplified to {len(simplified)} points.")
    return simplified


def scale_points(
    points: list[tuple[float, float]],
    target_box: tuple[float, float, float, float] = (112.0, 156.0, 912.0, 868.0),
) -> tuple[list[tuple[float, float]], dict[str, float]]:
    xs = [point[0] for point in points]
    ys = [point[1] for point in points]
    min_x, max_x = min(xs), max(xs)
    min_y, max_y = min(ys), max(ys)
    left, top, right, bottom = target_box
    scale = min((right - left) / (max_x - min_x), (bottom - top) / (max_y - min_y))
    source_cx = (min_x + max_x) / 2
    source_cy = (min_y + max_y) / 2
    target_cx = (left + right) / 2
    target_cy = (top + bottom) / 2
    scaled = [
        ((x - source_cx) * scale + target_cx, (y - source_cy) * scale + target_cy)
        for x, y in points
    ]
    return scaled, {
        "sourceMinX": min_x,
        "sourceMaxX": max_x,
        "sourceMinY": min_y,
        "sourceMaxY": max_y,
        "uniformScale": scale,
    }


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
        c1 = (p1[0] + (p2[0] - p0[0]) * tension, p1[1] + (p2[1] - p0[1]) * tension)
        c2 = (p2[0] - (p3[0] - p1[0]) * tension, p2[1] - (p3[1] - p1[1]) * tension)
        commands.append(
            f"C{fmt(c1[0])} {fmt(c1[1])} {fmt(c2[0])} {fmt(c2[1])} {fmt(p2[0])} {fmt(p2[1])}"
        )
    commands.append("Z")
    return "".join(commands)


def main() -> None:
    args = parse_args()
    crop = tuple(int(value) for value in args.crop.split(","))
    if len(crop) != 4:
        raise ValueError("--crop must contain left,top,right,bottom")
    image = Image.open(args.input).convert("RGB")
    cropped = image.crop(crop)
    pixels = np.asarray(cropped, dtype=np.uint8)
    luminance = 0.2126 * pixels[:, :, 0] + 0.7152 * pixels[:, :, 1] + 0.0722 * pixels[:, :, 2]
    mask = luminance >= args.threshold
    component = largest_component(mask)
    holes = enclosed_holes(component, mask.shape)
    cycles = boundary_cycles(component)
    outer = max(cycles, key=lambda cycle: abs(polygon_area(cycle)))
    simplified = simplify_closed([(float(x), float(y)) for x, y in outer], args.epsilon)
    scaled, scale_report = scale_points(simplified)
    path_data = catmull_rom_path(scaled, args.tension)

    args.out_dir.mkdir(parents=True, exist_ok=True)
    mask_image = np.zeros((*mask.shape, 4), dtype=np.uint8)
    for x, y in component:
        mask_image[y, x] = (255, 255, 255, 255)
    Image.fromarray(mask_image, mode="RGBA").save(args.out_dir / "trace-largest-component.png")

    svg = f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">
  <rect width="1024" height="1024" fill="#07182D"/>
  <path d="{path_data}" fill="#DCE9FF"/>
</svg>\n'''
    (args.out_dir / "luma-foldkin-traced-silhouette.svg").write_text(svg, encoding="utf-8")
    report = {
        "input": str(args.input),
        "crop": crop,
        "threshold": args.threshold,
        "componentPixels": len(component),
        "enclosedHoles": holes,
        "cycleCount": len(cycles),
        "rawOuterPoints": len(outer),
        "simplifiedPoints": len(simplified),
        "epsilon": args.epsilon,
        "tension": args.tension,
        "signedArea": polygon_area(outer),
        **scale_report,
        "scaledPoints": [[round(x, 3), round(y, 3)] for x, y in scaled],
        "path": path_data,
    }
    (args.out_dir / "trace-report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(
        json.dumps(
            {
                key: report[key]
                for key in (
                    "componentPixels",
                    "rawOuterPoints",
                    "simplifiedPoints",
                    "uniformScale",
                    "enclosedHoles",
                )
            },
            indent=2,
        )
    )


if __name__ == "__main__":
    main()
