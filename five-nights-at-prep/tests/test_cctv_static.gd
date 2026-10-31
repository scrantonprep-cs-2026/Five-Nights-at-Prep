class_name CCTVStaticTests
extends Node

func _make_monitor() -> CameraSystem:
	var builder: CCTVFeedTests = CCTVFeedTests.new()
	var monitor: CameraSystem = builder._make_monitor()
	builder.free()
	monitor._build_flip()
	monitor._cancel_camera_switch_burst()
	monitor._is_open = true
	monitor._ipad.visible = true
	return monitor

func _amount(monitor: CameraSystem) -> float:
	return float(monitor._static_material.get_shader_parameter("burst_amount"))

func test_idle_and_burst_tuning_updates_the_existing_material() -> void:
	var monitor: CameraSystem = _make_monitor()
	assert(is_equal_approx(monitor.switch_static_duration, 0.20))
	assert(is_equal_approx(monitor.switch_static_opacity, 0.90))
	assert(is_equal_approx(monitor.switch_static_updates_per_second, 48.0))
	assert(is_zero_approx(_amount(monitor)))
	monitor.static_intensity = 0.12
	monitor.static_band_strength = 0.025
	monitor.static_updates_per_second = 26.0
	monitor.switch_static_opacity = 0.85
	monitor.switch_static_updates_per_second = 50.0
	assert(is_equal_approx(float(monitor._static_material.get_shader_parameter("intensity")), 0.12))
	assert(is_equal_approx(float(monitor._static_material.get_shader_parameter("band_strength")), 0.025))
	assert(is_equal_approx(float(monitor._static_material.get_shader_parameter("updates_per_second")), 26.0))
	assert(is_equal_approx(float(monitor._static_material.get_shader_parameter("burst_opacity")), 0.85))
	assert(is_equal_approx(float(monitor._static_material.get_shader_parameter("burst_updates_per_second")), 50.0))
	monitor.free()

func test_burst_holds_peak_then_reveals_and_returns_to_idle() -> void:
	var monitor: CameraSystem = _make_monitor()
	monitor._start_camera_switch_burst()
	assert(monitor.is_processing() and is_equal_approx(_amount(monitor), 1.0))
	monitor._process(0.04)
	assert(is_equal_approx(_amount(monitor), 1.0))
	monitor._process(0.06)
	assert(_amount(monitor) > 0.0 and _amount(monitor) < 1.0)
	monitor._process(0.101)
	assert(is_zero_approx(_amount(monitor)))
	assert(is_zero_approx(monitor._switch_burst_remaining))
	assert(not monitor.is_processing(), "Idle shader animation must not require CPU processing")
	monitor.free()

func test_rapid_restarts_never_add_duration_or_create_effect_nodes() -> void:
	var monitor: CameraSystem = _make_monitor()
	var material_id: int = monitor._static_material.get_instance_id()
	for index: int in range(50):
		monitor._start_camera_switch_burst()
		assert(is_equal_approx(monitor._switch_burst_remaining, 0.20))
		assert(is_equal_approx(_amount(monitor), 1.0))
		assert(monitor._static_material.get_instance_id() == material_id)
		assert(monitor._feed.get_child_count() == 2, "Reuse the original photo/static children")
		monitor._process(0.08)
	monitor._process(0.121)
	assert(is_zero_approx(_amount(monitor)) and not monitor.is_processing())
	monitor.switch_static_duration = 10.0
	monitor._start_camera_switch_burst()
	assert(is_equal_approx(monitor._switch_burst_remaining, 0.25))
	monitor.switch_static_duration = 0.0
	monitor._start_camera_switch_burst()
	assert(is_equal_approx(monitor._switch_burst_remaining, 0.15))
	monitor.free()

func test_same_camera_and_locked_selection_do_not_restart_bursts() -> void:
	var monitor: CameraSystem = _make_monitor()
	monitor._on_camera_pressed(1)
	assert(is_zero_approx(monitor._switch_burst_remaining))
	monitor._start_camera_switch_burst()
	monitor._process(0.08)
	var remaining: float = monitor._switch_burst_remaining
	monitor._on_camera_pressed(1)
	assert(is_equal_approx(monitor._switch_burst_remaining, remaining))
	monitor._cancel_camera_switch_burst()
	monitor._is_open = false
	monitor._on_camera_pressed(2)
	monitor._is_open = true
	monitor._flipping = true
	monitor._on_camera_pressed(3)
	monitor._flipping = false
	monitor._vent_selected = true
	monitor._on_camera_pressed(4)
	assert(monitor.current_camera_id == 1)
	assert(is_zero_approx(monitor._switch_burst_remaining) and is_zero_approx(_amount(monitor)))
	monitor.free()

func test_vent_tab_and_hidden_state_guards_clear_burst_immediately() -> void:
	var monitor: CameraSystem = _make_monitor()
	monitor._start_camera_switch_burst()
	monitor._select_tab(true)
	assert(not monitor._static_overlay.visible and not monitor._rec_indicator.visible)
	assert(is_zero_approx(_amount(monitor)) and not monitor.is_processing())
	monitor._select_tab(false)
	assert(monitor._static_overlay.visible and is_zero_approx(_amount(monitor)))
	for lock: String in ["closed", "flip", "disabled", "vent"]:
		monitor._is_open = true
		monitor._flipping = false
		monitor._monitor_enabled = true
		monitor._vent_selected = false
		monitor._start_camera_switch_burst()
		match lock:
			"closed": monitor._is_open = false
			"flip": monitor._flipping = true
			"disabled": monitor._monitor_enabled = false
			"vent": monitor._vent_selected = true
		monitor._process(0.001)
		assert(is_zero_approx(_amount(monitor)) and not monitor.is_processing())
	monitor.free()

func test_feed_refresh_and_flip_completion_do_not_trigger_bursts() -> void:
	var monitor: CameraSystem = _make_monitor()
	for camera_id: int in range(1, 8):
		monitor.current_camera_id = camera_id
		monitor._refresh_feed()
		assert(is_zero_approx(monitor._switch_burst_remaining))
		assert(is_zero_approx(_amount(monitor)))
	monitor._flipping = true
	monitor._on_flip_finished()
	assert(is_zero_approx(_amount(monitor)) and not monitor.is_processing())
	monitor.free()
