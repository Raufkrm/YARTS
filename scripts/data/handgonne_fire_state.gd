class_name HandgonneFireState
extends RefCounted
## The simulation commits one shot; animation and VFX only display its timeline.
const DURATION := 8.0
const SHOT_TIME := 4.5
var elapsed := 0.0
var active := false
var fired := false
var shot_id := -1

func start(reload_state, id: int) -> bool:
	if active or not reload_state.can_fire() or id <= reload_state.last_committed_shot_id: return false
	elapsed = 0.0
	fired = false
	shot_id = id
	active = true
	return true

func advance(delta: float, reload_state) -> bool:
	if not active: return false
	elapsed = minf(DURATION, elapsed + maxf(delta, 0.0))
	var just_fired := false
	if not fired and elapsed >= SHOT_TIME:
		just_fired = reload_state.commit_shot(shot_id)
		fired = just_fired
		if not just_fired:
			active = false
			return false
	if elapsed >= DURATION: active = false
	return just_fired

func stop() -> void:
	active = false

func phase_label() -> String:
	if elapsed < 2.0: return "Raise to underarm aim"
	if elapsed < SHOT_TIME: return "Bring ignition rod to primer"
	if elapsed < 6.0: return "Fire and recoil"
	return "Return to carry"
