class_name CCTVFeedPlaytest
extends OfficeKeyboardPlaytest

## Live-only, read-only CCTV observer. Mouse/keys drive the real office.
## Inherits keyboard/echo/HUD checks and test-only short outage phases.
## B = 10s box charge, K = 1s box charge, P = CCTV snapshot; 1-9 inherited.
## GPU readback is QA-only; never used by the production camera/effect.
@export var sample_rendered_grain: bool = true
## Override in task-specific fixtures so older verification captures stay intact.
@export var capture_directory: String = "res://backups/cctv_static_bursts_1793337427/verification"
var _last_cctv_signature: String = ""
var _noise_elapsed: float = 0.0
var _capture_pending: bool = false
var _previous_samples: Dictionary = {}
var _moving_samples: Dictionary = {}
var _max_noise_delta: float = 0.0
var _seen_cameras: Array[int] = []
var _old_pan: float = 0.0
var _old_busy: bool = false
var _old_start: float = -1.0
var _was_winding: bool = false
var _office_clicks: Dictionary = {}

func _ready() -> void:
	super._ready()
	for button: OfficeButton in [office.left_door_button, office.right_door_button, office.vent_button, office.left_light_button, office.right_light_button]:
		button.pressed.connect(_on_office_click.bind(String(button.name)))
	print("CCTV TEST: real GUI clicks; GPU grain sampling; B=10s/K=1s box charge; P=report")

func _unhandled_key_input(event: InputEvent) -> void:
	super._unhandled_key_input(event)
	if not event is InputEventKey or not event.is_pressed() or event.is_echo():
		return
	var key: InputEventKey = event as InputEventKey
	match key.keycode:
		KEY_B:
			office.music_box.remaining_seconds = 10.0
		KEY_K:
			office.music_box.remaining_seconds = 1.0
		KEY_P:
			_report_cctv()

func _process(delta: float) -> void:
	super._process(delta)
	var monitor: CameraSystem = office.camera_system
	var visible_feed: bool = monitor._ipad.visible and not monitor._vent_selected
	assert(monitor._static_overlay.is_visible_in_tree() == visible_feed, "Static must never leak into office/flips/vent/outcomes")
	assert(monitor._rec_indicator.is_visible_in_tree() == visible_feed)
	var expected_path: String = String(CameraSystem.CAMERA_PHOTO_PATHS.get(monitor.current_camera_id, ""))
	if expected_path.is_empty():
		assert(monitor._feed_photo.texture == null)
		assert(monitor._feed_label.text.contains("TEMPORARY CCTV FEED"))
	else:
		assert(monitor._feed_photo.texture != null)
		assert(monitor._feed_photo.texture.resource_path == expected_path)
		assert(monitor._feed_photo.is_visible_in_tree() == visible_feed)
		var native_size: Vector2 = monitor._feed_photo.texture.get_size()
		assert(is_equal_approx(monitor._feed_photo.size.x / native_size.x, monitor._feed_photo.size.y / native_size.y))
		var photo_rect: Rect2 = Rect2(monitor._feed_photo.position, monitor._feed_photo.size)
		assert(photo_rect.position.x <= 0.001 and photo_rect.position.y <= 0.001)
		assert(photo_rect.end.x >= monitor._feed.size.x - 0.001 and photo_rect.end.y >= monitor._feed.size.y - 0.001)
	assert(monitor._feed_photo.get_index() < monitor._static_overlay.get_index())
	assert(monitor._feed.get_index() < monitor._map_area.get_index())
	assert(not monitor._rec_indicator.get_global_rect().intersects(monitor._close_button.get_global_rect()))
	var busy: bool = monitor.is_monitor_busy()
	if busy and _old_busy and is_equal_approx(_old_start, systems.night_start_time):
		assert(is_equal_approx(office._pan, _old_pan), "Panning must stay frozen through both flips and open CCTV")
		assert(is_zero_approx(office._pan_velocity_deg))
	_old_pan = office._pan
	_old_busy = busy
	_old_start = systems.night_start_time
	if visible_feed and not _seen_cameras.has(monitor.current_camera_id):
		_seen_cameras.append(monitor.current_camera_id)
	var signature: String = "%d/%s/%s/%s/%s/%s/%s" % [monitor.current_camera_id, monitor._vent_selected, monitor._ipad.visible, monitor._flipping, systems.game_state, monitor._feed.size, office.music_box.is_winding()]
	if signature != _last_cctv_signature:
		_last_cctv_signature = signature
		_report_cctv()
	if office.music_box.is_winding() != _was_winding:
		_was_winding = office.music_box.is_winding()
		print("CCTV WIND: winding=%s charge=%.3f usage=%d" % [_was_winding, office.music_box.remaining_seconds, systems.get_usage_bars()])
	_noise_elapsed += delta
	if sample_rendered_grain and visible_feed and not _capture_pending and _noise_elapsed >= 0.3 and monitor._switch_burst_remaining <= 0.0:
		_noise_elapsed = 0.0
		_capture_grain(monitor.current_camera_id, monitor._feed.size)

