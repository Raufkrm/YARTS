from __future__ import annotations

import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
sys.path.append(str(ROOT / "tools"))

from create_foliage_resource_assets import (
    FOLIAGE_DIR,
    clear_scene,
    count_asset_stats,
    ensure_dirs,
    export_asset,
    make_frustum_between,
    make_material,
)


DEAD_TREE_SPECS = [
    {
        "name": "dead_tree_01",
        "height": 4.9,
        "base_radius": 0.18,
        "top_radius": 0.075,
        "lean": Vector((0.10, -0.04, 0.0)),
        "branches": [
            (0.45, Vector((0.62, -0.16, 0.60)), 0.045),
            (0.62, Vector((-0.45, 0.30, 0.38)), 0.038),
            (0.76, Vector((0.30, 0.42, 0.34)), 0.030),
        ],
    },
    {
        "name": "dead_tree_02",
        "height": 5.6,
        "base_radius": 0.16,
        "top_radius": 0.060,
        "lean": Vector((-0.22, 0.10, 0.0)),
        "branches": [
            (0.38, Vector((-0.70, 0.16, 0.54)), 0.040),
            (0.57, Vector((0.52, 0.34, 0.42)), 0.034),
            (0.72, Vector((-0.24, -0.48, 0.32)), 0.027),
            (0.83, Vector((0.22, 0.18, 0.24)), 0.022),
        ],
    },
    {
        "name": "dead_tree_03",
        "height": 4.2,
        "base_radius": 0.22,
        "top_radius": 0.090,
        "lean": Vector((0.02, 0.18, 0.0)),
        "branches": [
            (0.40, Vector((0.48, 0.40, 0.46)), 0.052),
            (0.56, Vector((-0.55, -0.16, 0.36)), 0.042),
            (0.68, Vector((0.22, -0.50, 0.30)), 0.035),
        ],
    },
]


def dead_tree_materials() -> dict[str, bpy.types.Material]:
    return {
        "dead_bark": make_material("YARTS_Dead_Tree_Bark", (0.22, 0.17, 0.13, 1.0), roughness=0.92),
        "dead_bark_light": make_material("YARTS_Dead_Tree_Light_Bark", (0.42, 0.36, 0.28, 1.0), roughness=0.90),
        "break": make_material("YARTS_Dead_Tree_Break", (0.58, 0.45, 0.30, 1.0), roughness=0.84),
    }


def build_dead_tree(spec: dict[str, object], materials: dict[str, bpy.types.Material]) -> list[bpy.types.Object]:
    name = str(spec["name"])
    height = float(spec["height"])
    base_radius = float(spec["base_radius"])
    top_radius = float(spec["top_radius"])
    lean = spec["lean"]  # type: ignore[assignment]
    if not isinstance(lean, Vector):
        raise TypeError("lean must be a Vector")

    base = Vector((0.0, 0.0, 0.0))
    top = Vector((lean.x, lean.y, height))
    objects: list[bpy.types.Object] = [
        make_frustum_between(
            f"{name}_trunk",
            base,
            top,
            base_radius,
            top_radius,
            materials["dead_bark"],
            sides=7,
        )
    ]

    # A short angled cap makes the tree read as broken without increasing the footprint.
    cap_end = top + Vector((lean.x * 0.20 + 0.10, lean.y * 0.20 - 0.06, 0.18))
    objects.append(
        make_frustum_between(
            f"{name}_broken_tip",
            top - Vector((0.0, 0.0, 0.05)),
            cap_end,
            top_radius * 1.05,
            0.015,
            materials["break"],
            sides=5,
        )
    )

    branch_specs = spec["branches"]
    if not isinstance(branch_specs, list):
        raise TypeError("branches must be a list")
    for index, branch in enumerate(branch_specs):
        height_t, direction, radius = branch
        if not isinstance(direction, Vector):
            raise TypeError("branch direction must be a Vector")
        start = base.lerp(top, float(height_t))
        end = start + direction
        objects.append(
            make_frustum_between(
                f"{name}_branch_{index + 1}",
                start,
                end,
                float(radius),
                max(0.010, float(radius) * 0.32),
                materials["dead_bark_light"] if index % 2 else materials["dead_bark"],
                sides=5,
            )
        )

    return objects


def main() -> None:
    ensure_dirs()
    stats: dict[str, dict[str, object]] = {}
    for spec in DEAD_TREE_SPECS:
        clear_scene()
        materials = dead_tree_materials()
        objects = build_dead_tree(spec, materials)
        path = FOLIAGE_DIR / f"{spec['name']}.glb"
        export_asset(objects, path)
        item_stats = count_asset_stats(objects)
        item_stats["path"] = str(path)
        item_stats["base_diameter_m"] = round(float(spec["base_radius"]) * 2.0, 3)
        stats[str(spec["name"])] = item_stats

    print("YARTS_DEAD_TREE_ASSET_STATS " + json.dumps(stats, indent=2))


if __name__ == "__main__":
    main()
