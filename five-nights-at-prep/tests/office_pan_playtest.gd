class_name OfficePanPlaytest
extends PowerOutPlaytest

## Live-only observer and mouse-event driver. Never writes yaw or calls pan updates.
## Z/V gentle left/right; Q/E edges; C center; U/J same X, different Y;
## A/D/W are reserved for the production office keyboard shortcuts.
## O out-of-viewport motion; F/G focus exit/return, H mouse-exit signal; P snapshot.
## B sets 10s music-box charge; inherited 1-9 retain outage/clock test shortcuts.
@export_range(0, 120) var test_fps_cap: int = 60
var _saved_max_fps: int = 0
var _previous_pan: float = 0.0
var _previous_velocity: float = 0.0
var _previous_start_time: float = -1.0
var _previous_blocked: bool = false
var _have_sample: bool = false
var _initial_pitch: float = 0.0
var _initial_roll: float = 0.0
var _elapsed_report: float = 0.0
var _observed_frames: int = 0
var _blocked_frames: int = 0
var _max_velocity: float = 0.0
var _max_frame_travel: float = 0.0
var _previous_phase: int = -1
var _previous_busy: bool = false
var _previous_winding: bool = false
var _phase_history: Array[String] = []
var _click_counts: Dictionary = {}

func _ready() -> void:
	super._ready()
	# Observe after Office, AIandSystems and monitor updates, not before them.
	process_priority = 100
	_saved_max_fps = Engine.max_fps
	if test_fps_cap > 0:
		Engine.max_fps = test_fps_cap
	_initial_pitch = office.player.rotation.x
	_initial_roll = office.player.rotation.z
	# Focus/exit shortcuts emit window signals; they do not claim an OS focus test.
	for button: OfficeButton in [office.left_door_button, office.right_door_button, office.left_light_button, office.right_light_button, office.vent_button]:
		button.pressed.connect(_on_office_click.bind(String(button.name)))
	print("PAN TEST: Z/V=gentle, Q/E=edges, C=center, U/J=vertical, O=outside, F/G/H=focus exit/return/mouse exit, B=10s charge, P=snapshot; fps cap=", test_fps_cap)

func _unhandled_key_input(event: InputEvent) -> void:
	super._unhandled_key_input(event)
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key: InputEventKey = event as InputEventKey
	match key.keycode:
		KEY_Z:
			_send_pointer(Vector2(0.40, 0.45), "gentle LEFT")
		KEY_V:
			_send_pointer(Vector2(0.60, 0.45), "gentle RIGHT")
		KEY_Q:
			_send_pointer(Vector2(0.02, 0.45), "edge LEFT")
		KEY_E:
			_send_pointer(Vector2(0.98, 0.45), "edge RIGHT")
		KEY_C:
			_send_pointer(Vector2(0.50, 0.45), "CENTER")
		KEY_U:
			_send_pointer(Vector2(0.60, 0.12), "same X / high Y")
		KEY_J:
			_send_pointer(Vector2(0.60, 0.80), "same X / low Y")
		KEY_O:
			_send_pointer(Vector2(-0.10, 0.45), "OUTSIDE viewport")
		KEY_F:
			get_window().focus_exited.emit()
			print("PAN TEST: synthetic focus-exit signal (not an OS focus switch)")
		KEY_G:
			get_window().focus_entered.emit()
			print("PAN TEST: synthetic focus-return signal (fresh mouse input still required)")
		KEY_H:
			get_window().mouse_exited.emit()
			print("PAN TEST: synthetic window mouse-exit signal")
		KEY_B:
			office.music_box.remaining_seconds = 10.0
		KEY_P:
			_report_pan()

func _send_pointer(fraction: Vector2, label: String) -> void:
	var viewport: Viewport = office.get_viewport()
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = viewport.get_visible_rect().size * fraction
	motion.global_position = motion.position
	motion.relative = motion.position - office._mouse_pos
	# Deliver a mouse-motion event through the viewport's normal input/GUI path.
	viewport.push_input(motion, true)
	print("PAN INPUT: %s x=%.3f y=%.3f yaw=%.3f velocity=%.3f" % [label, fraction.x, fraction.y, office._pan, office._pan_velocity_deg])

