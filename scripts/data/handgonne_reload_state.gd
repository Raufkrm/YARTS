class_name HandgonneReloadState
extends RefCounted
## Simulation state only: independent of meshes, animation events and visibility.

const GOAL_READY := "ready"
const GOAL_PRIME := "prime"
const GOAL_LOAD := "load"
const EMPTY := 0
const CHARGED := 1
const SHOT_ADDED := 2
# Retain the serialized number for migrating saves made before packing was removed.
const PACKED := 3
const SEATED := 4
const PHASES := {
	"HG_R00": {"label": "Recover", "duration": 2.0},
	"HG_R01": {"label": "Reach supplies", "duration": 0.8},
	"HG_R02": {"label": "Pour powder", "duration": 3.2},
	"HG_R03": {"label": "Shot gesture", "duration": 3.0},
	"HG_R05": {"label": "Draw rod", "duration": 3.0},
	"HG_R06": {"label": "Seat load", "duration": 5.0},
	"HG_R07": {"label": "Return rod", "duration": 3.0},
	"HG_R08": {"label": "Prime", "duration": 3.0},
	"HG_R09": {"label": "Recover carry", "duration": 4.0},
}

const FULL_DURATION := 27.0

var ignition_prepared := false
var barrel_load_stage := EMPTY
var rod_stowed := true
var available_ammo := 0
var reserved_ammo := 0
var recovery_complete := false
var carry_recovered := true
var goal := GOAL_READY
var phase_id := ""
var phase_elapsed := 0.0
var speed_snapshot := 1.0
var active := false
var last_committed_shot_id := -1
var barrel_seated: bool:
	get: return barrel_load_stage == SEATED


func _init(ammunition: int = 0) -> void:
	available_ammo = maxi(0, ammunition)


func start_reload(requested_goal: String = GOAL_READY, speed_multiplier: float = 1.0) -> bool:
	if requested_goal not in [GOAL_READY, GOAL_PRIME, GOAL_LOAD]: return false
	if requested_goal == goal and not phase_id.is_empty():
		return resume()
	if not phase_id.is_empty(): interrupt_for_movement()
	goal = requested_goal
	phase_id = ""
	phase_elapsed = 0.0
	speed_snapshot = clampf(speed_multiplier, 0.05, 20.0)
	active = false
	if _goal_complete() and carry_recovered: return false
	_select_next_phase()
	return active


func pause() -> void:
	active = false


func resume() -> bool:
	if phase_id.is_empty():
		_select_next_phase()
	else:
		active = phase_id != "HG_R01" or available_ammo > 0
	return active


func interrupt_for_movement() -> void:
	if not active and phase_id.is_empty(): return
	# Restart only the unfinished gesture; committed priming/load/ammo survive.
	active = false
	phase_id = ""
	phase_elapsed = 0.0
	rod_stowed = true
	carry_recovered = false


func cancel_reload() -> void:
	interrupt_for_movement()
	# A reserved round remains inventory until the charge transfer commits.
	if barrel_load_stage == EMPTY:
		available_ammo += reserved_ammo
		reserved_ammo = 0


func advance(delta: float) -> Array[String]:
	var committed: Array[String] = []
	var remaining := maxf(0.0, delta)
	while active and remaining > 0.0:
		var needed := maxf(0.0, phase_duration() - phase_elapsed)
		var step := minf(remaining, needed)
		phase_elapsed += step
		remaining -= step
		if phase_elapsed + 0.000001 < phase_duration(): break
		var completed := phase_id
		_commit_phase()
		committed.append(completed)
		_select_next_phase()
	return committed


func phase_duration() -> float:
	if phase_id.is_empty(): return 0.0
	return float(PHASES[phase_id].duration) / speed_snapshot


func phase_label() -> String:
	return str(PHASES[phase_id].label) if not phase_id.is_empty() else "Carry"


func can_fire() -> bool:
	return not active and ignition_prepared and barrel_seated and rod_stowed and carry_recovered


func commit_shot(shot_id: int) -> bool:
	if shot_id <= last_committed_shot_id or not can_fire(): return false
	last_committed_shot_id = shot_id
	ignition_prepared = false
	barrel_load_stage = EMPTY
	reserved_ammo = 0
	rod_stowed = true
	recovery_complete = false
	carry_recovered = false
	phase_id = ""
	phase_elapsed = 0.0
	return true


func state_label() -> String:
	if can_fire(): return "Ready"
	if barrel_seated: return "Loaded" if ignition_prepared else "Loaded, unprimed"
	if barrel_load_stage != EMPTY: return "Partly loaded, primed" if ignition_prepared else "Partly loaded"
	return "Primed, unloaded" if ignition_prepared else "Empty, unprimed"


