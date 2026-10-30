class_name CCTVStaticPlaytest
extends CCTVFeedPlaytest

## Observes the real hotspot signals AFTER their production handler. Never drives
## a selection, countdown or shader itself. P prints the measured burst totals.
var _observed_id: int = 1
var _last_remaining: float = 0.0
var _tracking_burst: bool = false
var _burst_started_ms: int = 0
var _starts: int = 0
var _restarts: int = 0
var _clears: int = 0
var _cancellations: int = 0
var _same_camera_clicks: int = 0
var _burst_cameras: Array[int] = []
var _peak_captures: Dictionary = {}
var _clear_durations: Array[float] = []
var _overlay_material_id: int = 0

func _ready() -> void:
	super._ready()
	var monitor: CameraSystem = office.camera_system
	_observed_id = monitor.current_camera_id
	_overlay_material_id = monitor._static_material.get_instance_id()
	for index: int in range(monitor._camera_buttons.size()):
		monitor._camera_buttons[index].pressed.connect(_on_selection_observed.bind(index + 1))
	print("STATIC TEST: production hotspot observer; dark snow peak captures; P=burst stats")

func _on_selection_observed(camera_id: int) -> void:
	var monitor: CameraSystem = office.camera_system
	if not monitor._is_open or monitor._flipping or monitor._vent_selected:
		return
	assert(monitor.current_camera_id == camera_id)
	var amount: float = float(monitor._static_material.get_shader_parameter("burst_amount"))
	if camera_id != _observed_id:
		_starts += 1
		if _last_remaining > 0.0:
			_restarts += 1
		assert(is_equal_approx(monitor._switch_burst_remaining, monitor.switch_static_duration), "Every change replaces, not extends, the countdown")
		assert(is_equal_approx(amount, 1.0), "Texture cut must be masked at peak immediately")
		_tracking_burst = true
		_burst_started_ms = Time.get_ticks_msec()
		if not _burst_cameras.has(camera_id):
			_burst_cameras.append(camera_id)
		print("STATIC BURST START: #%d CAM%d restart=%s remaining=%.3f room=%s" % [_starts, camera_id, _last_remaining > 0.0, monitor._switch_burst_remaining, monitor._room_label.text])
		_capture_burst_peak(camera_id)
	else:
		_same_camera_clicks += 1
		assert(monitor._switch_burst_remaining <= _last_remaining + 0.001, "Same-camera clicks must not retrigger")
		print("STATIC SAME CAMERA: CAM%d no restart; remaining=%.3f" % [camera_id, monitor._switch_burst_remaining])
	_observed_id = camera_id
	_last_remaining = monitor._switch_burst_remaining

func _process(delta: float) -> void:
	super._process(delta)
	var monitor: CameraSystem = office.camera_system
	var remaining: float = monitor._switch_burst_remaining
	var amount: float = float(monitor._static_material.get_shader_parameter("burst_amount"))
	assert(monitor._static_material.get_instance_id() == _overlay_material_id)
	assert(monitor._feed.get_child_count() == 2, "Never accumulate overlays or timers")
	assert(remaining >= 0.0 and remaining <= monitor.switch_static_duration + 0.001)
	assert(amount >= 0.0 and amount <= 1.0)
	if remaining > 0.0:
		assert(monitor._static_overlay.is_visible_in_tree())
		assert(monitor.is_processing())
	else:
		assert(is_zero_approx(amount) and not monitor.is_processing(), "Burst must clear; idle stays shader-driven")
		if _tracking_burst:
			var elapsed: float = float(Time.get_ticks_msec() - _burst_started_ms) / 1000.0
			if monitor._ipad.visible and not monitor._vent_selected:
				_clears += 1
				_clear_durations.append(elapsed)
				assert(elapsed <= monitor.switch_static_duration + 0.075)
				print("STATIC BURST CLEARED: CAM%d measured=%.3fs amount=%.1f" % [monitor.current_camera_id, elapsed, amount])
			else:
				_cancellations += 1
				print("STATIC BURST CANCELLED: closed/vent/locked; amount=%.1f" % amount)
			_tracking_burst = false
	_last_remaining = remaining

func _capture_burst_peak(camera_id: int) -> void:
	var monitor: CameraSystem = office.camera_system
	var size: Vector2 = monitor._feed.size
	var key: String = "%d/%s" % [camera_id, size]
	if _peak_captures.has(key):
		return
	await RenderingServer.frame_post_draw
	if monitor.current_camera_id != camera_id or not monitor._static_overlay.is_visible_in_tree():
		return
	var amount: float = float(monitor._static_material.get_shader_parameter("burst_amount"))
	if amount < 0.8:
		return
	var image: Image = office.get_viewport().get_texture().get_image()
	var origin: Vector2i = Vector2i(size * Vector2(0.55, 0.35))
	var total: float = 0.0
	var squared_total: float = 0.0
	for y: int in range(8):
		for x: int in range(8):
			var gray: float = image.get_pixel(origin.x + x, origin.y + y).r
			total += gray / 64.0
			squared_total += gray * gray / 64.0
	var deviation: float = sqrt(maxf(0.0, squared_total - total * total))
	assert(deviation > 0.06, "Burst must render visibly stronger animated snow, not a uniform flash")
	assert(total < 0.55, "Burst must stay dark-biased rather than flash white")
	var capture_dir: String = capture_directory
	assert(DirAccess.make_dir_recursive_absolute(capture_dir) == OK)
	var path: String = capture_dir.path_join("burst_cam_%d_%dx%d.png" % [camera_id, int(size.x), int(size.y)])
	assert(image.save_png(path) == OK)
	_peak_captures[key] = true
	print("STATIC PEAK CAPTURE: CAM%d amount=%.3f mean=%.3f deviation=%.3f path=%s" % [camera_id, amount, total, deviation, path])

func _unhandled_key_input(event: InputEvent) -> void:
	super._unhandled_key_input(event)
	if event is InputEventKey and event.is_pressed() and not event.is_echo() and (event as InputEventKey).keycode == KEY_P:
		_report_static()

func _report_static() -> void:
	print("STATIC STATS: starts=%d restarts=%d clears=%d cancelled=%d same_camera=%d cameras=%s clear_seconds=%s peak_captures=%s" % [_starts, _restarts, _clears, _cancellations, _same_camera_clicks, _burst_cameras, _clear_durations, _peak_captures.keys()])
