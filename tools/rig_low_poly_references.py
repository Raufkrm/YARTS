from __future__ import annotations

import json
import math
from pathlib import Path

import bpy
from mathutils import Vector

# Rig Map:
#   Hips -> Spine -> Chest -> Neck -> Head
#   Chest -> Shoulder.L/R -> UpperArm.L/R -> LowerArm.L/R -> Hand.L/R -> Thumb.L/R
#   Hips -> UpperLeg.L/R -> LowerLeg.L/R -> Foot.L/R
#
# Mesh binding map:
#   Torso/head/limb vertices are assigned to matching deform bones by local position.
#   The original low-poly wrist/forearm geometry is preserved from the simple-hand copy.
#   Simplified palm/fingers bind to Hand.L/R; simplified thumb bind to Thumb.L/R.

ROOT = Path(__file__).resolve().parents[1]
SOURCE_DIR = ROOT / "assets" / "reference_models"

MALE_SOURCE = SOURCE_DIR / "base_low_poly_male_reference_simple_hands.glb"
FEMALE_SOURCE = SOURCE_DIR / "base_low_poly_female_reference_simple_hands.glb"

MALE_RIGGED_GLB = SOURCE_DIR / "base_low_poly_male_reference_simple_hands_rigged.glb"
FEMALE_RIGGED_GLB = SOURCE_DIR / "base_low_poly_female_reference_simple_hands_rigged.glb"
RIGGED_BLEND = SOURCE_DIR / "base_low_poly_rigged_references.blend"
RIGGED_PREVIEW = SOURCE_DIR / "base_low_poly_rigged_references_preview.png"

BONE_NAMES = [
    "Hips",
    "Spine",
    "Chest",
    "Neck",
    "Head",
    "Shoulder.L",
    "UpperArm.L",
    "LowerArm.L",
    "Hand.L",
    "Thumb.L",
    "Shoulder.R",
    "UpperArm.R",
    "LowerArm.R",
    "Hand.R",
    "Thumb.R",
    "UpperLeg.L",
    "LowerLeg.L",
    "Foot.L",
    "UpperLeg.R",
    "LowerLeg.R",
    "Foot.R",
]


def clear_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()


def import_single_mesh(path: Path) -> bpy.types.Object:
    bpy.ops.import_scene.gltf(filepath=str(path))
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    if len(meshes) != 1:
        raise ValueError(f"Expected one mesh in {path}, found {len(meshes)}")
    mesh = meshes[0]
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = mesh
    mesh.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    return mesh


def mesh_bounds(obj: bpy.types.Object) -> dict[str, tuple[float, float]]:
    verts = [obj.matrix_world @ v.co for v in obj.data.vertices]
    return {
        "x": (min(v.x for v in verts), max(v.x for v in verts)),
        "y": (min(v.y for v in verts), max(v.y for v in verts)),
        "z": (min(v.z for v in verts), max(v.z for v in verts)),
    }


def side_suffix(x: float) -> str:
    return ".L" if x >= 0.0 else ".R"


