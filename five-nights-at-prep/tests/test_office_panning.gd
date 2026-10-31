class_name OfficePanningContractTests
extends Node

## Pure response-curve/resource checks. Movement is checked in live fixtures.
func test_neutral_zone_directions_and_maximum_speed() -> void:
	var office: Office = Office.new()
	for fraction: float in [0.425, 0.45, 0.5, 0.55, 0.575]:
		assert(is_zero_approx(office.get_pan_target_speed(fraction * 1152.0, 1152.0)))
	assert(office.get_pan_target_speed(0.4 * 1152.0, 1152.0) > 0.0, "Left cursor means positive office yaw")
	assert(office.get_pan_target_speed(0.6 * 1152.0, 1152.0) < 0.0, "Right cursor means negative office yaw")
	assert(is_equal_approx(office.get_pan_target_speed(0.0, 1152.0), 110.0))
	assert(is_equal_approx(office.get_pan_target_speed(1152.0, 1152.0), -110.0))
	assert(is_equal_approx(office.get_pan_target_speed(-100.0, 1152.0), 110.0))
	assert(is_zero_approx(office.get_pan_target_speed(100.0, 0.0)))
	office.free()

func test_continuous_monotonic_and_symmetric_curve() -> void:
	var office: Office = Office.new()
	var previous: float = 0.0
	for index: int in range(501):
		var normalized: float = float(index) / 500.0
		var right: float = office.get_pan_target_speed((1.0 + normalized) * 576.0, 1152.0)
		var left: float = office.get_pan_target_speed((1.0 - normalized) * 576.0, 1152.0)
		assert(is_equal_approx(left, -right), "Symmetric left/right response")
		assert(absf(right) >= previous - 0.00001, "Speed must increase toward edges")
		assert(absf(right) - previous < 0.5, "No discrete speed steps")
		previous = absf(right)
	assert(absf(office.get_pan_target_speed(0.57501 * 1152.0, 1152.0)) < 0.01, "Gentle dead-zone boundary")
	var gentle: float = absf(office.get_pan_target_speed(0.6 * 1152.0, 1152.0))
	assert(gentle > 1.0 and gentle < 2.0, "Small offsets should pan slowly")
	office.free()

func test_resolution_independent_curve_and_tuning() -> void:
	var office: Office = Office.new()
	for fraction: float in [0.0, 0.02, 0.25, 0.4, 0.5, 0.6, 0.75, 0.98, 1.0]:
		assert(is_equal_approx(office.get_pan_target_speed(fraction * 1152.0, 1152.0), office.get_pan_target_speed(fraction * 960.0, 960.0)))
	assert(is_equal_approx(Office.PAN_MAX_DEG, 22.0), "Existing yaw limits remain unchanged")
	assert(is_equal_approx(office.pan_deadzone, 0.15))
	assert(is_equal_approx(office.pan_curve_exponent, 1.5))
	assert(is_equal_approx(office.pan_acceleration_deg, 750.0))
	assert(is_equal_approx(office.pan_deceleration_deg, 1000.0))
	office.free()

func test_monitor_query_covers_both_flip_directions_without_changing_power_state() -> void:
	var monitor: CameraSystem = CameraSystem.new()
	assert(not monitor.is_monitor_busy())
	monitor._is_open = true
	assert(monitor.is_monitor_up() and monitor.is_monitor_busy())
	monitor._is_open = false
	monitor._flipping = true
	assert(not monitor.is_monitor_up(), "Keep original monitor/power semantics during flip down")
	assert(monitor.is_monitor_busy(), "Pan must remain locked through flip down")
	monitor._flipping = false
	assert(not monitor.is_monitor_busy())
	monitor.free()

func test_office_keeps_one_yaw_camera_and_all_existing_controls() -> void:
	var packed: PackedScene = load("res://scenes/office.tscn") as PackedScene
	var office: Office = packed.instantiate() as Office
	var cameras: Array[Node] = office.find_children("*", "Camera3D", true, false)
	assert(cameras.size() == 1)
	assert(cameras[0] == office.get_node("Player"))
	for node_path: String in ["LeftDoorButton", "RightDoorButton", "LeftLightButton", "RightLightButton", "VentButton", "Desk/MusicBox", "CameraSystem", "AIandSystems", "PowerOutSequence"]:
		assert(office.has_node(node_path))
	var player: Camera3D = office.get_node("Player") as Camera3D
	assert(is_zero_approx(player.rotation.x) and is_zero_approx(player.rotation.z))
	office.free()
