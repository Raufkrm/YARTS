from __future__ import annotations

import json
import math
from pathlib import Path

import bpy
from mathutils import Vector

# Connection Map:
#   tree_trunk_top <-> foliage_layer_bottom        overlap: 0.20-0.85m on Z
#   conifer_foliage_layer <-> next_layer           overlap: 0.55-0.95m on Z
#   trunk_segments(start/end) <-> next_segment     connected at shared endpoints
#   palm_crown <-> palm_fronds_inner_edge          overlap: fronds start inside crown by 0.10m
#   ore_base_top/sides <-> ore_crystals_bottom     crystals start inside rock by 0.03m
#
# Each GLB is exported as a prop scene centered on world origin with ground at Z=0.
# Static parts are intentionally low-poly and use separate material slots/objects.

ROOT = Path(__file__).resolve().parents[1]
ASSET_ROOT = ROOT / "assets" / "models"
FOLIAGE_DIR = ASSET_ROOT / "foliage"
RESOURCE_DIR = ASSET_ROOT / "resources"
PREVIEW_BLEND = ASSET_ROOT / "foliage_resources_preview.blend"
PREVIEW_PNG = ASSET_ROOT / "foliage_resources_preview.png"


def clear_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()


def ensure_dirs() -> None:
    FOLIAGE_DIR.mkdir(parents=True, exist_ok=True)
    RESOURCE_DIR.mkdir(parents=True, exist_ok=True)


def make_material(
    name: str,
    color: tuple[float, float, float, float],
    metallic: float = 0.0,
    roughness: float = 0.72,
    emission: tuple[float, float, float, float] | None = None,
    emission_strength: float = 0.0,
) -> bpy.types.Material:
    material = bpy.data.materials.new(name)
    material.diffuse_color = color
    material.use_nodes = True
    bsdf = material.node_tree.nodes.get("Principled BSDF")
    if bsdf is not None:
        if "Base Color" in bsdf.inputs:
            bsdf.inputs["Base Color"].default_value = color
        if "Metallic" in bsdf.inputs:
            bsdf.inputs["Metallic"].default_value = metallic
        if "Roughness" in bsdf.inputs:
            bsdf.inputs["Roughness"].default_value = roughness
        if emission is not None and "Emission Color" in bsdf.inputs:
            bsdf.inputs["Emission Color"].default_value = emission
        if emission is not None and "Emission Strength" in bsdf.inputs:
            bsdf.inputs["Emission Strength"].default_value = emission_strength
    return material