def make_armature(name: str, height: float) -> bpy.types.Object:
    bpy.ops.object.armature_add(enter_editmode=True, location=(0.0, 0.0, 0.0))
    armature = bpy.context.object
    armature.name = name
    armature.data.name = f"{name}_Data"
    armature.data.display_type = "STICK"
    armature.show_in_front = True

    bones = armature.data.edit_bones
    bones.remove(bones[0])

    def z(amount: float) -> float:
        return height * amount

    def add_bone(
        bone_name: str,
        head: tuple[float, float, float],
        tail: tuple[float, float, float],
        parent_name: str | None = None,
        connected: bool = False,
    ) -> bpy.types.EditBone:
        bone = bones.new(bone_name)
        bone.head = Vector(head)
        bone.tail = Vector(tail)
        if parent_name:
            bone.parent = bones[parent_name]
            bone.use_connect = connected
        return bone

    add_bone("Hips", (0.0, 0.0, z(0.50)), (0.0, 0.0, z(0.60)))
    add_bone("Spine", (0.0, 0.0, z(0.60)), (0.0, 0.0, z(0.72)), "Hips", True)
    add_bone("Chest", (0.0, 0.0, z(0.72)), (0.0, 0.0, z(0.82)), "Spine", True)
    add_bone("Neck", (0.0, 0.0, z(0.82)), (0.0, 0.0, z(0.89)), "Chest", True)
    add_bone("Head", (0.0, 0.0, z(0.89)), (0.0, 0.0, z(0.995)), "Neck", True)

    for sign, suffix in ((1.0, ".L"), (-1.0, ".R")):
        add_bone(f"Shoulder{suffix}", (sign * 0.08, 0.0, z(0.805)), (sign * 0.27, 0.0, z(0.800)), "Chest")
        add_bone(f"UpperArm{suffix}", (sign * 0.27, 0.0, z(0.800)), (sign * 0.51, 0.0, z(0.800)), f"Shoulder{suffix}", True)
        add_bone(f"LowerArm{suffix}", (sign * 0.51, 0.0, z(0.800)), (sign * 0.66, 0.0, z(0.800)), f"UpperArm{suffix}", True)
        add_bone(f"Hand{suffix}", (sign * 0.66, 0.0, z(0.800)), (sign * 0.84, 0.0, z(0.800)), f"LowerArm{suffix}", True)
        add_bone(f"Thumb{suffix}", (sign * 0.70, -0.015, z(0.797)), (sign * 0.79, -0.065, z(0.790)), f"Hand{suffix}")

        add_bone(f"UpperLeg{suffix}", (sign * 0.115, 0.0, z(0.505)), (sign * 0.120, 0.0, z(0.305)), "Hips")
        add_bone(f"LowerLeg{suffix}", (sign * 0.120, 0.0, z(0.305)), (sign * 0.105, 0.0, z(0.085)), f"UpperLeg{suffix}", True)
        add_bone(f"Foot{suffix}", (sign * 0.105, 0.0, z(0.085)), (sign * 0.140, -0.115, z(0.030)), f"LowerLeg{suffix}", True)

    bpy.ops.object.mode_set(mode="OBJECT")
    return armature


def classify_vertex(co: Vector, height: float) -> str:
    x = co.x
    y = co.y
    z = co.z
    ax = abs(x)
    suffix = side_suffix(x)

    # Arms are in a T-pose and occupy the widest X positions.
    if ax >= 0.19 and z >= height * 0.67:
        if ax < 0.30:
            return f"Shoulder{suffix}"
        if ax < 0.44:
            return f"UpperArm{suffix}"
        if ax < 0.69:
            return f"LowerArm{suffix}"
        if y < 0.035 and z < height * 0.815:
            return f"Thumb{suffix}"
        return f"Hand{suffix}"

    # Legs are below the hips and separated around the center line.
    if z < height * 0.53 and ax >= 0.035:
        if z < height * 0.095:
            return f"Foot{suffix}"
        if z < height * 0.305:
            return f"LowerLeg{suffix}"
        return f"UpperLeg{suffix}"

    if z >= height * 0.885:
        return "Head"
    if z >= height * 0.815:
        return "Neck"
    if z >= height * 0.700:
        return "Chest"
    if z >= height * 0.570:
        return "Spine"
    return "Hips"


def bind_mesh_to_armature(mesh: bpy.types.Object, armature: bpy.types.Object, height: float) -> dict[str, int]:
    while mesh.vertex_groups:
        mesh.vertex_groups.remove(mesh.vertex_groups[0])

    groups = {bone_name: mesh.vertex_groups.new(name=bone_name) for bone_name in BONE_NAMES}
    counts = {bone_name: 0 for bone_name in BONE_NAMES}

    for vert in mesh.data.vertices:
        bone_name = classify_vertex(vert.co, height)
        groups[bone_name].add([vert.index], 1.0, "REPLACE")
        counts[bone_name] += 1

    modifier = mesh.modifiers.new("Armature", "ARMATURE")
    modifier.object = armature
    mesh.parent = armature
    return counts


