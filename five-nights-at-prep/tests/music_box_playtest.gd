class_name MusicBoxPlaytest
extends Node

## Test-only fixture. Production scenes have no shortcuts.
## 1 = 10s charge; 2 = 1s charge; 3/4 = start Night 1/5;
## 5 = reach 6 AM with 0.02s charge; 6 = drain battery; 9 = snapshot.
@onready var office: Office = $Office
@onready var systems: FNAPSystems = $Office/AIandSystems
@onready var box: MusicBox = $Office/Desk/MusicBox
@onready var sequence: PowerOutSequence = $Office/PowerOutSequence
var _report_elapsed: float = 0.0
var _last_state: int = -1
var _previous_winding: bool = false
var _freeze_checked: bool = false
var _freeze_clock: float = 0.0
var _freeze_power: float = 0.0
var _freeze_pan: float = 0.0
var _freeze_door_y: float = 0.0
var _freeze_locations: Array[int] = []

func _ready() -> void:
	print("MUSIC TEST: 1=10s, 2=1s, 3=Night1, 4=Night5, 5=6AM priority, 6=powerout, 9=snapshot")

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key: InputEventKey = event as InputEventKey
	match key.keycode:
		KEY_1:
			box.remaining_seconds = 10.0
		KEY_2:
			box.remaining_seconds = 1.0
		KEY_3:
			systems.night = 1
			systems.start_night()
			_freeze_checked = false
		KEY_4:
			systems.night = 5
			systems.start_night()
			_freeze_checked = false
		KEY_5:
			systems.start_night()
			box.remaining_seconds = 0.02
			systems.night_start_time = Time.get_ticks_msec() / 1000.0 - 361.0
		KEY_6:
			systems.office_power = 0.01
		KEY_9:
			_report()

func _process(delta: float) -> void:
	if systems.game_state != _last_state:
		_last_state = systems.game_state
		_report()
	if box.is_winding() != _previous_winding:
		_previous_winding = box.is_winding()
		print("MUSIC TEST: winding=%s remaining=%.3f" % [_previous_winding, box.remaining_seconds])
	if systems.game_state == FNAPSystems.GameState.MUSIC_BOX_FAILED:
		_check_freeze()
	_report_elapsed += delta
	if _report_elapsed >= 1.0:
		_report_elapsed = 0.0
		_report()

func _check_freeze() -> void:
	if not _freeze_checked:
		_freeze_checked = true
		_freeze_clock = systems.get_night_elapsed()
		_freeze_power = systems.office_power
		_freeze_pan = office.player.rotation.y
		_freeze_door_y = office.left_door.position.y
		_freeze_locations.clear()
		for animatronic: FNAPSystems.Animatronic in systems.animatronics:
			_freeze_locations.append(animatronic.location)
		print("MUSIC TEST: freeze baseline captured")
		return
	assert(is_equal_approx(systems.get_night_elapsed(), _freeze_clock), "Clock must freeze")
	assert(is_equal_approx(systems.office_power, _freeze_power), "Battery must freeze")
	assert(is_equal_approx(office.player.rotation.y, _freeze_pan), "Pan must freeze")
	assert(is_equal_approx(office.left_door.position.y, _freeze_door_y), "Door movement must freeze")
	for index: int in range(systems.animatronics.size()):
		assert(systems.animatronics[index].location == _freeze_locations[index], "AI must freeze")
	assert(not office._has_power, "Office controls must lock")
	assert(not office.camera_system._monitor_enabled, "CCTV must lock")

func _report() -> void:
	print("MUSIC SNAPSHOT: night=%d state=%s charge=%.3f/%.1f wind=%s failed=%s wait=%.3f clock=%.3f power=%.3f usage=%d frozen=%s retry=%s vent_closed=%s" % [
		systems.night, FNAPSystems.GameState.keys()[systems.game_state], box.remaining_seconds,
		box.full_duration, box.is_winding(), box.failed, box.failure_elapsed, systems.get_night_elapsed(),
		systems.office_power, systems.get_usage_bars(), office._music_box_frozen, sequence._retry.visible, office.vent_closed])
