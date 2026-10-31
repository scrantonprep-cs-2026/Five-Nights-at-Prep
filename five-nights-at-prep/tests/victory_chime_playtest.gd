class_name VictoryChimePlaytest
extends OfficeKeyboardPlaytest

## Test-only clock controls; production still requires the full six-minute night.
## 4=reach 6AM, 1=real drain, 5=reset (inherited); V=seek cue near its natural end.
## R/T=win while RED/BLACK, F=start Night5, K=let music box expire, P=report.
var _last_chime_signature: String = ""
var _victories_observed: int = 0
var _finished_count: int = 0
var _win_night: int = 0
var _win_power: float = 0.0
var _win_charge: float = 0.0
var _progress_reported: bool = false

func _ready() -> void:
	super._ready()
	sequence._victory_chime_sound.finished.connect(_on_chime_finished)
	assert(not (sequence._victory_chime_sound.stream as AudioStreamMP3).loop)
	print("VICTORY AUDIO TEST: 4=6AM, V=seek end, R/T=RED/BLACK win, F=Night5, K=box empty, P=report")

func _unhandled_key_input(event: InputEvent) -> void:
	super._unhandled_key_input(event)
	if not event is InputEventKey or not event.is_pressed() or event.is_echo():
		return
	match (event as InputEventKey).keycode:
		KEY_V:
			if sequence._victory_chime_sound.playing:
				sequence._victory_chime_sound.seek(maxf(0.0, sequence._victory_chime_sound.stream.get_length() - 0.6))
				print("VICTORY TEST: seek near natural end; no state/timing/loop override")
		KEY_R:
			systems.start_night()
			systems.night_start_time = Time.get_ticks_msec() / 1000.0 - (360.0 - sequence.red_light_duration * 0.5)
			systems.office_power = 0.02
		KEY_T:
			systems.start_night()
			systems.night_start_time = Time.get_ticks_msec() / 1000.0 - (360.0 - sequence.red_light_duration - sequence.blackout_min_duration * 0.5)
			systems.office_power = 0.02
		KEY_F:
			systems.night = 5
			systems.start_night()
		KEY_K:
			office.music_box.remaining_seconds = 0.01
		KEY_P:
			_report_chime()

func _process(delta: float) -> void:
	super._process(delta)
	var player: AudioStreamPlayer = sequence._victory_chime_sound
	assert(not (player.stream as AudioStreamMP3).loop)
	var signature: String = "%d/%d/%s" % [systems.game_state, systems.night, player.playing]
	if signature != _last_chime_signature:
		if systems.game_state == FNAPSystems.GameState.NIGHT_WON and player.playing:
			_victories_observed += 1
			_win_night = systems.night
			_win_power = systems.office_power
			_win_charge = office.music_box.remaining_seconds
			_progress_reported = false
		_last_chime_signature = signature
		_report_chime()
	if systems.game_state == FNAPSystems.GameState.NIGHT_WON:
		assert(is_equal_approx(systems.get_night_elapsed(), 360.0))
		assert(is_equal_approx(systems.office_power, _win_power))
		assert(is_equal_approx(office.music_box.remaining_seconds, _win_charge))
		assert(not office._has_power and not office.camera_system.is_monitor_busy())
		if player.playing:
			assert(systems.night == _win_night)
			if not _progress_reported and player.get_playback_position() >= 0.3:
				_progress_reported = true
				print("VICTORY CHIME ADVANCING: position=%.3f night=%d clock=6AM" % [player.get_playback_position(), systems.night])
	else:
		assert(not player.playing, "No victory sound during play, outage, failure or retry")

func _on_chime_finished() -> void:
	_finished_count += 1
	print("VICTORY CHIME FINISHED: count=%d phase=%s" % [_finished_count, PowerOutSequence.Phase.keys()[sequence.phase]])

func _report_chime() -> void:
	var player: AudioStreamPlayer = sequence._victory_chime_sound
	print("VICTORY CHIME SNAPSHOT: night=%d state=%s phase=%s playing=%s position=%.3f loop=%s wins=%d finished=%d victory_elapsed=%.3f all_complete=%s" % [systems.night, FNAPSystems.GameState.keys()[systems.game_state], PowerOutSequence.Phase.keys()[sequence.phase], player.playing, player.get_playback_position(), (player.stream as AudioStreamMP3).loop, _victories_observed, _finished_count, sequence._victory_elapsed, systems._simulation_finished])