def material_set() -> dict[str, bpy.types.Material]:
    return {
        "bark": make_material("YARTS_Bark", (0.38, 0.23, 0.12, 1.0), roughness=0.85),
        "dark_bark": make_material("YARTS_Dark_Bark", (0.22, 0.14, 0.08, 1.0), roughness=0.88),
        "conifer_dark": make_material("YARTS_Conifer_Dark", (0.06, 0.24, 0.13, 1.0), roughness=0.82),
        "conifer_mid": make_material("YARTS_Conifer_Mid", (0.09, 0.36, 0.17, 1.0), roughness=0.80),
        "conifer_blue": make_material("YARTS_Conifer_Blue", (0.11, 0.28, 0.26, 1.0), roughness=0.82),
        "leaf_light": make_material("YARTS_Leaf_Light", (0.22, 0.55, 0.18, 1.0), roughness=0.78),
        "leaf_mid": make_material("YARTS_Leaf_Mid", (0.15, 0.42, 0.14, 1.0), roughness=0.80),
        "leaf_dark": make_material("YARTS_Leaf_Dark", (0.09, 0.32, 0.12, 1.0), roughness=0.82),
        "leaf_warm": make_material("YARTS_Leaf_Warm", (0.42, 0.48, 0.16, 1.0), roughness=0.80),
        "palm_leaf": make_material("YARTS_Palm_Leaf", (0.08, 0.42, 0.15, 1.0), roughness=0.78),
        "palm_light": make_material("YARTS_Palm_Light", (0.20, 0.58, 0.20, 1.0), roughness=0.76),
        "snow": make_material("YARTS_Snow", (0.94, 0.96, 0.97, 1.0), roughness=0.58),
        "rock": make_material("YARTS_Rock", (0.25, 0.25, 0.24, 1.0), roughness=0.88),
        "rock_dark": make_material("YARTS_Dark_Rock", (0.12, 0.12, 0.12, 1.0), roughness=0.92),
        "copper": make_material("YARTS_Copper_Ore", (0.90, 0.38, 0.16, 1.0), metallic=0.85, roughness=0.38),
        "tin": make_material("YARTS_Tin_Ore", (0.68, 0.70, 0.72, 1.0), metallic=0.70, roughness=0.36),
        "coal": make_material("YARTS_Coal_Ore", (0.025, 0.025, 0.025, 1.0), roughness=0.96),
        "iron": make_material("YARTS_Iron_Ore", (0.52, 0.20, 0.10, 1.0), metallic=0.55, roughness=0.42),
        "silver": make_material("YARTS_Silver_Ore", (0.86, 0.88, 0.87, 1.0), metallic=0.90, roughness=0.25),
        "gold": make_material("YARTS_Gold_Ore", (1.00, 0.68, 0.08, 1.0), metallic=0.95, roughness=0.23),
        "uranium": make_material(
            "YARTS_Uranium_Ore",
            (0.22, 0.85, 0.12, 1.0),
            metallic=0.45,
            roughness=0.32,
            emission=(0.10, 0.75, 0.05, 1.0),
            emission_strength=0.45,
        ),
    }


def assign_material(obj: bpy.types.Object, material: bpy.types.Material) -> bpy.types.Object:
    obj.data.materials.append(material)
    return obj


def finalize_object(obj: bpy.types.Object, shade_flat: bool = True) -> bpy.types.Object:
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    if shade_flat:
        bpy.ops.object.shade_flat()
    return obj