def count_tris(obj: bpy.types.Object) -> int:
    return sum(max(0, len(poly.vertices) - 2) for poly in obj.data.polygons)


def rig_model(source: Path, output: Path, gender: str) -> dict[str, object]:
    clear_scene()
    mesh = import_single_mesh(source)
    mesh.name = f"YARTS_{gender}_Simple_Hands_Rigged_Mesh"
    mesh.data.name = f"{mesh.name}_Data"

    bounds = mesh_bounds(mesh)
    height = bounds["z"][1] - bounds["z"][0]
    armature = make_armature(f"YARTS_{gender}_Humanoid_Rig", height)
    counts = bind_mesh_to_armature(mesh, armature, height)

    bpy.ops.object.select_all(action="DESELECT")
    armature.select_set(True)
    mesh.select_set(True)
    bpy.context.view_layer.objects.active = armature
    bpy.ops.export_scene.gltf(filepath=str(output), export_format="GLB", use_selection=True, export_skins=True)

    return {
        "source": str(source),
        "output": str(output),
        "height_m": round(height, 4),
        "mesh": mesh.name,
        "armature": armature.name,
        "bones": len(armature.data.bones),
        "vertices": len(mesh.data.vertices),
        "triangles": count_tris(mesh),
        "weighted_vertices": sum(counts.values()),
        "vertex_group_counts": counts,
    }


def setup_combined_file() -> None:
    clear_scene()
    bpy.ops.import_scene.gltf(filepath=str(MALE_RIGGED_GLB))
    male_objects = list(bpy.context.scene.objects)
    for obj in male_objects:
        if obj.parent is None:
            obj.location.x -= 1.05
        if obj.type == "ARMATURE":
            obj.show_in_front = True
            obj.data.display_type = "STICK"

    bpy.ops.import_scene.gltf(filepath=str(FEMALE_RIGGED_GLB))
    for obj in bpy.context.scene.objects:
        if obj not in male_objects:
            if obj.parent is None:
                obj.location.x += 1.05
            if obj.type == "ARMATURE":
                obj.show_in_front = True
                obj.data.display_type = "STICK"

    bpy.ops.object.light_add(type="AREA", location=(0.0, -3.4, 3.2))
    light = bpy.context.object
    light.name = "Rigged_Reference_Key_Light"
    light.data.energy = 500
    light.data.size = 4.0

    bpy.ops.object.camera_add(location=(0.0, -5.0, 0.88), rotation=(math.radians(90), 0.0, 0.0))
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

    bpy.ops.wm.save_as_mainfile(filepath=str(RIGGED_BLEND))
    bpy.context.scene.render.filepath = str(RIGGED_PREVIEW)
    bpy.ops.render.render(write_still=True)


def verify_export(path: Path) -> dict[str, int | str]:
    clear_scene()
    bpy.ops.import_scene.gltf(filepath=str(path))
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH" and obj.name.startswith("YARTS_")]
    armatures = [obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE" and obj.name.startswith("YARTS_")]
    mesh = meshes[0] if meshes else None
    armature = armatures[0] if armatures else None
    return {
        "path": str(path),
        "meshes": len(meshes),
        "armatures": len(armatures),
        "bones": len(armature.data.bones) if armature else 0,
        "vertex_groups": len(mesh.vertex_groups) if mesh else 0,
    }


def main() -> None:
    SOURCE_DIR.mkdir(parents=True, exist_ok=True)
    results = {
        "male": rig_model(MALE_SOURCE, MALE_RIGGED_GLB, "Male"),
        "female": rig_model(FEMALE_SOURCE, FEMALE_RIGGED_GLB, "Female"),
    }
    results["verify_male"] = verify_export(MALE_RIGGED_GLB)
    results["verify_female"] = verify_export(FEMALE_RIGGED_GLB)
    setup_combined_file()
    results["blend"] = str(RIGGED_BLEND)
    results["preview"] = str(RIGGED_PREVIEW)
    print("YARTS_RIGGED_REFERENCE_STATS " + json.dumps(results, indent=2))


if __name__ == "__main__":
    main()