func _process(delta: float) -> void:
	var busy: bool = office.camera_system.is_monitor_busy()
	var winding: bool = office.music_box.is_winding()
	var blocked: bool = not office._has_power or office._music_box_frozen or busy or winding or not office._pan_pointer_valid or not office._pan_window_focused
	var reset: bool = not is_equal_approx(_previous_start_time, systems.night_start_time)
	assert(absf(office._pan) <= Office.PAN_MAX_DEG + 0.0001, "Yaw never exceeds the original limits")
	assert(is_equal_approx(office.player.rotation.y, deg_to_rad(office._pan)), "Only the production yaw owner rotates Player")
	assert(is_equal_approx(office.player.rotation.x, _initial_pitch), "Pitch must not change")
	assert(is_equal_approx(office.player.rotation.z, _initial_roll), "Roll must not change")
	assert(absf(office._pan_velocity_deg) <= office.pan_max_speed_deg + 0.001)
	if _have_sample and not reset:
		var travel: float = absf(office._pan - _previous_pan)
		_max_frame_travel = maxf(_max_frame_travel, travel)
		assert(travel <= office.pan_max_speed_deg * delta + 0.03, "No angle snaps")
		if blocked and _previous_blocked:
			assert(is_equal_approx(office._pan, _previous_pan), "Locked office must not pan")
			assert(is_zero_approx(office._pan_velocity_deg), "No stored momentum under a lock")
		elif not blocked and not _previous_blocked and absf(office._pan) < Office.PAN_MAX_DEG - 0.001:
			assert(absf(office._pan_velocity_deg - _previous_velocity) <= maxf(office.pan_acceleration_deg, office.pan_deceleration_deg) * delta + 0.05, "Velocity changes smoothly")
		if not blocked and is_zero_approx(office._pan_velocity_deg) and is_zero_approx(_previous_velocity):
			assert(is_equal_approx(office._pan, _previous_pan), "A stopped camera must never recenter")
	_observed_frames += 1
	if blocked:
		_blocked_frames += 1
	_max_velocity = maxf(_max_velocity, absf(office._pan_velocity_deg))
	_previous_pan = office._pan
	_previous_velocity = office._pan_velocity_deg
	_previous_start_time = systems.night_start_time
	_previous_blocked = blocked
	_have_sample = true
	if int(sequence.phase) != _previous_phase:
		_previous_phase = int(sequence.phase)
		_phase_history.append(String(PowerOutSequence.Phase.keys()[sequence.phase]))
		_report_pan()
	if busy != _previous_busy or winding != _previous_winding:
		print("PAN LOCK CHANGE: monitor_busy=%s winding=%s yaw=%.3f velocity=%.3f" % [busy, winding, office._pan, office._pan_velocity_deg])
	_previous_busy = busy
	_previous_winding = winding
	_elapsed_report += delta
	if _elapsed_report >= 0.5:
		_elapsed_report = 0.0
		_report_pan()

func _on_office_click(button_name: String) -> void:
	_click_counts[button_name] = int(_click_counts.get(button_name, 0)) + 1
	print("PAN OFFICE CLICK: %s yaw=%.3f doors=%s/%s lights=%s/%s vent=%s" % [button_name, office._pan, office.left_closed, office.right_closed, office.left_light_on, office.right_light_on, office.vent_closed])

func _report_pan() -> void:
	var size: Vector2 = office.get_viewport().get_visible_rect().size
	print("PAN SNAPSHOT: size=%s yaw=%.4f velocity=%.4f target=%.4f pointer=%s valid=%s native_focus=%s pan_focus=%s state=%s phase=%s busy=%s flip=%s cam=%d vent_tab=%s wind=%s box=%.3f power=%.3f usage=%d" % [
		size, office._pan, office._pan_velocity_deg, office.get_pan_target_speed(office._mouse_pos.x, size.x), office._mouse_pos, office._pan_pointer_valid, get_window().has_focus(), office._pan_window_focused,
		FNAPSystems.GameState.keys()[systems.game_state], PowerOutSequence.Phase.keys()[sequence.phase], office.camera_system.is_monitor_busy(), office.camera_system._flipping,
		office.camera_system.current_camera_id, office.camera_system._vent_selected, office.music_box.is_winding(), office.music_box.remaining_seconds, systems.office_power, systems.get_usage_bars()])
	print("PAN STATS: frames=%d locked_frames=%d max_speed=%.3f max_frame_travel=%.3f fps=%d phases=%s clicks=%s" % [_observed_frames, _blocked_frames, _max_velocity, _max_frame_travel, Engine.get_frames_per_second(), _phase_history, _click_counts])

func _exit_tree() -> void:
	Engine.max_fps = _saved_max_fps