func _capture_grain(camera_id: int, feed_size: Vector2) -> void:
	_capture_pending = true
	await RenderingServer.frame_post_draw
	_capture_pending = false
	var monitor: CameraSystem = office.camera_system
	if not monitor._static_overlay.is_visible_in_tree() or monitor.current_camera_id != camera_id or not monitor._feed.size.is_equal_approx(feed_size) or monitor._switch_burst_remaining > 0.0:
		return
	var image: Image = office.get_viewport().get_texture().get_image()
	assert(image != null and not image.is_empty())
	# Tiny patch clear of labels, map, tabs, HUD and REC at both target sizes.
	var origin: Vector2i = Vector2i(feed_size * Vector2(0.55, 0.35))
	var samples: Array[float] = []
	for y: int in range(8):
		for x: int in range(8):
			samples.append(image.get_pixel(origin.x + x, origin.y + y).r)
	var sample_key: String = "%d/%s" % [camera_id, feed_size]
	if _previous_samples.has(sample_key):
		var previous: Array = _previous_samples[sample_key]
		var mean_delta: float = 0.0
		var peak_delta: float = 0.0
		for index: int in range(samples.size()):
			var difference: float = absf(samples[index] - float(previous[index]))
			mean_delta += difference / float(samples.size())
			peak_delta = maxf(peak_delta, difference)
		assert(peak_delta <= monitor.static_intensity + monitor.static_band_strength + 0.009, "Only idle grain/bands may change in the stationary feed patch")
		if mean_delta > 0.0005:
			_moving_samples[sample_key] = int(_moving_samples.get(sample_key, 0)) + 1
			_max_noise_delta = maxf(_max_noise_delta, mean_delta)
			if int(_moving_samples[sample_key]) == 1:
				print("CCTV GRAIN MOVING: CAM %d size=%s mean_delta=%.5f peak_delta=%.5f opacity=%.3f" % [camera_id, feed_size, mean_delta, peak_delta, monitor.static_intensity])
				var capture_dir: String = capture_directory
				assert(DirAccess.make_dir_recursive_absolute(capture_dir) == OK)
				var capture_path: String = capture_dir.path_join("cam_%d_%dx%d.png" % [camera_id, int(feed_size.x), int(feed_size.y)])
				assert(image.save_png(capture_path) == OK)
				print("CCTV CAPTURE: ", capture_path)
	_previous_samples[sample_key] = samples

func _on_office_click(button_name: String) -> void:
	_office_clicks[button_name] = int(_office_clicks.get(button_name, 0)) + 1
	print("CCTV OFFICE CLICK: %s doors=%s/%s vent=%s lights=%s/%s usage=%d" % [button_name, office.left_closed, office.right_closed, office.vent_closed, office.left_light_on, office.right_light_on, systems.get_usage_bars()])

func _report_cctv() -> void:
	var monitor: CameraSystem = office.camera_system
	var photo: String = monitor._feed_photo.texture.resource_path if monitor._feed_photo.texture != null else "PLACEHOLDER"
	print("CCTV SNAPSHOT: size=%s CAM%d=%s room=%s feed_visible=%s static_visible=%s rec=%s vent_tab=%s busy=%s flip=%s yaw=%.3f state=%s phase=%s power=%.3f usage=%d box=%.3f wind=%s" % [monitor._feed.size, monitor.current_camera_id, photo, monitor._room_label.text, monitor._ipad.visible, monitor._static_overlay.is_visible_in_tree(), monitor._rec_indicator.is_visible_in_tree(), monitor._vent_selected, monitor.is_monitor_busy(), monitor._flipping, office._pan, FNAPSystems.GameState.keys()[systems.game_state], PowerOutSequence.Phase.keys()[sequence.phase], systems.office_power, systems.get_usage_bars(), office.music_box.remaining_seconds, office.music_box.is_winding()])
	print("CCTV STATS: seen=%s moving_grain=%s max_mean_delta=%.5f clicks=%s" % [_seen_cameras, _moving_samples, _max_noise_delta, _office_clicks])
