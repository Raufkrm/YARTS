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
    assign_material,
    clear_scene,
    count_asset_stats,
    ensure_dirs,
    export_asset,
    finalize_object,
    make_cylinder,
    make_material,
)


# Stump radii match the source trunk radii in build_conifer():
#   conifer_01 radius 0.18m -> diameter 0.36m
#   conifer_02 radius 0.16m -> diameter 0.32m
#   conifer_03 radius 0.22m -> diameter 0.44m
STUMP_SPECS = [
    {"name": "conifer_stump_01", "counterpart": "conifer_01", "radius": 0.18, "height": 0.58},
    {"name": "conifer_stump_02", "counterpart": "conifer_02", "radius": 0.16, "height": 0.64},
    {"name": "conifer_stump_03", "counterpart": "conifer_03", "radius": 0.22, "height": 0.54},
]


def stump_materials() -> dict[str, bpy.types.Material]:
    return {
        "bark": make_material("YARTS_Stump_Bark", (0.34, 0.20, 0.10, 1.0), roughness=0.88),
        "cut": make_material("YARTS_Stump_Cut_Wood", (0.66, 0.48, 0.27, 1.0), roughness=0.78),
        "inner": make_material("YARTS_Stump_Inner_Ring", (0.78, 0.60, 0.34, 1.0), roughness=0.74),
        "dark": make_material("YARTS_Stump_Dark_Ring", (0.23, 0.13, 0.07, 1.0), roughness=0.90),
    }


def make_ring(
    name: str,
    radius: float,
    tube_radius: float,
    z: float,
    material: bpy.types.Material,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_torus_add(
        major_segments=9,
        minor_segments=3,
        major_radius=max(0.001, radius),
        minor_radius=max(0.001, tube_radius),
        location=(0.0, 0.0, z),
    )
    obj = bpy.context.object
    obj.name = name
    obj.data.name = f"{name}_Mesh"
    assign_material(obj, material)
    return finalize_object(obj)


def make_cut_crack(
    name: str,
    radius: float,
    z: float,
    angle: float,
    material: bpy.types.Material,
) -> bpy.types.Object:
    half_width = radius * 0.055
    start = Vector((math.cos(angle) * radius * 0.18, math.sin(angle) * radius * 0.18, z))
    end = Vector((math.cos(angle) * radius * 0.72, math.sin(angle) * radius * 0.72, z + 0.002))
    perpendicular = Vector((-math.sin(angle), math.cos(angle), 0.0)) * half_width
    verts = [
        tuple(start - perpendicular),
        tuple(start + perpendicular),
        tuple(end + perpendicular * 0.42),
        tuple(end - perpendicular * 0.42),
    ]
    mesh = bpy.data.meshes.new(f"{name}_Mesh")
    mesh.from_pydata(verts, [], [(0, 1, 2), (0, 2, 3)])
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    assign_material(obj, material)
    return obj


def build_stump(spec: dict[str, object], materials: dict[str, bpy.types.Material]) -> list[bpy.types.Object]:
    name = str(spec["name"])
    radius = float(spec["radius"])
    height = float(spec["height"])
    top_z = height + 0.017

    objects: list[bpy.types.Object] = []
    objects.append(
        make_cylinder(
            f"{name}_bark",
            radius,
            height,
            Vector((0.0, 0.0, height * 0.5)),
            materials["bark"],
            vertices=7,
        )
    )
    objects.append(
        make_cylinder(
            f"{name}_cut_cap",
            radius,
            0.034,
            Vector((0.0, 0.0, top_z)),
            materials["cut"],
            vertices=7,
        )
    )
    objects.append(
        make_cylinder(
            f"{name}_inner_cut",
            radius * 0.64,
            0.038,
            Vector((0.0, 0.0, top_z + 0.003)),
            materials["inner"],
            vertices=7,
        )
    )
    objects.append(make_ring(f"{name}_growth_ring_outer", radius * 0.44, radius * 0.018, top_z + 0.025, materials["dark"]))
    objects.append(make_ring(f"{name}_growth_ring_inner", radius * 0.23, radius * 0.014, top_z + 0.028, materials["dark"]))
    objects.append(make_cut_crack(f"{name}_cut_crack_a", radius, top_z + 0.035, 0.40, materials["dark"]))
    objects.append(make_cut_crack(f"{name}_cut_crack_b", radius, top_z + 0.036, 2.75, materials["dark"]))
    return objects


def main() -> None:
    ensure_dirs()
    stats: dict[str, dict[str, object]] = {}
    for spec in STUMP_SPECS:
        clear_scene()
        materials = stump_materials()
        objects = build_stump(spec, materials)
        path = FOLIAGE_DIR / f"{spec['name']}.glb"
        export_asset(objects, path)
        item_stats = count_asset_stats(objects)
        item_stats["path"] = str(path)
        item_stats["counterpart"] = str(spec["counterpart"])
        item_stats["diameter_m"] = round(float(spec["radius"]) * 2.0, 3)
        stats[str(spec["name"])] = item_stats

    print("YARTS_STUMP_ASSET_STATS " + json.dumps(stats, indent=2))


if __name__ == "__main__":
    main()