func _goal_complete() -> bool:
	if goal == GOAL_PRIME: return ignition_prepared
	if goal == GOAL_LOAD: return barrel_seated and rod_stowed
	return ignition_prepared and barrel_seated and rod_stowed


func _next_phase() -> String:
	if _goal_complete(): return "" if carry_recovered else "HG_R09"
	if not recovery_complete: return "HG_R00"
	if goal != GOAL_PRIME:
		match barrel_load_stage:
			EMPTY: return "HG_R01" if reserved_ammo == 0 else "HG_R02"
			CHARGED: return "HG_R03"
			SHOT_ADDED, PACKED: return "HG_R05" if rod_stowed else "HG_R06"
			SEATED:
				if not rod_stowed: return "HG_R07"
	if goal != GOAL_LOAD and not ignition_prepared: return "HG_R08"
	return "HG_R09" if not carry_recovered else ""


func _select_next_phase() -> void:
	phase_id = _next_phase()
	phase_elapsed = 0.0
	active = not phase_id.is_empty()
	# Waiting for supplies never loops, loses priming, or creates ammunition.
	if phase_id == "HG_R01" and available_ammo <= 0:
		active = false
	if active: carry_recovered = false


func _commit_phase() -> void:
	match phase_id:
		"HG_R00": recovery_complete = true
		"HG_R08": ignition_prepared = true
		"HG_R01":
			available_ammo -= 1
			reserved_ammo = 1
		"HG_R02":
			reserved_ammo = 0
			barrel_load_stage = CHARGED
		"HG_R03": barrel_load_stage = SHOT_ADDED
		"HG_R05": rod_stowed = false
		"HG_R06": barrel_load_stage = SEATED
		"HG_R07": rod_stowed = true
		"HG_R09": carry_recovered = true


func to_dict() -> Dictionary:
	return {
		"weapon_profile_id": "early_handgonne", "version": 3,
		"ignition_prepared": ignition_prepared, "barrel_load_stage": barrel_load_stage,
		"rod_stowed": rod_stowed, "available_ammo": available_ammo, "reserved_ammo": reserved_ammo,
		"recovery_complete": recovery_complete, "carry_recovered": carry_recovered,
		"goal": goal, "phase_id": phase_id, "phase_elapsed": phase_elapsed,
		"speed_snapshot": speed_snapshot, "active": active,
		"last_committed_shot_id": last_committed_shot_id,
	}


func load_from_dict(data: Dictionary) -> void:
	ignition_prepared = bool(data.get("ignition_prepared", false))
	barrel_load_stage = clampi(int(data.get("barrel_load_stage", EMPTY)), EMPTY, SEATED)
	if barrel_load_stage == PACKED: barrel_load_stage = SHOT_ADDED
	rod_stowed = bool(data.get("rod_stowed", true))
	available_ammo = maxi(0, int(data.get("available_ammo", 0)))
	reserved_ammo = clampi(int(data.get("reserved_ammo", 0)), 0, 1) if barrel_load_stage == EMPTY else 0
	recovery_complete = bool(data.get("recovery_complete", false))
	carry_recovered = bool(data.get("carry_recovered", true))
	goal = str(data.get("goal", GOAL_READY))
	if goal not in [GOAL_READY, GOAL_PRIME, GOAL_LOAD]: goal = GOAL_READY
	speed_snapshot = clampf(float(data.get("speed_snapshot", 1.0)), 0.05, 20.0)
	phase_id = str(data.get("phase_id", ""))
	# V1 packing has no remaining action. A partial early prime in a full reload
	# now waits until the barrel is loaded; completed priming remains untouched.
	var redirected := phase_id == "HG_R04" or (phase_id == "HG_R08"
		and goal == GOAL_READY and not ignition_prepared
		and (not barrel_seated or not rod_stowed))
	if redirected: phase_id = _next_phase()
	if not PHASES.has(phase_id): phase_id = ""
	var elapsed := float(data.get("phase_elapsed", 0.0))
	if int(data.get("version", 1)) < 3 and phase_id in ["HG_R01", "HG_R02"]:
		elapsed *= float(PHASES[phase_id].duration) / (3.0 if phase_id == "HG_R01" else 4.0)
	phase_elapsed = 0.0 if redirected else clampf(elapsed, 0.0, phase_duration())
	active = bool(data.get("active", false)) and not phase_id.is_empty()
	if phase_id == "HG_R01" and available_ammo <= 0: active = false
	last_committed_shot_id = int(data.get("last_committed_shot_id", -1))
