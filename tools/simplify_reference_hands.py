from __future__ import annotations

import json
import math
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector

# Connection Map:
#   forearm_open_wrist(side) signed X ~= 0.660 <-> palm_finger_inner_face signed X ~= 0.656
#     overlap: 0.006m on signed X so the replacement palm visually tucks into the wrist.
#   thumb_inner_end(side) <-> palm_finger_lower_front_side
#     overlap: 0.010m through the palm side so the thumb reads as attached.
#   original body mesh <-> simplified hand parts
#     joined into one mesh per character after normal recalculation.

ROOT = Path(__file__).resolve().parents[1]
SOURCE_DIR = ROOT / "assets" / "reference_models"
MALE_SOURCE = SOURCE_DIR / "base_low_poly_male_reference.glb"
FEMALE_SOURCE = SOURCE_DIR / "base_low_poly_female_reference.glb"
MALE_OUT = SOURCE_DIR / "base_low_poly_male_reference_simple_hands.glb"
FEMALE_OUT = SOURCE_DIR / "base_low_poly_female_reference_simple_hands.glb"
BLEND_OUT = SOURCE_DIR / "base_low_poly_simple_hands_references.blend"
PREVIEW_OUT = SOURCE_DIR / "base_low_poly_simple_hands_references_preview.png"

WRIST_CUT_SIGNED_X = 0.660
WRIST_OVERLAP = 0.006


def clear_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()


def ensure_material(obj: bpy.types.Object) -> bpy.types.Material:
    if obj.data.materials:
        return obj.data.materials[0]
    material = bpy.data.materials.new("Reference_Matte_Grey")
    material.diffuse_color = (0.72, 0.72, 0.72, 1.0)
    obj.data.materials.append(material)
    return material


def percentile(values: list[float], amount: float) -> float:
    if not values:
        return 0.0
    ordered = sorted(values)
    idx = max(0, min(len(ordered) - 1, int(round((len(ordered) - 1) * amount))))
    return ordered[idx]


