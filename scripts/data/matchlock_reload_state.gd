class_name MatchlockReloadState
extends RefCounted
## Retained reload milestones; independent of animation, gender and rendering LOD.
const FULL_DURATION := 28.5
const PHASES := {
	"ML_R00": {"label": "Recover", "duration": 4.0},
	"ML_R02": {"label": "Reach supplies", "duration": 2.0},
	"ML_R03": {"label": "Muzzle load", "duration": 3.5},
	"ML_R04": {"label": "Add shot", "duration": 2.5},
	"ML_R05": {"label": "Draw and align rod", "duration": 3.0},
	"ML_R06": {"label": "Seat load", "duration": 4.0},
	"ML_R07": {"label": "Withdraw and return rod", "duration": 3.0},
	"ML_R08": {"label": "Prime and cover", "duration": 2.5},
	"ML_R10": {"label": "Shoulder", "duration": 4.0},
}
var combat_reload := false
var available_ammo := 3
var reserved_ammo := 0
var barrel_stage := 0
var recovered := false
var match_engaged := true
var match_ready := false
var pan_prepared := false
var cover_open := false
var rod_stowed := true
var carry_recovered := true
var plug_attached := false
var socket_attached := false
var phase_id := ""
var phase_elapsed := 0.0
var active := false
var last_shot_id := -1

func start_reload() -> bool:
	if plug_attached: return false
	if phase_id.is_empty(): _select_next()
	else: active = not (phase_id == "ML_R02" and available_ammo == 0)
	return active

func pause() -> void: active = false

func interrupt_for_movement() -> void:
	active = false
	phase_id = ""
	phase_elapsed = 0
	rod_stowed = true
	carry_recovered = false

func set_plug_attached(attached: bool) -> void:
	plug_attached = attached
	if attached: pause()

func phase_duration() -> float:
	var duration := float(PHASES[phase_id].duration) if PHASES.has(phase_id) else 0.0
	return duration * (1.6 if socket_attached and phase_id in ["ML_R03", "ML_R04", "ML_R05", "ML_R06", "ML_R07"] else 1.0)

func phase_label() -> String:
	if plug_attached: return "Plug bayonet blocks loading"
	return ("Careful · " if socket_attached else "") + str(PHASES[phase_id].label) if PHASES.has(phase_id) else "Loaded carry" if ready_to_aim() else "Carry"

func ready_to_aim() -> bool:
	return not plug_attached and barrel_stage == 3 and rod_stowed and pan_prepared and match_ready and match_engaged

func commit_shot(id: int) -> bool:
	if active or not ready_to_aim() or not cover_open or id <= last_shot_id: return false
	last_shot_id = id
	barrel_stage = 0
	pan_prepared = false
	match_ready = false
	recovered = false
	carry_recovered = false
	return true

func _select_next() -> void:
	if not recovered: phase_id = "ML_R00"
	elif barrel_stage == 0: phase_id = "ML_R02" if reserved_ammo == 0 else "ML_R03"
	elif barrel_stage == 1: phase_id = "ML_R04"
	elif barrel_stage == 2: phase_id = "ML_R05" if rod_stowed else "ML_R06"
	elif not rod_stowed: phase_id = "ML_R07"
	elif not pan_prepared: phase_id = "ML_R08"
	elif not carry_recovered and not combat_reload: phase_id = "ML_R10"
	else: phase_id = ""
	phase_elapsed = 0
	active = not phase_id.is_empty() and not plug_attached
	if phase_id == "ML_R02" and available_ammo <= 0: active = false
	if active: carry_recovered = false

func advance(delta: float) -> void:
	var remaining := maxf(0, delta)
	while active and not plug_attached and remaining > 0:
		var step := minf(remaining, phase_duration() - phase_elapsed)
		phase_elapsed += step
		remaining -= step
		if phase_elapsed + 0.000001 < phase_duration(): break
		match phase_id:
			"ML_R00": recovered = true
			"ML_R02":
				available_ammo -= 1
				reserved_ammo = 1
			"ML_R03":
				barrel_stage = 1
				reserved_ammo = 0
			"ML_R04": barrel_stage = 2
			"ML_R05": rod_stowed = false
			"ML_R06": barrel_stage = 3
			"ML_R07": rod_stowed = true
			"ML_R08":
				pan_prepared = true
				cover_open = false
				match_ready = true
				match_engaged = true
			"ML_R10": carry_recovered = true
		_select_next()

func to_dict() -> Dictionary:
	var result := {"version": 3}
	for field in _fields(): result[field] = get(field)
	return result

func load_from_dict(data: Dictionary) -> void:
	for field in _fields():
		if data.has(field): set(field, data[field])
	if int(data.get("version", 1)) < 3 and phase_id in ["ML_R00", "ML_R10"]:
		phase_elapsed = clampf(phase_elapsed / 1.5, 0.0, 1.0) * phase_duration()
	# Earlier previews removed the cord. Migrate without replaying that gesture.
	match_engaged = true
	if pan_prepared: match_ready = true
	if phase_id in ["ML_R01", "ML_R09"]:
		var was_active := active
		_select_next()
		active = active and was_active
	available_ammo = maxi(0, available_ammo)
	barrel_stage = clampi(barrel_stage, 0, 3)
	reserved_ammo = clampi(reserved_ammo, 0, 1) if barrel_stage == 0 else 0
	if not PHASES.has(phase_id): phase_id = ""
	phase_elapsed = clampf(phase_elapsed, 0, phase_duration())
	active = active and not phase_id.is_empty() and not plug_attached
	if phase_id == "ML_R02" and available_ammo == 0: active = false

func _fields() -> Array[String]:
	return ["combat_reload", "available_ammo", "reserved_ammo", "barrel_stage", "recovered", "match_engaged", "match_ready", "pan_prepared", "cover_open", "rod_stowed", "carry_recovered", "plug_attached", "socket_attached", "phase_id", "phase_elapsed", "active", "last_shot_id"]
