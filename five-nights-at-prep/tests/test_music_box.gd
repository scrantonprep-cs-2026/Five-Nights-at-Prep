class_name MusicBoxContractTests
extends Node

func test_all_five_nights_keep_six_minutes_and_box_scales() -> void:
	var box: MusicBox = MusicBox.new()
	var expected: PackedFloat32Array = PackedFloat32Array([60, 50, 40, 30, 20])
	for index: int in range(5):
		assert(is_equal_approx(box.duration_for_night(index + 1), expected[index]))
		assert(is_equal_approx(FNAPSystems.NIGHT_DURATIONS[index + 1], 360.0))
	assert(is_equal_approx(box.duration_for_night(0), 60.0))
	assert(is_equal_approx(box.duration_for_night(6), 20.0))
	assert(is_equal_approx(box.failure_delay, 15.0))
	box.night_durations = PackedFloat32Array()
	assert(is_equal_approx(box.duration_for_night(3), 60.0))
	box.free()

func test_box_scene_has_pickable_monitor_and_empty_sound_slot() -> void:
	var packed: PackedScene = load("res://scenes/office.tscn") as PackedScene
	var office: Node3D = packed.instantiate() as Node3D
	var box: MusicBox = office.get_node("Desk/MusicBox") as MusicBox
	assert(box != null)
	assert(box.input_ray_pickable)
	assert(box.collision_layer != 0)
	var shape: CollisionShape3D = box.get_node("CollisionShape3D") as CollisionShape3D
	assert(shape.shape is BoxShape3D)
	assert(box.get_node("Model") is Node3D)
	assert(box.get_node("Screen") is MeshInstance3D)
	var viewport: SubViewport = box.get_node("ScreenViewport") as SubViewport
	assert(viewport.size == Vector2i(408, 240))
	var sound: AudioStreamPlayer = box.get_node("FailureSound") as AudioStreamPlayer
	assert(sound.stream == null, "Future recording stays empty")
	assert(not sound.autoplay)
	assert(is_equal_approx(box.wind_rate, 4.0))
	assert(box.scale.is_equal_approx(Vector3(0.68, 0.68, 0.68)))
	assert(box.position.x > 0.0, "Keep the monitor on the right with the vent clear")
	office.free()

func test_display_has_only_a_centered_gray_ring() -> void:
	# Build only the UI, without starting an office or simulating gameplay.
	var packed: PackedScene = load("res://scenes/music_box.tscn") as PackedScene
	var box: MusicBox = packed.instantiate() as MusicBox
	box.screen_viewport = box.get_node("ScreenViewport") as SubViewport
	box._build_screen()
	var background: ColorRect = box.screen_viewport.get_node("ScreenUI") as ColorRect
	assert(box.screen_viewport.get_child_count() == 1)
	assert(background.get_child_count() == 1, "No percentage, countdown, titles or hint labels")
	assert(is_equal_approx(background.color.r, background.color.g))
	assert(is_equal_approx(background.color.g, background.color.b))
	var ring: ColorRect = background.get_node("WindGauge") as ColorRect
	assert(ring != null)
	assert(ring.position + ring.size * 0.5 == background.size * 0.5, "Gauge must be centered")
	assert(is_equal_approx(ring.size.x, ring.size.y), "Keep the gauge circular")
	var material: ShaderMaterial = ring.material as ShaderMaterial
	for charge: float in [1.0, 0.5, 0.1, 0.0]:
		box.remaining_seconds = box.full_duration * charge
		box._refresh_display()
		assert(is_equal_approx(float(material.get_shader_parameter("charge")), charge))
		var tint: Color = material.get_shader_parameter("fill_color")
		assert(is_equal_approx(tint.r, tint.g) and is_equal_approx(tint.g, tint.b), "Stay gray even at low charge")
	box.free()