def make_tapered_palm(
    name: str,
    side: int,
    start_x: float,
    end_x: float,
    base_y_min: float,
    base_y_max: float,
    base_z_min: float,
    base_z_max: float,
    tip_y_min: float,
    tip_y_max: float,
    tip_z_min: float,
    tip_z_max: float,
    material: bpy.types.Material,
) -> bpy.types.Object:
    sx = side
    verts = [
        (sx * start_x, base_y_min, base_z_min),
        (sx * start_x, base_y_max, base_z_min),
        (sx * start_x, base_y_max, base_z_max),
        (sx * start_x, base_y_min, base_z_max),
        (sx * end_x, tip_y_min, tip_z_min),
        (sx * end_x, tip_y_max, tip_z_min),
        (sx * end_x, tip_y_max, tip_z_max),
        (sx * end_x, tip_y_min, tip_z_max),
    ]
    faces = [
        (0, 1, 2, 3),
        (4, 7, 6, 5),
        (0, 4, 5, 1),
        (1, 5, 6, 2),
        (2, 6, 7, 3),
        (3, 7, 4, 0),
    ]
    mesh = bpy.data.meshes.new(f"{name}_Mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(material)
    return obj


def make_box_beam(
    name: str,
    start: Vector,
    end: Vector,
    half_width: float,
    half_height: float,
    material: bpy.types.Material,
) -> bpy.types.Object:
    direction = end - start
    length = direction.length
    if length < 0.0001:
        raise ValueError(f"{name} has no length")
    forward = direction.normalized()
    world_up = Vector((0.0, 0.0, 1.0))
    if abs(forward.dot(world_up)) > 0.96:
        world_up = Vector((0.0, 1.0, 0.0))
    right = forward.cross(world_up).normalized()
    up = right.cross(forward).normalized()

    verts = []
    for center in (start, end):
        for sy, sz in ((-1.0, -1.0), (1.0, -1.0), (1.0, 1.0), (-1.0, 1.0)):
            p = center + right * half_width * sy + up * half_height * sz
            verts.append((p.x, p.y, p.z))
    faces = [
        (0, 1, 5, 4),
        (1, 2, 6, 5),
        (2, 3, 7, 6),
        (3, 0, 4, 7),
        (0, 3, 2, 1),
        (4, 5, 6, 7),
    ]
    mesh = bpy.data.meshes.new(f"{name}_Mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(material)
    return obj


def recalc_normals(obj: bpy.types.Object) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    bpy.ops.object.shade_flat()


def delete_original_hands(obj: bpy.types.Object) -> int:
    mesh = obj.data
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bm.faces.ensure_lookup_table()
    bm.verts.ensure_lookup_table()

    hand_faces = []
    for face in bm.faces:
        center_x = sum(v.co.x for v in face.verts) / float(len(face.verts))
        if abs(center_x) >= WRIST_CUT_SIGNED_X:
            hand_faces.append(face)
    removed = len(hand_faces)
    bmesh.ops.delete(bm, geom=hand_faces, context="FACES")

    loose_verts = [vert for vert in bm.verts if not vert.link_faces]
    if loose_verts:
        bmesh.ops.delete(bm, geom=loose_verts, context="VERTS")

    bm.to_mesh(mesh)
    bm.free()
    mesh.update()
    return removed


def side_hand_bounds(obj: bpy.types.Object, side: int) -> dict[str, float]:
    points = [v.co.copy() for v in obj.data.vertices if side * v.co.x >= WRIST_CUT_SIGNED_X]
    if not points:
        raise ValueError(f"No hand vertices found on side {side} for {obj.name}")

    signed_x = [side * p.x for p in points]
    y_values = [p.y for p in points]
    z_values = [p.z for p in points]

    palm_floor_y = percentile(y_values, 0.42)
    palm_points = [p for p in points if p.y >= palm_floor_y]
    if len(palm_points) < 8:
        palm_points = points

    palm_y = [p.y for p in palm_points]
    palm_z = [p.z for p in palm_points]

    return {
        "min_x": min(signed_x),
        "max_x": max(signed_x),
        "min_y": min(y_values),
        "max_y": max(y_values),
        "min_z": min(z_values),
        "max_z": max(z_values),
        "palm_min_y": min(palm_y),
        "palm_max_y": max(palm_y),
        "palm_min_z": min(palm_z),
        "palm_max_z": max(palm_z),
    }


def add_simplified_hand_parts(
    obj: bpy.types.Object,
    gender: str,
    material: bpy.types.Material,
    original_bounds: dict[int, dict[str, float]],
) -> list[bpy.types.Object]:
    parts: list[bpy.types.Object] = []
    for side in (-1, 1):
        bounds = original_bounds[side]
        start_x = bounds["min_x"] - WRIST_OVERLAP
        end_x = bounds["max_x"]
        palm_length = max(0.050, end_x - start_x)
        y_center = (bounds["palm_min_y"] + bounds["palm_max_y"]) * 0.5
        z_center = (bounds["palm_min_z"] + bounds["palm_max_z"]) * 0.5
        base_y_half = max(0.018, (bounds["palm_max_y"] - bounds["palm_min_y"]) * 0.50)
        base_z_half = max(0.013, (bounds["palm_max_z"] - bounds["palm_min_z"]) * 0.50)
        tip_y_half = base_y_half * 0.72
        tip_z_half = base_z_half * 0.70

        palm = make_tapered_palm(
            f"{gender}_Simple_{'Right' if side > 0 else 'Left'}_PalmFingers",
            side,
            start_x,
            end_x,
            y_center - base_y_half,
            y_center + base_y_half,
            z_center - base_z_half,
            z_center + base_z_half,
            y_center - tip_y_half,
            y_center + tip_y_half,
            z_center - tip_z_half,
            z_center + tip_z_half,
            material,
        )
        parts.append(palm)

        thumb_start = Vector(
            (
                side * (start_x + palm_length * 0.28),
                y_center - base_y_half * 0.82,
                z_center - base_z_half * 0.70,
            )
        )
        thumb_end = Vector(
            (
                side * (start_x + palm_length * 0.66),
                bounds["min_y"] + 0.010,
                bounds["min_z"] + max(0.010, (bounds["max_z"] - bounds["min_z"]) * 0.22),
            )
        )
        thumb = make_box_beam(
            f"{gender}_Simple_{'Right' if side > 0 else 'Left'}_Thumb",
            thumb_start,
            thumb_end,
            half_width=max(0.010, base_y_half * 0.38),
            half_height=max(0.010, base_z_half * 0.42),
            material=material,
        )
        parts.append(thumb)
    return parts


def count_tris(obj: bpy.types.Object) -> int:
    return sum(max(0, len(poly.vertices) - 2) for poly in obj.data.polygons)


def simplify_model(source: Path, output: Path, gender: str) -> dict[str, object]:
    clear_scene()
    bpy.ops.import_scene.gltf(filepath=str(source))
    body = next(o for o in bpy.context.scene.objects if o.type == "MESH")
    body.name = f"YARTS_Reference_Base_Low_Poly_{gender}_Simple_Hands"
    body.data.name = f"{body.name}_Mesh"
    bpy.context.view_layer.objects.active = body
    body.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)

    material = ensure_material(body)
    original_bounds = {side: side_hand_bounds(body, side) for side in (-1, 1)}
    before_vertices = len(body.data.vertices)
    before_faces = len(body.data.polygons)
    before_tris = count_tris(body)
    removed_faces = delete_original_hands(body)
    parts = add_simplified_hand_parts(body, gender, material, original_bounds)

    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True)
    bpy.context.view_layer.objects.active = body
    for part in parts:
        part.select_set(True)
    bpy.ops.object.join()
    joined = bpy.context.object
    joined.name = f"YARTS_Reference_Base_Low_Poly_{gender}_Simple_Hands"
    joined.data.name = f"{joined.name}_Mesh"
    recalc_normals(joined)

    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = joined
    joined.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(output), export_format="GLB", use_selection=True)

    return {
        "source": str(source),
        "output": str(output),
        "object": joined.name,
        "vertices_before": before_vertices,
        "faces_before": before_faces,
        "triangles_before": before_tris,
        "hand_faces_removed": removed_faces,
        "vertices_after": len(joined.data.vertices),
        "faces_after": len(joined.data.polygons),
        "triangles_after": count_tris(joined),
    }


