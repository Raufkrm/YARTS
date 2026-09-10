from __future__ import annotations

import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector

sys.path.append(str(Path(__file__).resolve().parent))

from create_foliage_resource_assets import (
    ASSET_ROOT,
    assign_material,
    clear_scene,
    count_asset_stats,
    export_asset,
    finalize_object,
    make_ellipsoid,
    make_frustum_between,
    make_material,
    make_rock,
)

# Connection Map:
#   broken_log_segment_end <-> next_log_segment_start       overlap: shared center + radius overlap at joint
#   broken_log_end <-> splinter_base                       overlap: 0.04-0.10m inside trunk end
#   broken_log_side <-> branch_stub_base                   overlap: 0.04-0.12m inside trunk side
#   bone_shaft_end <-> bone_knuckle_center                 overlap: 0.015-0.05m inside shaft end
#   animal_skull_front <-> snout_back                      overlap: 0.05m on local X
#   carcass_spine <-> rib_base                             overlap: 0.02-0.05m at spine
#   flint_body_surface <-> flint_chip/vein                 overlap: 0.004-0.012m into outer face

DETAIL_DIR = ASSET_ROOT / "details"


def ensure_dirs() -> None:
    DETAIL_DIR.mkdir(parents=True, exist_ok=True)


def detail_materials() -> dict[str, bpy.types.Material]:
    return {
        "dead_bark": make_material("YARTS_Dead_Bark", (0.33, 0.25, 0.16, 1.0), roughness=0.88),
        "dark_bark": make_material("YARTS_Dark_Dead_Bark", (0.18, 0.12, 0.07, 1.0), roughness=0.92),
        "fresh_break": make_material("YARTS_Fresh_Wood_Break", (0.68, 0.54, 0.35, 1.0), roughness=0.72),
        "moss": make_material("YARTS_Log_Moss", (0.16, 0.31, 0.10, 1.0), roughness=0.86),
        "bone": make_material("YARTS_Old_Bone", (0.78, 0.70, 0.55, 1.0), roughness=0.80),
        "bone_dark": make_material("YARTS_Dirty_Bone", (0.42, 0.34, 0.24, 1.0), roughness=0.90),
        "shadow_hole": make_material("YARTS_Skull_Dark_Holes", (0.035, 0.030, 0.024, 1.0), roughness=0.96),
        "flint": make_material("YARTS_Shiny_Flint", (0.055, 0.058, 0.060, 1.0), metallic=0.55, roughness=0.16),
        "flint_mid": make_material("YARTS_Flint_Mid_Facet", (0.22, 0.23, 0.23, 1.0), metallic=0.48, roughness=0.18),
        "flint_chip": make_material("YARTS_Flint_Chipped_Edge", (0.76, 0.73, 0.66, 1.0), metallic=0.20, roughness=0.28),
    }


def make_bone(
    asset_name: str,
    name: str,
    start: Vector,
    end: Vector,
    radius: float,
    materials: dict[str, bpy.types.Material],
    dirty: bool = False,
) -> list[bpy.types.Object]:
    bone_mat = materials["bone_dark"] if dirty else materials["bone"]
    objects: list[bpy.types.Object] = []
    direction = end - start
    if direction.length < 0.001:
        return objects
    forward = direction.normalized()
    shaft_start = start + forward * radius * 0.55
    shaft_end = end - forward * radius * 0.55
    objects.append(make_frustum_between(f"{asset_name}_{name}_shaft", shaft_start, shaft_end, radius * 0.42, radius * 0.34, bone_mat, sides=7))
    for endpoint_name, center in (("a", start), ("b", end)):
        tangent = Vector((-forward.y, forward.x, 0.0))
        if tangent.length < 0.01:
            tangent = Vector((1.0, 0.0, 0.0))
        tangent.normalize()
        objects.append(make_ellipsoid(f"{asset_name}_{name}_knuckle_{endpoint_name}_1", center + tangent * radius * 0.28, Vector((radius * 0.72, radius * 0.52, radius * 0.46)), bone_mat, subdivisions=1))
        objects.append(make_ellipsoid(f"{asset_name}_{name}_knuckle_{endpoint_name}_2", center - tangent * radius * 0.28, Vector((radius * 0.62, radius * 0.48, radius * 0.40)), bone_mat, subdivisions=1))
    return objects


