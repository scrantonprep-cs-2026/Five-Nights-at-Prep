class_name WindingVentPlaytest
extends MusicBoxPlaytest

## Focused QA only. Uses the real office/input, never substitutes an audio asset.
## Inherited: 1=10s charge, 3=reset, 5=6AM, 6=near-zero battery. C=center pointer.
const CAPTURE_DIR = "res://backups/winding_vent_tracker_1793377692/verification"
var _last_signature: String = ""
var _previous_deadline: int = 0
var _captures: Dictionary = {}
var _check_gate_key: bool = false
var _expected_gate: bool = false
var _holds: int = 0
var _was_held: bool = false
var _cadence_intervals: Array[int] = []

func _ready() -> void:
	super._ready()
	process_priority = 100
	# Only this QA scene shortens outage waiting; production values stay untouched.
	sequence.red_light_duration = 0.6
	sequence.blackout_min_duration = 0.4
	sequence.blackout_max_duration = 0.4
	print("WIND/TRACKER QA: exact_audio_present=%s; no substitute stream; C=center" % ResourceLoader.exists(MusicBox.WINDUP_SOUND_PATH))

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.is_pressed() or event.is_echo():
		return
	if event.is_action_pressed(&"office_toggle_vent_gate", false, true):
		var monitor: CameraSystem = office.camera_system
		var target_y: float = Office.VENT_CLOSED_Y if office.vent_closed else Office.VENT_OPEN_Y
		var allowed: bool = office._has_power and not office._music_box_frozen and not monitor.is_monitor_busy() and systems.game_state == FNAPSystems.GameState.NORMAL and systems._night_active and is_equal_approx(office.vent_cover.position.y, target_y)
		_expected_gate = not office.vent_closed if allowed else office.vent_closed
		_check_gate_key = true
		print("TRACKER W INPUT: allowed=%s previous=%s" % [allowed, office.vent_closed])

func _unhandled_key_input(event: InputEvent) -> void:
	super._unhandled_key_input(event)
	if event is InputEventKey and event.is_pressed() and not event.is_echo() and (event as InputEventKey).keycode == KEY_C:
		var motion: InputEventMouseMotion = InputEventMouseMotion.new()
		motion.position = office.get_viewport().get_visible_rect().size * Vector2(0.5, 0.45)
		motion.global_position = motion.position
		motion.relative = motion.position - office._mouse_pos
		office.get_viewport().push_input(motion, true)

func _process(delta: float) -> void:
	super._process(delta)
	var monitor: CameraSystem = office.camera_system
	var tracker: VentTracker = monitor._vent_tracker
	var sound: AudioStreamPlayer = box._windup_sound
	var held: bool = box.is_winding()
	if held and not _was_held:
		_holds += 1
	_was_held = held
	if not held:
		assert(box._next_windup_at_msec == 0 and not sound.playing, "Release/lock/reset must cancel audio without a later callback")
	if sound.stream == null:
		assert(not sound.playing and box._next_windup_at_msec == 0, "Missing exact WAV must stay inactive, not get a substitute")
	else:
		assert(sound.stream is AudioStreamWAV and (sound.stream as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_DISABLED)
		assert(sound.max_polyphony == 1 and is_equal_approx(sound.pitch_scale, 1.0))
		if _previous_deadline > 0 and box._next_windup_at_msec > _previous_deadline:
			var interval: int = box._next_windup_at_msec - _previous_deadline
			assert(interval >= MusicBox.WINDUP_INTERVAL_MSEC, "No catch-up rapid fire")
			_cadence_intervals.append(interval)
			print("WIND AUDIO CADENCE: start_interval=%dms" % interval)
	_previous_deadline = box._next_windup_at_msec
	var cctv_visible: bool = monitor._ipad.visible and not monitor._vent_selected
	assert(monitor._static_overlay.is_visible_in_tree() == cctv_visible)
	assert(monitor._rec_indicator.is_visible_in_tree() == cctv_visible)
	assert(monitor._feed_photo.texture.resource_path == CameraSystem.CAMERA_PHOTO_PATHS[monitor.current_camera_id])
	if _check_gate_key:
		assert(office.vent_closed == _expected_gate, "W must preserve the existing monitor/travel lockouts")
		_check_gate_key = false
		print("TRACKER W RESULT: actual_closed=%s" % office.vent_closed)
	if tracker.is_visible_in_tree():
		assert(tracker._gate_status.text == ("GATE CLOSED" if office.vent_closed else "GATE OPEN"))
		assert(not monitor._static_overlay.is_visible_in_tree() and not monitor._rec_indicator.is_visible_in_tree())
		assert(tracker.get_contact_count() == 0, "No fabricated player-facing contacts")
		_capture_tracker(tracker._gate_status.text)
	var signature: String = "%s/%d/%s/%s/%s/%s/%d/%s/%s/%s" % [held, box._next_windup_at_msec, sound.playing, monitor._ipad.visible, monitor._flipping, monitor._vent_selected, monitor.current_camera_id, tracker._gate_status.text, monitor._switch_burst_remaining > 0.0, systems.game_state]
	if signature != _last_signature:
		_last_signature = signature
		print("WIND/TRACKER STATE: winding=%s audio=%s next=%d gate_closed=%s status=%s page=%s visible=%s flip=%s CAM%d=%s static=%s REC=%s burst=%.3f state=%s usage=%d" % [held, sound.playing, box._next_windup_at_msec, office.vent_closed, tracker._gate_status.text, "VENT" if monitor._vent_selected else "CCTV", monitor._ipad.visible, monitor._flipping, monitor.current_camera_id, monitor._feed_photo.texture.resource_path, monitor._static_overlay.is_visible_in_tree(), monitor._rec_indicator.is_visible_in_tree(), monitor._switch_burst_remaining, FNAPSystems.GameState.keys()[systems.game_state], systems.get_usage_bars()])

func _capture_tracker(status: String) -> void:
	if _captures.has(status):
		return
	_captures[status] = true
	await RenderingServer.frame_post_draw
	var tracker: VentTracker = office.camera_system._vent_tracker
	if not tracker.is_visible_in_tree() or tracker._gate_status.text != status:
		return
	var image: Image = office.get_viewport().get_texture().get_image()
	var directory_error: Error = DirAccess.make_dir_recursive_absolute(CAPTURE_DIR)
	assert(directory_error == OK)
	var path: String = CAPTURE_DIR.path_join(status.to_lower().replace(" ", "_") + ".png")
	var save_error: Error = image.save_png(path)
	assert(save_error == OK)
	print("TRACKER CAPTURE: " + path)

func _exit_tree() -> void:
	print("WIND/TRACKER SUMMARY: accepted_holds=%d measured_audio_intervals_ms=%s (empty when required WAV is absent)" % [_holds, _cadence_intervals])