def make_cylinder(
    name: str,
    radius: float,
    depth: float,
    location: Vector,
    material: bpy.types.Material,
    vertices: int = 7,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.data.name = f"{name}_Mesh"
    assign_material(obj, material)
    return finalize_object(obj)


def make_cone(
    name: str,
    radius1: float,
    radius2: float,
    depth: float,
    location: Vector,
    material: bpy.types.Material,
    vertices: int = 8,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=radius1, radius2=radius2, depth=depth, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.data.name = f"{name}_Mesh"
    assign_material(obj, material)
    return finalize_object(obj)


def make_ellipsoid(
    name: str,
    location: Vector,
    scale: Vector,
    material: bpy.types.Material,
    subdivisions: int = 1,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdivisions, radius=1.0, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.data.name = f"{name}_Mesh"
    obj.scale = scale
    assign_material(obj, material)
    return finalize_object(obj)


def make_frustum_between(
    name: str,
    start: Vector,
    end: Vector,
    radius_start: float,
    radius_end: float,
    material: bpy.types.Material,
    sides: int = 7,
) -> bpy.types.Object:
    direction = end - start
    length = direction.length
    if length <= 0.0001:
        raise ValueError(f"{name} has no length")
    forward = direction.normalized()
    world_up = Vector((0.0, 0.0, 1.0))
    if abs(forward.dot(world_up)) > 0.96:
        world_up = Vector((0.0, 1.0, 0.0))
    right = forward.cross(world_up).normalized()
    up = right.cross(forward).normalized()

    verts: list[tuple[float, float, float]] = []
    for center, radius in ((start, radius_start), (end, radius_end)):
        for i in range(sides):
            angle = math.tau * i / sides
            point = center + right * math.cos(angle) * radius + up * math.sin(angle) * radius
            verts.append((point.x, point.y, point.z))
    faces: list[tuple[int, ...]] = []
    for i in range(sides):
        faces.append((i, (i + 1) % sides, sides + ((i + 1) % sides), sides + i))
    faces.append(tuple(range(sides - 1, -1, -1)))
    faces.append(tuple(range(sides, sides * 2)))

    mesh = bpy.data.meshes.new(f"{name}_Mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    assign_material(obj, material)
    return obj


def make_leaf_plane(
    name: str,
    base: Vector,
    tip: Vector,
    width: float,
    material: bpy.types.Material,
) -> bpy.types.Object:
    direction = tip - base
    if direction.length <= 0.0001:
        raise ValueError(f"{name} has no length")
    forward = direction.normalized()
    right = forward.cross(Vector((0.0, 0.0, 1.0)))
    if right.length < 0.001:
        right = Vector((1.0, 0.0, 0.0))
    right.normalize()
    mid = base.lerp(tip, 0.50)
    verts = [
        tuple(base),
        tuple(mid + right * width),
        tuple(tip),
        tuple(mid - right * width),
    ]
    faces = [(0, 1, 2), (0, 2, 3)]
    mesh = bpy.data.meshes.new(f"{name}_Mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    assign_material(obj, material)
    return obj


def make_rock(
    name: str,
    radius_x: float,
    radius_y: float,
    height: float,
    material: bpy.types.Material,
    sides: int = 9,
    offset: Vector = Vector((0.0, 0.0, 0.0)),
) -> bpy.types.Object:
    verts: list[tuple[float, float, float]] = []
    lower: list[int] = []
    upper: list[int] = []
    for i in range(sides):
        angle = math.tau * i / sides
        rough = 0.86 + 0.22 * math.sin(i * 1.91 + radius_x * 7.0)
        x = math.cos(angle) * radius_x * rough
        y = math.sin(angle) * radius_y * (0.92 + 0.18 * math.cos(i * 2.37))
        lower.append(len(verts))
        verts.append((offset.x + x, offset.y + y, offset.z + 0.0))
    for i in range(sides):
        angle = math.tau * i / sides
        rough = 0.70 + 0.20 * math.cos(i * 2.13 + radius_y * 5.0)
        x = math.cos(angle) * radius_x * rough
        y = math.sin(angle) * radius_y * (0.76 + 0.18 * math.sin(i * 2.70))
        upper.append(len(verts))
        verts.append((offset.x + x, offset.y + y, offset.z + height * (0.72 + 0.22 * math.sin(i * 0.9))))
    top_center = len(verts)
    verts.append((offset.x, offset.y, offset.z + height))

    faces: list[tuple[int, ...]] = []
    faces.append(tuple(reversed(lower)))
    for i in range(sides):
        faces.append((lower[i], lower[(i + 1) % sides], upper[(i + 1) % sides], upper[i]))
        faces.append((upper[i], upper[(i + 1) % sides], top_center))

    mesh = bpy.data.meshes.new(f"{name}_Mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    assign_material(obj, material)
    return obj


def make_crystal(
    name: str,
    base: Vector,
    radius: float,
    height: float,
    material: bpy.types.Material,
    sides: int = 6,
) -> bpy.types.Object:
    verts: list[tuple[float, float, float]] = []
    for i in range(sides):
        angle = math.tau * i / sides
        verts.append((base.x + math.cos(angle) * radius, base.y + math.sin(angle) * radius, base.z))
    top = len(verts)
    verts.append((base.x, base.y, base.z + height))
    faces: list[tuple[int, ...]] = [tuple(reversed(range(sides)))]
    for i in range(sides):
        faces.append((i, (i + 1) % sides, top))
    mesh = bpy.data.meshes.new(f"{name}_Mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    assign_material(obj, material)
    return obj


def build_conifer(asset_name: str, origin: Vector, variant: int, snow: bool, materials: dict[str, bpy.types.Material]) -> list[bpy.types.Object]:
    objects: list[bpy.types.Object] = []
    trunk_height = [2.2, 2.7, 2.0][variant]
    total_height = [6.2, 7.4, 5.4][variant]
    trunk_radius = [0.18, 0.16, 0.22][variant]
    foliage_material = materials["snow"] if snow else [materials["conifer_mid"], materials["conifer_blue"], materials["conifer_dark"]][variant]

    objects.append(make_cylinder(f"{asset_name}_trunk", trunk_radius, trunk_height, origin + Vector((0.0, 0.0, trunk_height * 0.5)), materials["bark"], vertices=7))
    layer_count = [4, 5, 3][variant]
    canopy_bottom = trunk_height * 0.42
    canopy_top = total_height * 0.96
    for i in range(layer_count):
        t = i / max(1, layer_count - 1)
        depth = [2.0, 1.85, 2.1][variant] * (1.0 - t * 0.08)
        layer_z = canopy_bottom + t * max(0.1, canopy_top - canopy_bottom - depth)
        radius = [1.05, 0.95, 1.28][variant] * (1.0 - t * 0.58)
        x_shift = 0.0
        y_shift = 0.0
        if variant == 2:
            x_shift = 0.14 * math.sin(i * 1.7)
            y_shift = -0.10 * math.cos(i * 1.2)
        cone = make_cone(
            f"{asset_name}_needles_{i + 1}",
            radius,
            0.05,
            depth,
            origin + Vector((x_shift, y_shift, layer_z + depth * 0.5)),
            foliage_material,
            vertices=9,
        )
        objects.append(cone)
    return objects


def build_leaf_tree(asset_name: str, origin: Vector, variant: int, snow: bool, materials: dict[str, bpy.types.Material]) -> list[bpy.types.Object]:
    objects: list[bpy.types.Object] = []
    trunk_height = [2.5, 3.1, 2.2][variant]
    trunk_radius = [0.18, 0.14, 0.23][variant]
    objects.append(make_cylinder(f"{asset_name}_trunk", trunk_radius, trunk_height, origin + Vector((0.0, 0.0, trunk_height * 0.5)), materials["bark"], vertices=7))

    branch_specs = [
        (Vector((0.0, 0.0, trunk_height * 0.72)), Vector((0.42, -0.10, trunk_height + 0.50)), 0.055),
        (Vector((0.0, 0.0, trunk_height * 0.82)), Vector((-0.36, 0.12, trunk_height + 0.40)), 0.050),
    ]
    if variant == 2:
        branch_specs.append((Vector((0.0, 0.0, trunk_height * 0.70)), Vector((0.10, 0.46, trunk_height + 0.32)), 0.050))
    for i, (start, end, radius) in enumerate(branch_specs):
        objects.append(make_frustum_between(f"{asset_name}_branch_{i + 1}", origin + start, origin + end, radius, radius * 0.55, materials["bark"], sides=6))

    if variant == 0:
        canopy_specs = [
            (Vector((0.0, 0.0, 3.25)), Vector((1.15, 1.00, 0.95)), materials["leaf_mid"]),
            (Vector((0.55, -0.10, 3.05)), Vector((0.75, 0.68, 0.65)), materials["leaf_light"]),
            (Vector((-0.48, 0.18, 3.05)), Vector((0.72, 0.70, 0.62)), materials["leaf_dark"]),
        ]
    elif variant == 1:
        canopy_specs = [
            (Vector((0.0, 0.0, 3.75)), Vector((0.92, 0.80, 1.15)), materials["leaf_light"]),
            (Vector((0.55, 0.04, 3.45)), Vector((0.55, 0.52, 0.62)), materials["leaf_mid"]),
            (Vector((-0.52, -0.05, 3.42)), Vector((0.55, 0.50, 0.58)), materials["leaf_mid"]),
        ]
    else:
        canopy_specs = [
            (Vector((0.0, 0.0, 3.00)), Vector((1.28, 0.88, 0.72)), materials["leaf_warm"]),
            (Vector((0.20, -0.18, 3.34)), Vector((0.85, 0.70, 0.66)), materials["leaf_mid"]),
            (Vector((-0.58, 0.18, 2.95)), Vector((0.70, 0.65, 0.56)), materials["leaf_dark"]),
        ]
    for i, (loc, scale, mat) in enumerate(canopy_specs):
        canopy_material = materials["snow"] if snow else mat
        objects.append(make_ellipsoid(f"{asset_name}_canopy_{i + 1}", origin + loc, scale, canopy_material, subdivisions=1))
    return objects


def build_palm(asset_name: str, origin: Vector, variant: int, materials: dict[str, bpy.types.Material]) -> list[bpy.types.Object]:
    objects: list[bpy.types.Object] = []
    if variant == 0:
        points = [origin + Vector((0.0, 0.0, 0.0)), origin + Vector((0.05, 0.0, 2.0)), origin + Vector((0.0, 0.0, 4.3))]
        crown = origin + Vector((0.0, 0.0, 4.45))
    elif variant == 1:
        points = [origin + Vector((0.0, 0.0, 0.0)), origin + Vector((0.30, 0.05, 1.8)), origin + Vector((0.72, 0.10, 4.0))]
        crown = origin + Vector((0.75, 0.10, 4.12))
    else:
        points = [origin + Vector((0.0, 0.0, 0.0)), origin + Vector((-0.05, -0.05, 1.45)), origin + Vector((0.12, -0.12, 3.2))]
        crown = origin + Vector((0.12, -0.12, 3.34))
    for i in range(len(points) - 1):
        radius_a = 0.18 - i * 0.025
        radius_b = 0.15 - i * 0.025
        objects.append(make_frustum_between(f"{asset_name}_trunk_segment_{i + 1}", points[i], points[i + 1], radius_a, radius_b, materials["dark_bark"], sides=7))
    objects.append(make_ellipsoid(f"{asset_name}_crown", crown, Vector((0.28, 0.24, 0.22)), materials["bark"], subdivisions=1))

    frond_count = [7, 8, 6][variant]
    for i in range(frond_count):
        angle = math.tau * i / frond_count + [0.0, 0.18, -0.25][variant]
        length = [1.55, 1.75, 1.25][variant] * (0.90 + 0.16 * math.sin(i * 1.6))
        tip = crown + Vector((math.cos(angle) * length, math.sin(angle) * length, -0.45 - 0.12 * math.cos(i)))
        base = crown + Vector((math.cos(angle) * 0.12, math.sin(angle) * 0.12, -0.02))
        width = [0.28, 0.32, 0.24][variant]
        objects.append(make_leaf_plane(f"{asset_name}_frond_{i + 1}", base, tip, width, materials["palm_leaf" if i % 2 else "palm_light"]))

    if variant != 2:
        for i, angle in enumerate((0.4, 2.5, 4.6)):
            objects.append(make_ellipsoid(f"{asset_name}_coconut_{i + 1}", crown + Vector((math.cos(angle) * 0.20, math.sin(angle) * 0.20, -0.20)), Vector((0.10, 0.10, 0.10)), materials["dark_bark"], subdivisions=1))
    return objects


def build_ore(asset_name: str, origin: Vector, ore_key: str, materials: dict[str, bpy.types.Material]) -> list[bpy.types.Object]:
    objects: list[bpy.types.Object] = []
    rock_mat = materials["rock_dark"] if ore_key in {"coal", "uranium"} else materials["rock"]
    ore_mat = materials[ore_key]
    objects.append(make_rock(f"{asset_name}_rock_base", 0.72, 0.52, 0.42, rock_mat, sides=9, offset=origin))

    if ore_key == "coal":
        coal_offsets = [(-0.25, -0.05, 0.25), (0.12, 0.08, 0.32), (0.34, -0.16, 0.20), (-0.08, 0.22, 0.28)]
        for i, (x, y, z) in enumerate(coal_offsets):
            objects.append(make_rock(f"{asset_name}_coal_chunk_{i + 1}", 0.18, 0.13, 0.18, ore_mat, sides=7, offset=origin + Vector((x, y, z))))
        return objects

    crystal_specs = [
        (Vector((-0.24, -0.05, 0.28)), 0.08, 0.36),
        (Vector((0.04, 0.12, 0.30)), 0.07, 0.45),
        (Vector((0.28, -0.14, 0.25)), 0.075, 0.34),
    ]
    if ore_key in {"gold", "silver", "uranium"}:
        crystal_specs.append((Vector((-0.02, -0.24, 0.25)), 0.06, 0.30))
    for i, (loc, radius, height) in enumerate(crystal_specs):
        objects.append(make_crystal(f"{asset_name}_ore_crystal_{i + 1}", origin + loc, radius, height, ore_mat, sides=6))

    vein_specs = [
        (Vector((-0.42, 0.10, 0.30)), Vector((-0.05, 0.02, 0.42)), 0.025),
        (Vector((0.10, -0.22, 0.25)), Vector((0.45, -0.08, 0.36)), 0.022),
    ]
    for i, (start, end, radius) in enumerate(vein_specs):
        objects.append(make_frustum_between(f"{asset_name}_ore_vein_{i + 1}", origin + start, origin + end, radius, radius * 0.75, ore_mat, sides=5))
    return objects


def count_asset_stats(objects: list[bpy.types.Object]) -> dict[str, int]:
    meshes = [obj for obj in objects if obj.type == "MESH"]
    vertices = sum(len(obj.data.vertices) for obj in meshes)
    triangles = sum(sum(max(0, len(poly.vertices) - 2) for poly in obj.data.polygons) for obj in meshes)
    return {"objects": len(meshes), "vertices": vertices, "triangles": triangles}


def export_asset(objects: list[bpy.types.Object], path: Path) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", use_selection=True)


def remove_objects(objects: list[bpy.types.Object]) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.ops.object.delete()


def build_asset_specs(materials: dict[str, bpy.types.Material]) -> list[dict[str, object]]:
    specs: list[dict[str, object]] = []
    for index in range(3):
        specs.append({
            "name": f"conifer_{index + 1:02d}",
            "path": FOLIAGE_DIR / f"conifer_{index + 1:02d}.glb",
            "builder": lambda name, origin, idx=index: build_conifer(name, origin, idx, False, materials),
        })
        specs.append({
            "name": f"conifer_{index + 1:02d}_snow",
            "path": FOLIAGE_DIR / f"conifer_{index + 1:02d}_snow.glb",
            "builder": lambda name, origin, idx=index: build_conifer(name, origin, idx, True, materials),
        })
    for index in range(3):
        specs.append({
            "name": f"leaf_tree_{index + 1:02d}",
            "path": FOLIAGE_DIR / f"leaf_tree_{index + 1:02d}.glb",
            "builder": lambda name, origin, idx=index: build_leaf_tree(name, origin, idx, False, materials),
        })
        specs.append({
            "name": f"leaf_tree_{index + 1:02d}_snow",
            "path": FOLIAGE_DIR / f"leaf_tree_{index + 1:02d}_snow.glb",
            "builder": lambda name, origin, idx=index: build_leaf_tree(name, origin, idx, True, materials),
        })
    for index in range(3):
        specs.append({
            "name": f"palm_tree_{index + 1:02d}",
            "path": FOLIAGE_DIR / f"palm_tree_{index + 1:02d}.glb",
            "builder": lambda name, origin, idx=index: build_palm(name, origin, idx, materials),
        })
    for ore_name in ("copper", "tin", "coal", "iron", "silver", "gold", "uranium"):
        specs.append({
            "name": f"ore_{ore_name}",
            "path": RESOURCE_DIR / f"ore_{ore_name}.glb",
            "builder": lambda name, origin, key=ore_name: build_ore(name, origin, key, materials),
        })
    return specs


def export_all_assets(specs: list[dict[str, object]]) -> dict[str, dict[str, int | str]]:
    stats: dict[str, dict[str, int | str]] = {}
    for spec in specs:
        clear_scene()
        materials = material_set()
        # Rebuild the spec with the fresh material set to keep exported GLBs self-contained.
        fresh_specs = build_asset_specs(materials)
        fresh = next(item for item in fresh_specs if item["name"] == spec["name"])
        objects = fresh["builder"](str(fresh["name"]), Vector((0.0, 0.0, 0.0)))
        export_asset(objects, fresh["path"])
        item_stats = count_asset_stats(objects)
        item_stats["path"] = str(fresh["path"])
        stats[str(fresh["name"])] = item_stats
    return stats


def create_preview_scene(specs: list[dict[str, object]], materials: dict[str, bpy.types.Material]) -> None:
    clear_scene()
    spacing_x = 3.2
    spacing_y = 3.2
    for index, spec in enumerate(specs):
        row = index // 6
        col = index % 6
        origin = Vector(((col - 2.5) * spacing_x, (0.1 - row) * spacing_y, 0.0))
        spec["builder"](str(spec["name"]), origin)

    bpy.ops.object.light_add(type="AREA", location=(0.0, -9.5, 12.0))
    light = bpy.context.object
    light.name = "Asset_Preview_Key_Light"
    light.data.energy = 900
    light.data.size = 8.0

    bpy.ops.object.camera_add(location=(0.0, -23.0, 12.0), rotation=(math.radians(62), 0.0, 0.0))
    camera = bpy.context.object
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 25.0
    bpy.context.scene.camera = camera

    bpy.context.scene.render.engine = "CYCLES"
    bpy.context.scene.cycles.samples = 64
    bpy.context.scene.render.resolution_x = 1800
    bpy.context.scene.render.resolution_y = 1200
    bpy.context.scene.view_settings.view_transform = "Filmic"
    bpy.context.scene.view_settings.look = "Medium High Contrast"
    bpy.ops.wm.save_as_mainfile(filepath=str(PREVIEW_BLEND))
    bpy.context.scene.render.filepath = str(PREVIEW_PNG)
    bpy.ops.render.render(write_still=True)


def verify_exports(paths: list[Path]) -> dict[str, dict[str, int]]:
    results: dict[str, dict[str, int]] = {}
    for path in paths:
        clear_scene()
        bpy.ops.import_scene.gltf(filepath=str(path))
        meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH" and not obj.name.startswith(("Cube", "Icosphere"))]
        results[path.name] = {
            "meshes": len(meshes),
            "vertices": sum(len(obj.data.vertices) for obj in meshes),
            "triangles": sum(sum(max(0, len(poly.vertices) - 2) for poly in obj.data.polygons) for obj in meshes),
        }
    return results


def main() -> None:
    ensure_dirs()
    clear_scene()
    materials = material_set()
    specs = build_asset_specs(materials)
    stats = export_all_assets(specs)

    clear_scene()
    materials = material_set()
    preview_specs = build_asset_specs(materials)
    create_preview_scene(preview_specs, materials)

    paths = [Path(str(spec["path"])) for spec in specs]
    verification = verify_exports(paths)
    print("YARTS_FOLIAGE_RESOURCE_ASSET_STATS " + json.dumps({
        "asset_count": len(specs),
        "stats": stats,
        "verification": verification,
        "preview_blend": str(PREVIEW_BLEND),
        "preview_png": str(PREVIEW_PNG),
    }, indent=2))


if __name__ == "__main__":
    main()