def make_skull(asset_name: str, origin: Vector, scale: float, materials: dict[str, bpy.types.Material], antlers: bool) -> list[bpy.types.Object]:
    objects: list[bpy.types.Object] = []
    objects.append(make_ellipsoid(f"{asset_name}_skull_cranium", origin + Vector((0.0, 0.0, 0.28 * scale)), Vector((0.34 * scale, 0.25 * scale, 0.23 * scale)), materials["bone"], subdivisions=1))
    objects.append(make_ellipsoid(f"{asset_name}_skull_snout", origin + Vector((0.38 * scale, 0.0, 0.20 * scale)), Vector((0.32 * scale, 0.16 * scale, 0.13 * scale)), materials["bone"], subdivisions=1))
    objects.append(make_ellipsoid(f"{asset_name}_skull_jaw", origin + Vector((0.34 * scale, 0.0, 0.08 * scale)), Vector((0.30 * scale, 0.11 * scale, 0.045 * scale)), materials["bone_dark"], subdivisions=1))
    for side in (-1.0, 1.0):
        objects.append(make_ellipsoid(f"{asset_name}_skull_eye_{'l' if side < 0 else 'r'}", origin + Vector((0.16 * scale, side * 0.14 * scale, 0.30 * scale)), Vector((0.07 * scale, 0.045 * scale, 0.055 * scale)), materials["shadow_hole"], subdivisions=1))
        objects.append(make_ellipsoid(f"{asset_name}_skull_nostril_{'l' if side < 0 else 'r'}", origin + Vector((0.58 * scale, side * 0.055 * scale, 0.22 * scale)), Vector((0.045 * scale, 0.026 * scale, 0.035 * scale)), materials["shadow_hole"], subdivisions=1))
        horn_base = origin + Vector((-0.16 * scale, side * 0.13 * scale, 0.43 * scale))
        horn_tip = origin + Vector((-0.48 * scale, side * 0.35 * scale, 0.68 * scale))
        if antlers:
            objects.append(make_frustum_between(f"{asset_name}_antler_{'l' if side < 0 else 'r'}_main", horn_base, horn_tip, 0.035 * scale, 0.018 * scale, materials["bone_dark"], sides=5))
            objects.append(make_frustum_between(f"{asset_name}_antler_{'l' if side < 0 else 'r'}_tine_1", horn_tip - Vector((0.07 * scale, side * 0.02 * scale, 0.02 * scale)), horn_tip + Vector((-0.03 * scale, side * 0.12 * scale, 0.18 * scale)), 0.018 * scale, 0.006 * scale, materials["bone_dark"], sides=5))
            objects.append(make_frustum_between(f"{asset_name}_antler_{'l' if side < 0 else 'r'}_tine_2", horn_tip - Vector((0.14 * scale, side * 0.04 * scale, 0.08 * scale)), horn_tip + Vector((-0.12 * scale, side * 0.08 * scale, 0.08 * scale)), 0.016 * scale, 0.006 * scale, materials["bone_dark"], sides=5))
        else:
            objects.append(make_frustum_between(f"{asset_name}_horn_{'l' if side < 0 else 'r'}", horn_base, horn_tip, 0.050 * scale, 0.012 * scale, materials["bone_dark"], sides=6))
    return objects


