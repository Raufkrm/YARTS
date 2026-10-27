class_name CrossbowProp
extends Node3D
## Preview mechanism, independent of ammunition/gameplay authority.

const PALETTE = preload("res://assets/models/weapons/firearms/firearm_vertex_palette.tres")
const WINCH_ORIGIN := Vector3(-0.45, 0.025, -0.23)
const QUIVER_ORIGIN := Vector3(-0.32, -0.025, -0.38)
const BOLT_GRIP := Vector3(-0.19, 0.052, 0)
static var _models: Dictionary = {}
var detail_level := 0
var body: Node3D
var windlass: Node3D
var cranks: Node3D
var bolt: Node3D
var quiver: Node3D
var parts: Dictionary = {}
var draw_amount := 0.0
var winch_attached := false
var bolt_grip := BOLT_GRIP

func _ready() -> void:
	_build()

func _build() -> void:
	if body != null: body.free()
	parts.clear()
	if not _models.has(detail_level):
		var path := "res://assets/models/weapons/crossbow/crossbow_mechanism_lod%d.glb" % detail_level
		if ResourceLoader.exists(path):
			_models[detail_level] = load(path) as PackedScene
		else:
			# Useful immediately after authoring, before the editor's first import.
			var document := GLTFDocument.new()
			var state := GLTFState.new()
			var error := document.append_from_file(path, state)
			assert(error == OK, "Crossbow mechanism export missing")
			var imported := document.generate_scene(state)
			var packed := PackedScene.new()
			packed.pack(imported)
			_models[detail_level] = packed
			imported.free()
	body = _models[detail_level].instantiate()
	add_child(body)
	windlass = Node3D.new(); windlass.name = "Windlass"; body.add_child(windlass)
	windlass.position = WINCH_ORIGIN
	cranks = Node3D.new(); cranks.name = "Cranks"; windlass.add_child(cranks)
	bolt = Node3D.new(); bolt.name = "MovingBolt"; body.add_child(bolt); bolt.position = bolt_grip
	quiver = Node3D.new(); quiver.name = "Quiver"; body.add_child(quiver); quiver.position = QUIVER_ORIGIN
	for candidate in body.find_children("*", "MeshInstance3D", true, false):
		var mesh := candidate as MeshInstance3D
		var key := str(mesh.name)
		parts[key] = mesh
		mesh.material_override = PALETTE
		if key.begins_with("Crank"): mesh.reparent(cranks, true)
		elif key.begins_with("Windlass") or key == "StowedBundle": mesh.reparent(windlass, true)
		elif key.begins_with("Bolt") or key.begins_with("Fletching"): mesh.reparent(bolt, true)
		elif key.begins_with("Quiver") or key == "SpareBolts": mesh.reparent(quiver, true)
	set_draw(0)

func set_detail_level(level: int) -> void:
	detail_level = clampi(level, 0, 2)
	_build()

func set_draw(amount: float) -> void:
	draw_amount = clampf(amount, 0, 1)
	for key in ["String", "Prod"]:
		var mesh := parts.get(key) as MeshInstance3D
		if mesh != null and mesh.get_blend_shape_count() > 0:
			mesh.set_blend_shape_value(0, 1.0 - draw_amount)

func crank_contact(side: String) -> Vector3:
	var local := Vector3(0.075, 0.035, -0.092 if side == "l" else 0.092)
	return cranks.to_global(local)

func set_release(amount: float) -> void:
	# Meshes retain authored coordinates; rotate around their authored pivots.
	for key in ["Nut", "Trigger"]:
		var mesh := parts.get(key) as MeshInstance3D
		if mesh == null: continue
		var pivot := Vector3(-0.17, 0.031, 0) if key == "Nut" else Vector3(-0.15, -0.017, 0)
		var rotation := Basis(Vector3.BACK, amount * (0.60 if key == "Nut" else -0.16))
		mesh.transform = Transform3D(rotation, pivot - rotation * pivot)

func update_ropes(attached: bool) -> void:
	winch_attached = attached
	for sign in [-1, 1]:
		var rope := parts.get("WindlassRope" + str(sign)) as MeshInstance3D
		if rope == null: continue
		rope.visible = attached
		if not attached: continue
		# Affine map the authored rope segment to the axle and moving string hook.
		var a := Vector3(-0.45, 0.025, -(0.23 + sign * 0.070))
		var b := a + Vector3(0.13, -0.025, 0)
		var start := windlass.to_global(Vector3(0, 0, -sign * 0.035))
		var center_x := lerpf(0.12, -0.17, draw_amount)
		var tip_x := 0.19 + 0.022 * (1.0 - draw_amount)
		var hook_fraction := 0.025 / 0.48
		var finish := to_global(Vector3(lerpf(center_x, tip_x, hook_fraction), lerpf(0.052, 0.042, hook_fraction), -sign * 0.025))
		var source_axis := (b - a).normalized()
		var axis := (finish - start).normalized()
		var rotation := Basis(Quaternion(source_axis, axis))
		var factor := (finish - start).length() / (b - a).length() - 1.0
		var stretch := Basis(Vector3.RIGHT + source_axis * source_axis.x * factor, Vector3.UP + source_axis * source_axis.y * factor, Vector3.BACK + source_axis * source_axis.z * factor)
		var basis := rotation * stretch
		rope.global_transform = Transform3D(basis, start - basis * a)

func socket_position(key: String) -> Vector3:
	var sockets := {"support_grip": Vector3(0.08, -0.04, 0), "trigger_grip": Vector3(-0.29, -0.04, 0), "stirrup_contact": Vector3(0.54, -0.02, 0), "windlass_mount": Vector3(-0.53, 0.06, 0)}
	return sockets.get(key, Vector3.ZERO)
