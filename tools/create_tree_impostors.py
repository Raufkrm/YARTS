"""Render tree impostor sprites from the current YARTS tree GLBs.

Outputs transparent PNGs for each tree from three gameplay camera angles:
ground-level, 45 degrees above, and 90 degrees top-down.
"""

from __future__ import annotations

import json
import math
from pathlib import Path

import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[1]
FOLIAGE_DIR = ROOT / "assets" / "models" / "foliage"
OUTPUT_ROOT = ROOT / "assets" / "sprites" / "tree_impostors"
SPRITE_SIZE = 512

ANGLE_SPECS = {
    "ground": {
        "label": "Ground level",
        "direction": Vector((0.0, 1.0, -0.08)),
        "up": Vector((0.0, 0.0, 1.0)),
        "padding": 1.22,
    },
    "angle45": {
        "label": "45 degrees above",
        "direction": Vector((0.0, 1.0, -1.0)),
        "up": Vector((0.0, 0.0, 1.0)),
        "padding": 1.28,
    },
    "top90": {
        "label": "90 degrees above",
        "direction": Vector((0.0, 0.0, -1.0)),
        "up": Vector((0.0, 1.0, 0.0)),
        "padding": 1.38,
    },
}


def clear_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()


def ensure_output_dirs() -> None:
    for angle_name in ANGLE_SPECS:
        (OUTPUT_ROOT / angle_name).mkdir(parents=True, exist_ok=True)


def tree_paths() -> list[Path]:
    return sorted(FOLIAGE_DIR.glob("*.glb"))


def look_at(obj: bpy.types.Object, target: Vector, up: Vector) -> None:
    direction = target - obj.location
    obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    if abs(up.dot(Vector((0.0, 0.0, 1.0)))) < 0.5:
        obj.rotation_euler.rotate_axis("Z", 0.0)


def scene_bounds(objects: list[bpy.types.Object]) -> tuple[Vector, Vector]:
    min_corner = Vector((math.inf, math.inf, math.inf))
    max_corner = Vector((-math.inf, -math.inf, -math.inf))
    for obj in objects:
        if obj.type != "MESH":
            continue
        for corner in obj.bound_box:
            world_corner = obj.matrix_world @ Vector(corner)
            min_corner.x = min(min_corner.x, world_corner.x)
            min_corner.y = min(min_corner.y, world_corner.y)
            min_corner.z = min(min_corner.z, world_corner.z)
            max_corner.x = max(max_corner.x, world_corner.x)
            max_corner.y = max(max_corner.y, world_corner.y)
            max_corner.z = max(max_corner.z, world_corner.z)
    return min_corner, max_corner


def projected_ortho_scale(objects: list[bpy.types.Object], camera: bpy.types.Object, padding: float) -> float:
    half_width = 0.0
    half_height = 0.0
    for obj in objects:
        if obj.type != "MESH":
            continue
        for corner in obj.bound_box:
            camera_space = camera.matrix_world.inverted() @ (obj.matrix_world @ Vector(corner))
            half_width = max(half_width, abs(camera_space.x))
            half_height = max(half_height, abs(camera_space.y))
    return max(half_width, half_height, 0.5) * 2.0 * padding


def fit_ortho_scale(
    angle_name: str,
    min_corner: Vector,
    max_corner: Vector,
    height: float,
    padding: float,
) -> float:
    horizontal_span = max(max_corner.x - min_corner.x, max_corner.y - min_corner.y, 0.5)
    if angle_name == "top90":
        return horizontal_span * padding
    return max(height, horizontal_span * 0.9, 0.5) * padding


def setup_rendering() -> None:
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE_NEXT"
    scene.eevee.taa_render_samples = 32
    scene.render.resolution_x = SPRITE_SIZE
    scene.render.resolution_y = SPRITE_SIZE
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "Medium High Contrast"
    scene.world = bpy.data.worlds.new("Transparent_World")
    scene.world.color = (0.0, 0.0, 0.0)


def setup_lighting(center: Vector, height: float) -> None:
    bpy.ops.object.light_add(type="AREA", location=center + Vector((-3.0, -4.0, height + 3.0)))
    key = bpy.context.object
    key.name = "Tree_Impostor_Key_Light"
    key.data.energy = 500
    key.data.size = 5.0

    bpy.ops.object.light_add(type="POINT", location=center + Vector((3.0, 4.0, height * 0.65 + 2.0)))
    fill = bpy.context.object
    fill.name = "Tree_Impostor_Fill_Light"
    fill.data.energy = 85


def render_tree_angle(tree_path: Path, angle_name: str, spec: dict[str, object]) -> dict[str, object]:
    clear_scene()
    bpy.ops.import_scene.gltf(filepath=str(tree_path))
    mesh_objects = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    if not mesh_objects:
        raise RuntimeError(f"No mesh objects imported from {tree_path}")

    min_corner, max_corner = scene_bounds(mesh_objects)
    center = (min_corner + max_corner) * 0.5
    height = max(max_corner.z - min_corner.z, 1.0)
    target = Vector((center.x, center.y, min_corner.z + height * 0.48))
    setup_lighting(center, height)

    view_direction = Vector(spec["direction"]).normalized()
    camera_distance = max(height * 4.0, 12.0)
    camera_location = target - view_direction * camera_distance
    bpy.ops.object.camera_add(location=camera_location)
    camera = bpy.context.object
    camera.name = f"{tree_path.stem}_{angle_name}_Camera"
    camera.data.type = "ORTHO"
    look_at(camera, target, Vector(spec["up"]))
    camera.data.ortho_scale = fit_ortho_scale(
        angle_name,
        min_corner,
        max_corner,
        height,
        float(spec["padding"]),
    )
    bpy.context.scene.camera = camera

    output_path = OUTPUT_ROOT / angle_name / f"{tree_path.stem}_{angle_name}.png"
    bpy.context.scene.render.filepath = str(output_path)
    bpy.ops.render.render(write_still=True)
    return {
        "tree": tree_path.stem,
        "source": str(tree_path.relative_to(ROOT)).replace("\\", "/"),
        "angle": angle_name,
        "label": str(spec["label"]),
        "sprite": str(output_path.relative_to(ROOT)).replace("\\", "/"),
        "size": SPRITE_SIZE,
    }


def main() -> None:
    ensure_output_dirs()
    setup_rendering()
    manifest: list[dict[str, object]] = []
    for tree_path in tree_paths():
        for angle_name, spec in ANGLE_SPECS.items():
            manifest.append(render_tree_angle(tree_path, angle_name, spec))

    manifest_path = OUTPUT_ROOT / "tree_impostors_manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    print("YARTS_TREE_IMPOSTORS " + json.dumps({
        "count": len(manifest),
        "output_root": str(OUTPUT_ROOT),
        "manifest": str(manifest_path),
    }, indent=2))


if __name__ == "__main__":
    main()