def build_broken_tree(asset_name: str, variant: int, materials: dict[str, bpy.types.Material]) -> list[bpy.types.Object]:
    objects: list[bpy.types.Object] = []
    if variant == 0:
        points = [Vector((-3.0, -0.10, 0.42)), Vector((-1.1, 0.22, 0.48)), Vector((1.05, 0.02, 0.42)), Vector((3.1, -0.08, 0.34))]
        radii = [0.44, 0.40, 0.36, 0.28]
    elif variant == 1:
        points = [Vector((-2.55, 0.20, 0.32)), Vector((-0.90, -0.24, 0.40)), Vector((0.95, -0.10, 0.38)), Vector((2.75, 0.24, 0.30))]
        radii = [0.34, 0.38, 0.32, 0.22]
    else:
        points = [Vector((-2.25, -0.18, 0.30)), Vector((-0.60, 0.08, 0.34)), Vector((0.95, 0.26, 0.31)), Vector((2.25, 0.08, 0.25))]
        radii = [0.30, 0.31, 0.26, 0.18]
    for i in range(len(points) - 1):
        mat = materials["dead_bark"] if i % 2 == 0 else materials["dark_bark"]
        objects.append(make_frustum_between(f"{asset_name}_trunk_segment_{i + 1}", points[i], points[i + 1], radii[i], radii[i + 1], mat, sides=8))

    for i, point in enumerate((points[0], points[-1])):
        inward = (points[1] - points[0]).normalized() if i == 0 else (points[-2] - points[-1]).normalized()
        for j in range(5):
            angle = math.tau * j / 5.0 + variant * 0.28
            offset = Vector((0.0, math.cos(angle) * radii[i * -1] * 0.36, math.sin(angle) * radii[i * -1] * 0.22))
            base = point + inward * 0.08 + offset
            tip = point - inward * (0.28 + 0.08 * (j % 2)) + offset * 0.45 + Vector((0.0, 0.0, 0.08 * math.sin(angle)))
            objects.append(make_frustum_between(f"{asset_name}_splinter_{i + 1}_{j + 1}", base, tip, 0.055, 0.010, materials["fresh_break"], sides=4))

    branch_specs = [
        (1, Vector((0.15, 0.60, 0.42)), 0.12),
        (1, Vector((-0.10, -0.72, 0.28)), 0.10),
        (2, Vector((0.55, 0.52, 0.22)), 0.09),
    ]
    for index, (point_index, branch_delta, radius) in enumerate(branch_specs):
        if point_index >= len(points):
            continue
        base = points[point_index] + Vector((0.0, 0.0, 0.05))
        end = points[point_index] + branch_delta
        objects.append(make_frustum_between(f"{asset_name}_branch_stub_{index + 1}", base, end, radius, radius * 0.28, materials["dead_bark"], sides=6))

    for j in range(4):
        t = (j + 1) / 5.0
        loc = points[0].lerp(points[-1], t) + Vector((0.0, 0.12 * math.sin(j * 2.1), radii[min(j, len(radii) - 1)] * 0.82))
        objects.append(make_ellipsoid(f"{asset_name}_moss_patch_{j + 1}", loc, Vector((0.32, 0.12, 0.035)), materials["moss"], subdivisions=1))
    return objects


