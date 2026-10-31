class_name MonitorAudioTests
extends Node

func test_active_camera_scene_has_wired_nonpositional_sound_players() -> void:
	var packed: PackedScene = load("res://scenes/camera_system.tscn") as PackedScene
	var monitor: Node = packed.instantiate()
	var up: AudioStreamPlayer = monitor.get_node("CamerasUp") as AudioStreamPlayer
	var down: AudioStreamPlayer = monitor.get_node("CamerasDown") as AudioStreamPlayer
	assert(up != null and down != null)
	assert(up.stream.resource_path == "res://CamerasUp.wav")
	assert(down.stream.resource_path == "res://CamerasDown.wav")
	var switch_sound: AudioStreamPlayer = monitor.get_node("CameraSwitchSound") as AudioStreamPlayer
	assert(switch_sound != null)
	assert(switch_sound.stream.resource_path == "res://blip3.wav")
	for player: AudioStreamPlayer in [up, down, switch_sound]:
		assert(player.stream.get_length() > 0.0)
		assert(player.stream is AudioStreamWAV)
		var wav: AudioStreamWAV = player.stream as AudioStreamWAV
		assert(wav.loop_mode == AudioStreamWAV.LOOP_DISABLED)
		assert(not player.autoplay)
		assert(player.bus == &"Master")
		assert(is_zero_approx(player.volume_db))
	monitor.free()
