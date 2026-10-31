class_name PowerOutContractTests
extends Node

## Static resource/wiring checks; gameplay is verified in the live test scenes.
func test_office_has_one_camera_and_one_outage_controller() -> void:
	var packed: PackedScene = load("res://scenes/office.tscn") as PackedScene
	var office: Node = packed.instantiate()
	var cameras: int = 0
	var controllers: int = 0
	for child: Node in office.get_children():
		if child is CameraSystem:
			cameras += 1
		if child is PowerOutSequence:
			controllers += 1
	assert(cameras == 1, "Exactly one existing monitor system")
	assert(controllers == 1, "Exactly one outage presentation controller")
	assert(office.get_node("AIandSystems") is FNAPSystems)
	office.free()

func test_alpha_defaults_and_optional_silent_audio_hook() -> void:
	var packed: PackedScene = load("res://scenes/office.tscn") as PackedScene
	var office: Node = packed.instantiate()
	var sequence: PowerOutSequence = office.get_node("PowerOutSequence") as PowerOutSequence
	var piano: AudioStreamPlayer = sequence.get_node("PowerOutPiano") as AudioStreamPlayer
	var red: OmniLight3D = sequence.get_node("EmergencyRedLight") as OmniLight3D
	assert(is_equal_approx(sequence.red_light_duration, 20.0))
	assert(is_equal_approx(sequence.blackout_min_duration, 3.0))
	assert(is_equal_approx(sequence.blackout_max_duration, 5.0))
	assert(is_zero_approx(sequence.blackout_duration), "No blackout duration selected before an outage")
	assert(piano.stream == null, "Future recording slot must remain empty")
	assert(not piano.autoplay)
	assert(not red.visible, "Emergency light must start off")
	assert(red.light_color.r > red.light_color.g * 10.0)
	assert(red.light_energy < 1.0)
	assert(is_equal_approx(FNAPSystems.POWER_DRAIN_PER_BAR, 0.15))
	for duration: float in FNAPSystems.NIGHT_DURATIONS.values():
		assert(is_equal_approx(duration, 360.0))
	office.free()