def make_flint_mesh(asset_name: str, materials: dict[str, bpy.types.Material]) -> list[bpy.types.Object]:
    verts = [
        (-0.74, -0.42, 0.00), (0.54, -0.36, 0.00), (0.80, 0.12, 0.00), (0.20, 0.52, 0.00), (-0.58, 0.34, 0.00),
        (-0.50, -0.30, 0.22), (0.36, -0.28, 0.34), (0.58, 0.06, 0.24), (0.12, 0.36, 0.46), (-0.42, 0.20, 0.30),
        (-0.08, -0.02, 0.68),
    ]
    faces = [
        (0, 1, 2, 3, 4),
        (0, 5, 6, 1), (1, 6, 7, 2), (2, 7, 8, 3), (3, 8, 9, 4), (4, 9, 5, 0),
        (5, 10, 6), (6, 10, 7), (7, 10, 8), (8, 10, 9), (9, 10, 5),
    ]
    mesh = bpy.data.meshes.new(f"{asset_name}_body_Mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.validate(clean_customdata=False)
    mesh.update()
    body = bpy.data.objects.new(f"{asset_name}_body", mesh)
    bpy.context.collection.objects.link(body)
    assign_material(body, materials["flint"])
    objects = [body]

    chip_specs = [
        (Vector((-0.28, -0.30, 0.28)), Vector((0.28, -0.23, 0.38)), 0.025, materials["flint_chip"]),
        (Vector((0.16, 0.34, 0.42)), Vector((0.54, 0.08, 0.27)), 0.022, materials["flint_mid"]),
        (Vector((-0.48, 0.12, 0.30)), Vector((-0.08, -0.04, 0.66)), 0.018, materials["flint_chip"]),
    ]
    for i, (start, end, radius, material) in enumerate(chip_specs):
        objects.append(make_frustum_between(f"{asset_name}_flake_line_{i + 1}", start, end, radius, radius * 0.55, material, sides=4))
    return objects


def build_bone_pile(asset_name: str, materials: dict[str, bpy.types.Material]) -> list[bpy.types.Object]:
    objects: list[bpy.types.Object] = []
    bones = [
        (Vector((-0.72, -0.16, 0.14)), Vector((0.82, 0.12, 0.16)), 0.095),
        (Vector((-0.56, 0.38, 0.19)), Vector((0.62, -0.30, 0.25)), 0.080),
        (Vector((-0.20, -0.50, 0.24)), Vector((0.54, 0.52, 0.30)), 0.070),
        (Vector((-0.88, 0.18, 0.11)), Vector((-0.10, -0.22, 0.16)), 0.060),
        (Vector((0.18, 0.04, 0.38)), Vector((0.92, 0.40, 0.44)), 0.070),
    ]
    for i, (start, end, radius) in enumerate(bones):
        objects.extend(make_bone(asset_name, f"bone_{i + 1}", start, end, radius, materials, dirty=i % 2 == 1))
    objects.extend(make_skull(f"{asset_name}_animal", Vector((-0.10, 0.08, 0.18)), 0.72, materials, antlers=False))
    for i, loc in enumerate((Vector((-0.38, 0.04, 0.05)), Vector((0.26, -0.08, 0.06)), Vector((0.52, 0.18, 0.08)))):
        objects.append(make_rock(f"{asset_name}_dirt_clump_{i + 1}", 0.16, 0.10, 0.08, materials["bone_dark"], sides=6, offset=loc))
    return objects


def build_carcass(asset_name: str, materials: dict[str, bpy.types.Material]) -> list[bpy.types.Object]:
    objects: list[bpy.types.Object] = []
    spine_points = [Vector((-1.10, 0.0, 0.22)), Vector((-0.48, 0.02, 0.28)), Vector((0.20, -0.04, 0.30)), Vector((0.82, 0.00, 0.24))]
    for i in range(len(spine_points) - 1):
        objects.append(make_frustum_between(f"{asset_name}_spine_{i + 1}", spine_points[i], spine_points[i + 1], 0.055, 0.045, materials["bone_dark"], sides=6))
    for i, spine in enumerate(spine_points[1:-1]):
        for side in (-1.0, 1.0):
            rib_tip = spine + Vector((0.10 * i, side * (0.34 + 0.06 * i), -0.05))
            rib_mid = spine + Vector((0.03, side * (0.20 + 0.04 * i), 0.24))
            objects.append(make_frustum_between(f"{asset_name}_rib_{i + 1}_{'l' if side < 0 else 'r'}_upper", spine, rib_mid, 0.035, 0.024, materials["bone"], sides=5))
            objects.append(make_frustum_between(f"{asset_name}_rib_{i + 1}_{'l' if side < 0 else 'r'}_lower", rib_mid, rib_tip, 0.024, 0.012, materials["bone"], sides=5))
    objects.extend(make_skull(f"{asset_name}_skull", Vector((1.12, -0.04, 0.08)), 0.82, materials, antlers=True))
    leg_specs = [
        (Vector((-0.65, -0.26, 0.10)), Vector((-1.05, -0.62, 0.12)), 0.065),
        (Vector((-0.35, 0.26, 0.13)), Vector((-0.74, 0.68, 0.10)), 0.058),
        (Vector((0.42, -0.24, 0.12)), Vector((0.72, -0.70, 0.10)), 0.055),
        (Vector((0.50, 0.24, 0.12)), Vector((0.92, 0.62, 0.11)), 0.055),
    ]
    for i, (start, end, radius) in enumerate(leg_specs):
        objects.extend(make_bone(asset_name, f"leg_{i + 1}", start, end, radius, materials, dirty=i % 2 == 0))
    return objects


def build_specs(materials: dict[str, bpy.types.Material]) -> list[dict[str, object]]:
    specs: list[dict[str, object]] = []
    for index in range(3):
        specs.append({
            "name": f"broken_tree_{index + 1:02d}",
            "path": DETAIL_DIR / f"broken_tree_{index + 1:02d}.glb",
            "builder": lambda name, idx=index: build_broken_tree(name, idx, materials),
        })
    specs.extend([
        {"name": "bone_pile_01", "path": DETAIL_DIR / "bone_pile_01.glb", "builder": lambda name: build_bone_pile(name, materials)},
        {"name": "flint_stone_01", "path": DETAIL_DIR / "flint_stone_01.glb", "builder": lambda name: make_flint_mesh(name, materials)},
        {"name": "dead_carcass_01", "path": DETAIL_DIR / "dead_carcass_01.glb", "builder": lambda name: build_carcass(name, materials)},
    ])
    return specs


def export_all() -> dict[str, dict[str, int | str]]:
    ensure_dirs()
    stats: dict[str, dict[str, int | str]] = {}
    for base_spec in build_specs(detail_materials()):
        clear_scene()
        materials = detail_materials()
        spec = next(item for item in build_specs(materials) if item["name"] == base_spec["name"])
        objects = spec["builder"](str(spec["name"]))
        export_asset(objects, spec["path"])
        item_stats = count_asset_stats(objects)
        item_stats["path"] = str(spec["path"])
        stats[str(spec["name"])] = item_stats
    return stats


def main() -> None:
    clear_scene()
    stats = export_all()
    print("DETAIL_PROP_STATS=" + json.dumps(stats, indent=2))


if __name__ == "__main__":
    main()
