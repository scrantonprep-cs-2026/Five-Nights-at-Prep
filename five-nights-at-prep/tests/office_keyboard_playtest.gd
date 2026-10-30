class_name OfficeKeyboardPlaytest
extends PowerOutPlaytest

## Live input observer; never calls a door/vent toggle itself.
## Shortens ONLY this fixture's outage phases for keyboard-lock coverage.
## Injects OS-style echo events while real test keys are held.
## C/Q/E move the pointer through normal input; P prints results; 1-9 inherited.
const ACTIONS = [&"office_toggle_left_door", &"office_toggle_right_door", &"office_toggle_vent_gate"]
const KEY_LABELS = ["A", "D", "W"]
var _held_keys: Dictionary = {}
var _pending: Array[Dictionary] = []
var _accepted: Dictionary = {"A": 0, "D": 0, "W": 0}
var _blocked: Dictionary = {"A": 0, "D": 0, "W": 0}
var _echo_count: int = 0
var _hud_refresh_wait_frames: int = 0
var _echo_elapsed: float = 0.0
var _phase_history: Array[String] = []
var _last_phase: int = -1
var _last_busy: bool = false
@onready var _meter: PowerMeter = $Office/PowerMeter

func _ready() -> void:
	super._ready()
	process_priority = 100
	sequence.red_light_duration = 1.5
	sequence.blackout_min_duration = 1.0
	sequence.blackout_max_duration = 1.0
	print("KEY TEST: real A/D/W; echoes every 0.12s; test-only RED=1.5s / BLACK=1.0s")

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or event.is_echo():
		return
	for index: int in range(ACTIONS.size()):
		if not event.is_action(ACTIONS[index], true):
			continue
		var label: String = KEY_LABELS[index]
		if not event.is_pressed():
			_held_keys.erase(label)
			return
		_held_keys[label] = event.duplicate()
		# Independent observation of the production movement lock: do not call its helper.
		var heights: Array[float] = [office.left_door.position.y, office.right_door.position.y, office.vent_cover.position.y]
		var targets: Array[float] = [Office.DOOR_CLOSED_Y if office.left_closed else Office.DOOR_OPEN_Y, Office.DOOR_CLOSED_Y if office.right_closed else Office.DOOR_OPEN_Y, Office.VENT_CLOSED_Y if office.vent_closed else Office.VENT_OPEN_Y]
		var settled: bool = is_equal_approx(heights[index], targets[index])
		var allowed: bool = settled and office._has_power and not office._music_box_frozen and not office.camera_system.is_monitor_busy() and systems.game_state == FNAPSystems.GameState.NORMAL and systems._night_active and systems.office_power > 0.0 and systems.get_night_elapsed() < 360.0
		print("MECHANISM INPUT: %s y=%.4f target=%.4f settled=%s allowed=%s" % [label, heights[index], targets[index], settled, allowed])
		var expected: Array[bool] = _flags()
		if allowed:
			expected[index] = not expected[index]
		var context: String = "%s/%s up=%s flip=%s elapsed=%.2f" % [FNAPSystems.GameState.keys()[systems.game_state], PowerOutSequence.Phase.keys()[sequence.phase], office.camera_system.is_monitor_up(), office.camera_system._flipping, systems.get_night_elapsed()]
		_pending.append({"key": label, "index": index, "allowed": allowed, "expected": expected, "context": context})
		return

func _unhandled_key_input(event: InputEvent) -> void:
	super._unhandled_key_input(event)
	if not event is InputEventKey or not event.is_pressed() or event.is_echo():
		return
	var key: InputEventKey = event as InputEventKey
	match key.keycode:
		KEY_C:
			_point(0.50)
		KEY_Q:
			_point(0.02)
		KEY_E:
			_point(0.98)
		KEY_P:
			_snapshot()

