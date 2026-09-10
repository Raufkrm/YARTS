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
    make_cylinder,
    make_ellipsoid,
    make_frustum_between,
    make_material,
    make_rock,
)

# Connection Map:
#   gold_bar_bottom_row <-> gold_bar_top_row       overlap: 0.01m on Z
#   log_bottom_pair <-> log_top                   overlap: 0.04m between circular sides
#   log_body <-> log_end_cut                      overlap: 0.01m into body end
#   stone_pile_base_stones <-> upper_stones       overlap: 0.02-0.06m on Z
#   clay_pot_body_top <-> clay_pot_rim            overlap: 0.04m on Z
#   clay_pot_opening <-> meat/berries             food sits 0.03m into dark opening

RESOURCE_DIR = ASSET_ROOT / "resources"


def ensure_dirs() -> None:
    RESOURCE_DIR.mkdir(parents=True, exist_ok=True)


def resource_materials() -> dict[str, bpy.types.Material]:
    return {
        "gold": make_material("YARTS_Shiny_Gold_Bars", (1.0, 0.72, 0.10, 1.0), metallic=1.0, roughness=0.16),
        "gold_edge": make_material("YARTS_Gold_Bright_Edges", (1.0, 0.90, 0.34, 1.0), metallic=1.0, roughness=0.12),
        "bark": make_material("YARTS_Log_Bark", (0.36, 0.22, 0.11, 1.0), roughness=0.86),
        "wood_cut": make_material("YARTS_Log_Cut_Wood", (0.74, 0.56, 0.33, 1.0), roughness=0.72),
        "stone": make_material("YARTS_Neat_Stone", (0.38, 0.38, 0.35, 1.0), roughness=0.88),
        "stone_dark": make_material("YARTS_Neat_Dark_Stone", (0.24, 0.24, 0.23, 1.0), roughness=0.92),
        "clay": make_material("YARTS_Brown_Clay_Pot", (0.44, 0.25, 0.13, 1.0), roughness=0.84),
        "dark_clay": make_material("YARTS_Dark_Pot_Opening", (0.10, 0.055, 0.035, 1.0), roughness=0.90),
        "meat": make_material("YARTS_Raw_Meat", (0.58, 0.12, 0.10, 1.0), roughness=0.70),
        "meat_fat": make_material("YARTS_Meat_Fat", (0.92, 0.72, 0.56, 1.0), roughness=0.78),
        "berries": make_material("YARTS_Berries", (0.36, 0.025, 0.09, 1.0), roughness=0.56),
    }


