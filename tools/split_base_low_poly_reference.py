# Connection Map:
#   source_male_mesh   -> centered male reference export   transform baked into vertices
#   source_female_mesh -> centered female reference export transform baked into vertices
#   split references are read-only modelling references; no new connected geometry is created.

import json
import shutil
from pathlib import Path

import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[1]
SOURCE_PATH = Path(r"C:\Users\Raufk\Downloads\base_low_poly.glb")
OUT_DIR = ROOT / "assets" / "reference_models"
SOURCE_COPY_PATH = OUT_DIR / "base_low_poly_source.glb"
MALE_GLB_PATH = OUT_DIR / "base_low_poly_male_reference.glb"
FEMALE_GLB_PATH = OUT_DIR / "base_low_poly_female_reference.glb"
BLEND_PATH = OUT_DIR / "base_low_poly_split_references.blend"
PREVIEW_PATH = OUT_DIR / "base_low_poly_split_references_preview.png"


def clear_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()


def bounds_for_mesh(mesh: bpy.types.Mesh) -> dict:
    coords = [vertex.co.copy() for vertex in mesh.vertices]
    return {
        "min": Vector((min(v.x for v in coords), min(v.y for v in coords), min(v.z for v in coords))),
        "max": Vector((max(v.x for v in coords), max(v.y for v in coords), max(v.z for v in coords))),
    }


def centered_reference_from_source(src: bpy.types.Object, name: str) -> bpy.types.Object:
    mesh = src.data.copy()
    mesh.name = name + "_Mesh"

    # Bake any source hierarchy transform into vertex positions, then center on ground.
    for vertex in mesh.vertices:
        vertex.co = src.matrix_world @ vertex.co

    bounds = bounds_for_mesh(mesh)
    center_offset = Vector((
        (bounds["min"].x + bounds["max"].x) * 0.5,
        (bounds["min"].y + bounds["max"].y) * 0.5,
        bounds["min"].z,
    ))
    for vertex in mesh.vertices:
        vertex.co -= center_offset

    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def source_meshes() -> dict:
    meshes = {}
    for obj in bpy.context.scene.objects:
        if obj.type != "MESH":
            continue
        lower_name = obj.name.lower()
        if "man" in lower_name and "woman" not in lower_name:
            meshes["male"] = obj
        elif "woman" in lower_name:
            meshes["female"] = obj
    return meshes


def export_single(obj: bpy.types.Object, path: Path) -> None:
    old_location = obj.location.copy()
    obj.location = (0.0, 0.0, 0.0)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", use_selection=True)
    obj.location = old_location
    bpy.ops.object.select_all(action="DESELECT")


def stats_for(obj: bpy.types.Object) -> dict:
    obj.data.calc_loop_triangles()
    bounds = bounds_for_mesh(obj.data)
    return {
        "name": obj.name,
        "vertices": len(obj.data.vertices),
        "faces": len(obj.data.polygons),
        "triangles": len(obj.data.loop_triangles),
        "height_m": round(bounds["max"].z - bounds["min"].z, 3),
    }


def setup_preview(male: bpy.types.Object, female: bpy.types.Object) -> None:
    male.location.x = -1.05
    female.location.x = 1.05

    light_data = bpy.data.lights.new("Reference_Key_Light", "AREA")
    light_data.energy = 480
    light_data.size = 4.0
    light = bpy.data.objects.new("Reference_Key_Light", light_data)
    light.location = (2.0, -4.0, 3.0)
    bpy.context.scene.collection.objects.link(light)

    camera_data = bpy.data.cameras.new("Reference_Camera")
    camera = bpy.data.objects.new("Reference_Camera", camera_data)
    camera.location = (0.0, -4.8, 0.95)
    direction = Vector((0.0, 0.0, 0.82)) - Vector(camera.location)
    camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    camera_data.lens = 45
    bpy.context.scene.collection.objects.link(camera)
    bpy.context.scene.camera = camera

    bpy.context.scene.render.engine = "BLENDER_EEVEE_NEXT"
    bpy.context.scene.eevee.taa_render_samples = 64
    bpy.context.scene.world.color = (0.18, 0.18, 0.18)
    bpy.context.scene.render.resolution_x = 1400
    bpy.context.scene.render.resolution_y = 1000


def main() -> None:
    if not SOURCE_PATH.exists():
        raise FileNotFoundError(f"Missing source model: {SOURCE_PATH}")

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    shutil.copy2(SOURCE_PATH, SOURCE_COPY_PATH)

    clear_scene()
    bpy.ops.import_scene.gltf(filepath=str(SOURCE_PATH))

    meshes = source_meshes()
    if "male" not in meshes or "female" not in meshes:
        raise RuntimeError(f"Expected male and female meshes, found: {list(meshes.keys())}")

    male = centered_reference_from_source(meshes["male"], "YARTS_Reference_Base_Low_Poly_Male")
    female = centered_reference_from_source(meshes["female"], "YARTS_Reference_Base_Low_Poly_Female")

    for obj in list(bpy.context.scene.objects):
        if obj.name not in (male.name, female.name):
            bpy.data.objects.remove(obj, do_unlink=True)

    export_single(male, MALE_GLB_PATH)
    export_single(female, FEMALE_GLB_PATH)
    setup_preview(male, female)

    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND_PATH))
    bpy.context.scene.render.filepath = str(PREVIEW_PATH)
    bpy.ops.render.render(write_still=True)

    print("YARTS_SPLIT_REFERENCE_STATS", json.dumps({
        "male": stats_for(male),
        "female": stats_for(female),
        "source_copy": str(SOURCE_COPY_PATH),
        "male_glb": str(MALE_GLB_PATH),
        "female_glb": str(FEMALE_GLB_PATH),
        "blend": str(BLEND_PATH),
        "preview": str(PREVIEW_PATH),
    }, indent=2))


if __name__ == "__main__":
    main()
