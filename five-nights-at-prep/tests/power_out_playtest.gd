class_name PowerOutPlaytest
extends Node

## Test-only entry point. Production office has no debug battery/clock shortcuts.
## 1: near-zero battery, real drain; 2: 6 AM in RED; 3: 6 AM in BLACK.
## 4: move clock beyond 6 AM (including after GAME_OVER to test the guard).
## 5: reset normal night. 6: repeat the outage hook (must not restart stages).
## 7: resize to 960x540. 8: resize to 1152x648.
@onready var office: Office = $Office
@onready var systems: FNAPSystems = $Office/AIandSystems
@onready var sequence: PowerOutSequence = $Office/PowerOutSequence

func _ready() -> void:
	print("OUTAGE TEST: keys 1=drain, 2=red win, 3=black win, 4=6 AM, 5=reset, 6=repeat hook, 7/8=resize")

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key: InputEventKey = event as InputEventKey
	match key.keycode:
		KEY_1:
			systems.office_power = 0.02
			print("OUTAGE TEST: near-zero battery, monitor up = ", office.camera_system.is_monitor_up())
		KEY_2:
			_prepare_clock(357.0)
		KEY_3:
			_prepare_clock(360.0 - sequence.red_light_duration - sequence.blackout_min_duration * 0.5)
		KEY_4:
			systems.night_start_time = Time.get_ticks_msec() / 1000.0 - 361.0
		KEY_5:
			systems.start_night()
		KEY_6:
			systems.on_power_out()
		KEY_7:
			get_window().size = Vector2i(960, 540)
		KEY_8:
			get_window().size = Vector2i(1152, 648)
		KEY_9:
			_report()

func _report() -> void:
	print("OUTAGE TIMING: red=%.2fs black=%.2fs phase_elapsed=%.2fs" % [sequence.red_light_duration, sequence.blackout_duration, sequence.phase_elapsed])
	print("OUTAGE SNAPSHOT: state=%s phase=%s power=%.3f elapsed=%.2f has_power=%s monitor=%s enabled=%s flipping=%s doors=%s/%s vent=%s halls=%s/%s red=%s cover=%s piano=%s ceiling=%s ambient=%.2f" % [
		FNAPSystems.GameState.keys()[systems.game_state], PowerOutSequence.Phase.keys()[sequence.phase],
		systems.office_power, systems.get_night_elapsed(), office._has_power,
		office.camera_system.is_monitor_up(), office.camera_system._monitor_enabled, office.camera_system._flipping,
		office.left_closed, office.right_closed, office.vent_closed,
		office.left_hall_light.visible, office.right_hall_light.visible, sequence.emergency_light.visible,
		sequence._cover.visible, sequence.piano.playing, office.get_node("CeilingLight").visible,
		sequence._environment.ambient_light_energy])

func _prepare_clock(elapsed: float) -> void:
	systems.start_night()
	sequence.victory_display_duration = 12.0
	systems.night_start_time = Time.get_ticks_msec() / 1000.0 - elapsed
	systems.office_power = 0.02
	print("OUTAGE TEST: real clock fast-forwarded to ", elapsed, " seconds; natural drain remains enabled")