def make_box(name: str, location: Vector, half_extents: Vector, material: bpy.types.Material) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cube_add(size=2, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.data.name = f"{name}_Mesh"
    obj.scale = half_extents
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    assign_material(obj, material)
    return finalize_object(obj)


def build_gold_bars(asset_name: str, materials: dict[str, bpy.types.Material]) -> list[bpy.types.Object]:
    objects: list[bpy.types.Object] = []
    bar_half = Vector((0.42, 0.16, 0.075))
    positions = [
        Vector((-0.34, -0.18, 0.075)),
        Vector((0.34, -0.18, 0.075)),
        Vector((0.0, 0.18, 0.075)),
        Vector((-0.18, -0.02, 0.225)),
        Vector((0.18, -0.02, 0.225)),
    ]
    for index, position in enumerate(positions):
        material = materials["gold_edge"] if index >= 3 else materials["gold"]
        bar = make_box(f"{asset_name}_bar_{index + 1}", position, bar_half, material)
        bevel = bar.modifiers.new("Small low-poly bevel", "BEVEL")
        bevel.width = 0.025
        bevel.segments = 1
        bpy.context.view_layer.objects.active = bar
        bar.select_set(True)
        bpy.ops.object.modifier_apply(modifier=bevel.name)
        bar.select_set(False)
        objects.append(bar)
    return objects


def build_wood_logs(asset_name: str, materials: dict[str, bpy.types.Material]) -> list[bpy.types.Object]:
    objects: list[bpy.types.Object] = []
    log_specs = [
        (Vector((-2.05, -0.28, 0.26)), Vector((2.05, -0.28, 0.28)), 0.28),
        (Vector((-2.05, 0.30, 0.27)), Vector((2.05, 0.30, 0.25)), 0.27),
        (Vector((-2.00, 0.02, 0.72)), Vector((2.00, 0.02, 0.70)), 0.26),
    ]
    for index, (start, end, radius) in enumerate(log_specs):
        objects.append(make_frustum_between(f"{asset_name}_log_{index + 1}", start, end, radius, radius * 0.96, materials["bark"], sides=9))
        for side, point in (("left", start), ("right", end)):
            objects.append(make_ellipsoid(
                f"{asset_name}_log_{index + 1}_{side}_cut",
                point,
                Vector((0.035, radius * 0.88, radius * 0.88)),
                materials["wood_cut"],
                subdivisions=1,
            ))
    return objects


def build_stone_pile(asset_name: str, materials: dict[str, bpy.types.Material]) -> list[bpy.types.Object]:
    objects: list[bpy.types.Object] = []
    stone_specs = [
        (Vector((-0.42, -0.22, 0.0)), 0.34, 0.26, 0.24, "stone"),
        (Vector((0.12, -0.28, 0.0)), 0.32, 0.24, 0.28, "stone_dark"),
        (Vector((0.46, 0.10, 0.0)), 0.28, 0.22, 0.24, "stone"),
        (Vector((-0.18, 0.26, 0.0)), 0.38, 0.22, 0.26, "stone"),
        (Vector((0.06, 0.02, 0.22)), 0.30, 0.24, 0.25, "stone_dark"),
        (Vector((-0.42, 0.14, 0.20)), 0.22, 0.18, 0.18, "stone"),
        (Vector((0.34, -0.10, 0.22)), 0.20, 0.16, 0.16, "stone"),
    ]
    for index, (offset, radius_x, radius_y, height, material_key) in enumerate(stone_specs):
        objects.append(make_rock(
            f"{asset_name}_stone_{index + 1}",
            radius_x,
            radius_y,
            height,
            materials[material_key],
            sides=8,
            offset=offset,
        ))
    return objects


def build_food_pot(asset_name: str, materials: dict[str, bpy.types.Material]) -> list[bpy.types.Object]:
    objects: list[bpy.types.Object] = []
    objects.append(make_cylinder(f"{asset_name}_pot_foot", 0.36, 0.10, Vector((0.0, 0.0, 0.05)), materials["clay"], vertices=10))
    objects.append(make_cylinder(f"{asset_name}_pot_body", 0.46, 0.48, Vector((0.0, 0.0, 0.33)), materials["clay"], vertices=10))
    objects.append(make_cylinder(f"{asset_name}_pot_rim", 0.54, 0.12, Vector((0.0, 0.0, 0.60)), materials["clay"], vertices=10))
    objects.append(make_cylinder(f"{asset_name}_dark_opening", 0.44, 0.035, Vector((0.0, 0.0, 0.665)), materials["dark_clay"], vertices=10))

    meat_specs = [
        (Vector((-0.16, -0.04, 0.78)), Vector((0.24, 0.12, 0.08))),
        (Vector((0.14, 0.10, 0.76)), Vector((0.20, 0.10, 0.07))),
    ]
    for index, (location, scale) in enumerate(meat_specs):
        objects.append(make_ellipsoid(f"{asset_name}_meat_{index + 1}", location, scale, materials["meat"], subdivisions=1))
        objects.append(make_ellipsoid(f"{asset_name}_fat_{index + 1}", location + Vector((0.02, -0.02, 0.045)), scale * 0.38, materials["meat_fat"], subdivisions=1))

    berry_positions = [
        (-0.24, 0.14, 0.75), (-0.13, 0.21, 0.80), (-0.02, 0.18, 0.76),
        (0.20, -0.12, 0.78), (0.30, -0.02, 0.75), (0.03, -0.22, 0.77),
        (-0.30, -0.10, 0.76), (0.18, 0.22, 0.80),
    ]
    for index, berry_position in enumerate(berry_positions):
        objects.append(make_ellipsoid(
            f"{asset_name}_berry_{index + 1}",
            Vector(berry_position),
            Vector((0.055, 0.055, 0.055)),
            materials["berries"],
            subdivisions=1,
        ))
    return objects


def build_specs(materials: dict[str, bpy.types.Material]) -> list[dict[str, object]]:
    return [
        {
            "name": "resource_gold_bars",
            "path": RESOURCE_DIR / "resource_gold_bars.glb",
            "builder": lambda name: build_gold_bars(name, materials),
        },
        {
            "name": "resource_wood_logs",
            "path": RESOURCE_DIR / "resource_wood_logs.glb",
            "builder": lambda name: build_wood_logs(name, materials),
        },
        {
            "name": "resource_stone_pile",
            "path": RESOURCE_DIR / "resource_stone_pile.glb",
            "builder": lambda name: build_stone_pile(name, materials),
        },
        {
            "name": "resource_food_pot",
            "path": RESOURCE_DIR / "resource_food_pot.glb",
            "builder": lambda name: build_food_pot(name, materials),
        },
    ]


def export_all() -> dict[str, dict[str, int | str]]:
    ensure_dirs()
    stats: dict[str, dict[str, int | str]] = {}
    for base_spec in build_specs(resource_materials()):
        clear_scene()
        materials = resource_materials()
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
    print("RESOURCE_PICKUP_ASSET_STATS=" + json.dumps(stats, indent=2))


if __name__ == "__main__":
    main()