func _point(fraction: float) -> void:
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = office.get_viewport().get_visible_rect().size * Vector2(fraction, 0.45)
	motion.global_position = motion.position
	motion.relative = motion.position - office._mouse_pos
	office.get_viewport().push_input(motion, true)

func _flags() -> Array[bool]:
	return [office.left_closed, office.right_closed, office.vent_closed]

func _process(delta: float) -> void:
	for record: Dictionary in _pending:
		# A/D/W may arrive together; a different device is allowed to change too.
		assert(_flags()[int(record.index)] == record.expected[int(record.index)], "Keyboard event must toggle its device exactly once, or not at all under a lock: " + String(record.key))
		if record.allowed:
			_accepted[record.key] = int(_accepted[record.key]) + 1
			var sounds: Array[AudioStreamPlayer3D] = [office.left_sound, office.right_sound, office.vent_sound]
			assert(sounds[int(record.index)].playing, "Existing mechanism sound must start")
			assert(office.button_click_sound.playing, "Existing button sound must start")
		else:
			_blocked[record.key] = int(_blocked[record.key]) + 1
		print("KEY RESULT: %s allowed=%s flags=%s usage=%d HUD=%d at=%s" % [record.key, record.allowed, _flags(), systems.get_usage_bars(), _meter._level, record.context])
	_pending.clear()
	assert(office.left_door_button._active == office.left_closed)
	assert(office.right_door_button._active == office.right_closed)
	assert(office.vent_button._active == office.vent_closed)
	# HUD runs before AIandSystems in the existing scene. Shutdown/night reset
	# can change devices after that refresh; the next frame must catch up.
	if _meter._level == systems.get_usage_bars():
		_hud_refresh_wait_frames = 0
	else:
		_hud_refresh_wait_frames += 1
		assert(_hud_refresh_wait_frames <= 1, "Usage HUD must catch up on its next existing refresh")
	_echo_elapsed += delta
	if _echo_elapsed >= 0.12:
		_echo_elapsed = 0.0
		for label: String in _held_keys:
			var repeat: InputEventKey = _held_keys[label].duplicate() as InputEventKey
			repeat.echo = true
			var before: Array[bool] = _flags()
			office.get_viewport().push_input(repeat, true)
			assert(_flags() == before, "Held-key echoes must never toggle, even after a lock ends")
			_echo_count += 1
	var busy: bool = office.camera_system.is_monitor_busy()
	if int(sequence.phase) != _last_phase:
		_last_phase = int(sequence.phase)
		_phase_history.append(String(PowerOutSequence.Phase.keys()[sequence.phase]))
		_snapshot()
	if busy != _last_busy:
		_snapshot()
	_last_busy = busy

func _snapshot() -> void:
	print("KEY SNAPSHOT: accepted=%s blocked=%s ignored_echoes=%d flags=%s usage=%d HUD=%d state=%s phase=%s phases=%s monitor=%s flip=%s yaw=%.3f power=%.3f" % [_accepted, _blocked, _echo_count, _flags(), systems.get_usage_bars(), _meter._level, FNAPSystems.GameState.keys()[systems.game_state], PowerOutSequence.Phase.keys()[sequence.phase], _phase_history, office.camera_system.is_monitor_up(), office.camera_system._flipping, office._pan, systems.office_power])
	var heights: Array[float] = [office.left_door.position.y, office.right_door.position.y, office.vent_cover.position.y]
	var targets: Array[float] = [Office.DOOR_CLOSED_Y if office.left_closed else Office.DOOR_OPEN_Y, Office.DOOR_CLOSED_Y if office.right_closed else Office.DOOR_OPEN_Y, Office.VENT_CLOSED_Y if office.vent_closed else Office.VENT_OPEN_Y]
	print("MECHANISM SNAPSHOT: heights=%s targets=%s settled=%s" % [heights, targets, [is_equal_approx(heights[0], targets[0]), is_equal_approx(heights[1], targets[1]), is_equal_approx(heights[2], targets[2])]])
