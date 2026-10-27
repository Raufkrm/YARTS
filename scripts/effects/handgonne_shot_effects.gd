class_name HandgonneShotEffects
extends Node3D
## One bounded shared billboard batch, rather than a particle node per soldier.
const MAX_SHOTS := 24
const CARDS_PER_SHOT := 8
const LIFETIME := 2.8
var bursts: Array[Dictionary] = []
var batch: MultiMeshInstance3D
var emitted_count := 0
var playback_speed := 1.0

func _ready() -> void:
	batch = MultiMeshInstance3D.new()
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mesh := QuadMesh.new()
	mesh.size = Vector2.ONE
	var material := ShaderMaterial.new()
	material.shader = preload("res://assets/shaders/handgonne_shot.gdshader")
	mesh.material = material
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = mesh
	multimesh.instance_count = MAX_SHOTS * CARDS_PER_SHOT
	multimesh.visible_instance_count = 0
	batch.multimesh = multimesh
	add_child(batch)
	set_process(false)

func emit_shot(muzzle: Vector3, primer: Vector3, direction: Vector3, level: int, initial_age: float = 0.0) -> void:
	emitted_count += 1
	if initial_age >= LIFETIME: return
	if bursts.size() >= MAX_SHOTS: bursts.pop_front()
	bursts.append({"muzzle": muzzle, "primer": primer, "axis": direction.normalized(), "age": maxf(0, initial_age), "lod": clampi(level, 0, 2), "seed": float(emitted_count) * 1.71})
	set_process(true)
	_refresh()

func clear() -> void:
	bursts.clear()
	if batch != null: batch.multimesh.visible_instance_count = 0
	set_process(false)

func _process(delta: float) -> void:
	advance(delta * playback_speed)

func advance(delta: float) -> void:
	for burst in bursts: burst.age += maxf(0, delta)
	bursts = bursts.filter(func(burst): return burst.age < LIFETIME)
	_refresh()
	if bursts.is_empty(): set_process(false)

func _card(index: int, center: Vector3, size: float, kind: float, opacity: float, age: float, seed: float) -> void:
	batch.multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * size), to_local(center)))
	batch.multimesh.set_instance_custom_data(index, Color(age / LIFETIME, kind, seed, opacity))

func _refresh() -> void:
	if batch == null: return
	var card := 0
	for burst in bursts:
		var age: float = burst.age
		var level: int = burst.lod
		var count: int = [6, 3, 1][level]
		if level < 2 and age < 0.12:
			_card(card, burst.muzzle + burst.axis * 0.11, 0.25 + age, 1, 1.0 - age / 0.12, age, burst.seed)
			card += 1
			if level == 0:
				_card(card, burst.primer, 0.075, 1, 1.0 - age / 0.12, age, burst.seed)
				card += 1
		for i in range(count):
			var fraction := float(i) / maxi(1, count - 1)
			var distance := age * (0.30 + fraction * 0.55)
			var center: Vector3 = burst.muzzle + burst.axis * distance + Vector3(sin(burst.seed + i) * age * 0.065, age * (0.11 + fraction * 0.05), 0)
			var fade := (1.0 - age / LIFETIME) * minf(1.0, (age + 0.04) * 9.0)
			_card(card, center, 0.15 + age * (0.24 + fraction * 0.14), 0, fade * (0.31 if level == 0 else 0.44), age, burst.seed + i)
			card += 1
	batch.multimesh.visible_instance_count = card