def setup_preview() -> None:
    clear_scene()
    bpy.ops.import_scene.gltf(filepath=str(MALE_OUT))
    male = next(o for o in bpy.context.scene.objects if o.type == "MESH")
    male.location.x = -1.05
    male.name = "Preview_Male_Simple_Hands"

    bpy.ops.import_scene.gltf(filepath=str(FEMALE_OUT))
    female = [o for o in bpy.context.scene.objects if o.type == "MESH" and o != male][0]
    female.location.x = 1.05
    female.name = "Preview_Female_Simple_Hands"

    bpy.ops.object.light_add(type="AREA", location=(0.0, -3.2, 3.2))
    light = bpy.context.object
    light.name = "Preview_Key_Light"
    light.data.energy = 450
    light.data.size = 4.0

    bpy.ops.object.camera_add(location=(0.0, -5.0, 0.86), rotation=(math.radians(90), 0.0, 0.0))
    camera = bpy.context.object
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 3.2
    bpy.context.scene.camera = camera

    bpy.context.scene.render.engine = "CYCLES"
    bpy.context.scene.cycles.samples = 64
    bpy.context.scene.render.resolution_x = 1400
    bpy.context.scene.render.resolution_y = 1000
    bpy.context.scene.view_settings.view_transform = "Filmic"
    bpy.context.scene.view_settings.look = "Medium High Contrast"

    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND_OUT))
    bpy.context.scene.render.filepath = str(PREVIEW_OUT)
    bpy.ops.render.render(write_still=True)


def main() -> None:
    SOURCE_DIR.mkdir(parents=True, exist_ok=True)
    results = {
        "male": simplify_model(MALE_SOURCE, MALE_OUT, "Male"),
        "female": simplify_model(FEMALE_SOURCE, FEMALE_OUT, "Female"),
    }
    setup_preview()
    results["blend"] = str(BLEND_OUT)
    results["preview"] = str(PREVIEW_OUT)
    print("YARTS_SIMPLE_HAND_REFERENCE_STATS " + json.dumps(results, indent=2))


if __name__ == "__main__":
    main()
