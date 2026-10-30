class_name FNAPSystems
# FNAP Animatronic Movement Simulation [BETA 1.0]
# Ported from the Python prototype for Godot 4.x.
# Attach to its own Node in a scene. It runs independently of the office script.
extends Node

# Movement Path Logic
const ROOMS := {
	1: "Yondr Room",
	2: "Bellermine",
	3: "Admin",
	4: "Right Hall",
	5: "Left Hall",
	6: "Classroom1",
	7: "Classroom2",
	8: "Mrs. E's Room",
}

# Placeholder movement paths; these have NOT been adjusted to the FNAP map.
const FREDDY_MOVEMENT_PATH := [2, 5, 3, 4]
const BONNIE_MOVEMENT_PATH := [2, 5, 6, 7]
const CHICA_MOVEMENT_PATH := [2, 8, 3, 4]

const NIGHT_DURATIONS := {
	1: 360.0,
	2: 360.0,
	3: 360.0,
	4: 360.0,
	5: 360.0,
}

@export var auto_start: bool = true

# Define Class for Animatronic
class Animatronic:
	extends RefCounted

	var name: String
	var location: int
	var aggression: int
	var movement_path: Array
	var current_index: int
	var movement_interval: float
	var last_movement_time: float
	var room_names: Dictionary

	func _init(animatronic_name: String, starting_location: int, initial_aggression: int, path: Array, rooms: Dictionary) -> void:
		name = animatronic_name
		location = starting_location
		aggression = initial_aggression
		movement_path = path.duplicate()
		room_names = rooms
		current_index = movement_path.find(location)
		movement_interval = 12.0 - float(aggression)
		last_movement_time = Time.get_ticks_msec() / 1000.0

	# Animatronic Moves
	func move() -> void:
		var current_time: float = Time.get_ticks_msec() / 1000.0
		var elapsed_time: float = current_time - last_movement_time

		if elapsed_time >= movement_interval:
			current_index = (current_index + 1) % movement_path.size()
			location = movement_path[current_index]
			last_movement_time = current_time
			print("--- %s moved to %s!" % [name, room_names.get(location, "Unknown room")])
		else:
			print("--- %s did not move this time. Aggression: %d, Time since last move: %.2f seconds" % [name, aggression, elapsed_time])

	func check_movement() -> void:
		var move_roll: int = randi_range(1, 10)
		if move_roll <= aggression:
			move()
		else:
			print("--- %s failed movement check. Aggression: %d, Roll: %d" % [name, aggression, move_roll])

	func reset() -> void:
		location = movement_path[0]
		current_index = 0
		last_movement_time = Time.get_ticks_msec() / 1000.0

	func add_aggression() -> void:
		aggression += 1
		print("Log: %s's aggression has increased to %d" % [name, aggression])

	func decrease_movement_interval() -> void:
		movement_interval = maxf(1.0, movement_interval - 1.0)
		print("Log: %s's movement interval has decreased to %.0f seconds" % [name, movement_interval])


var freddy: Animatronic
var bonnie: Animatronic
var chica: Animatronic
var animatronics: Array[Animatronic] = []

## Percentage points drained per real second, per active usage bar.
const POWER_DRAIN_PER_BAR: float = 0.15

var night: int = 1
@export var night_start_time: float = 0.0
## Authoritative battery on a 0-100 scale, drained continuously as a float.
## The HUD only ever shows an integer derived from this value.
@export var office_power: float = 100.0
var _tick_accumulator: float = 0.0
var _simulation_finished: bool = false
var _power_out: bool = false

enum GameState { NORMAL, POWER_OUT, GAME_OVER, NIGHT_WON, MUSIC_BOX_FAILED }
var game_state: GameState = GameState.NORMAL
var _night_active: bool = false
var _frozen_night_elapsed: float = -1.0
@onready var _music_box: MusicBox = $"../Desk/MusicBox"


func _ready() -> void:
	if auto_start:
		begin_simulation()


# Public: start or restart the standalone simulation.
func begin_simulation() -> void:
	freddy = Animatronic.new("Freddy", 2, 2, FREDDY_MOVEMENT_PATH, ROOMS)
	bonnie = Animatronic.new("Bonnie", 2, 5, BONNIE_MOVEMENT_PATH, ROOMS)
	chica = Animatronic.new("Chica", 2, 4, CHICA_MOVEMENT_PATH, ROOMS)
	animatronics = [freddy, bonnie, chica]
	night = 1
	_simulation_finished = false
	_tick_accumulator = 0.0
	start_night()
	set_process(true)


# Start Night Setup & Reset Functions
func start_night() -> void:
	night_start_time = Time.get_ticks_msec() / 1000.0
	office_power = 100.0
	_power_out = false
	_simulation_finished = false
	_tick_accumulator = 0.0
	_frozen_night_elapsed = -1.0
	game_state = GameState.NORMAL
	_night_active = true
	set_process(true)
	var office: Node = get_parent()
	if office != null and office.is_node_ready() and office.has_method("reset_night"):
		office.reset_night()


# Clock Timer Functions
func convert_elapsed_to_time(elapsed_time: float) -> int:
	# 60 real seconds = one in-game hour; zero displays as 12 AM.
	var hours: int = int(elapsed_time / 60.0)
	if hours == 0:
		hours = 12
	return hours


# Usage bars: baseline 1 + closed doors + closed vent + (monitor up OR one light).
# Reads the real office component state so nothing can drift out of sync.
func get_usage_bars() -> int:
	var usage: int = 1
	var office: Node = get_parent()
	if office != null:
		if office.left_closed:
			usage += 1
		if office.right_closed:
			usage += 1
		if office.vent_closed:
			usage += 1
		var cam: Node = office.get_node_or_null("CameraSystem")
		if cam != null and cam.is_monitor_up():
			usage += 1
		elif office.left_light_on or office.right_light_on:
			usage += 1
	return clampi(usage, 1, 5)


# Continuous, frame-rate-independent battery drain: 0.15 points/second per bar.
func drain_power(delta: float) -> void:
	if not _night_active or game_state != GameState.NORMAL or _power_out:
		return
	var usage_bars: int = get_usage_bars()
	office_power = maxf(0.0, office_power - float(usage_bars) * POWER_DRAIN_PER_BAR * delta)
	if office_power <= 0.0:
		on_power_out()


# Fires exactly once when the battery empties.
func on_power_out() -> void:
	if game_state != GameState.NORMAL or not _night_active:
		return
	if get_night_elapsed() >= float(NIGHT_DURATIONS[night]):
		win_night()
		return
	_power_out = true
	office_power = 0.0
	game_state = GameState.POWER_OUT
	var office: Node = get_parent()
	if office != null and office.has_method("power_out"):
		office.power_out()


func get_night_elapsed() -> float:
	if game_state == GameState.NIGHT_WON:
		return 360.0
	if _frozen_night_elapsed >= 0.0:
		return _frozen_night_elapsed
	return maxf(0.0, Time.get_ticks_msec() / 1000.0 - night_start_time)


func can_wind_music_box() -> bool:
	return game_state == GameState.NORMAL and _night_active


func on_music_box_empty() -> void:
	if not can_wind_music_box():
		return
	if get_night_elapsed() >= float(NIGHT_DURATIONS[night]):
		win_night()
		return
	_frozen_night_elapsed = get_night_elapsed()
	game_state = GameState.MUSIC_BOX_FAILED
	_night_active = false
	get_parent().freeze_for_music_box()
	_music_box.begin_failure()
	get_parent().get_node("PowerOutSequence").show_music_box_wait()


func finish_music_box_failure() -> void:
	if game_state != GameState.MUSIC_BOX_FAILED:
		return
	game_state = GameState.GAME_OVER
	_simulation_finished = true
	get_parent().get_node("PowerOutSequence").show_game_over("MUSIC BOX — ALPHA PLACEHOLDER")
	print("MUSIC BOX: GAME_OVER after %.2fs" % _music_box.failure_elapsed)


func win_night() -> void:
	if not _night_active or game_state == GameState.GAME_OVER or game_state == GameState.NIGHT_WON:
		return
	game_state = GameState.NIGHT_WON
	_night_active = false
	get_parent().lock_night_controls()
	get_parent().get_node("PowerOutSequence").show_victory(night == 5)
	print("Night %d has ended! 6 AM wins." % night)


func request_power_out_attack() -> void:
	if game_state != GameState.POWER_OUT or not _night_active:
		return
	if get_night_elapsed() >= float(NIGHT_DURATIONS[night]):
		win_night()
		return
	game_state = GameState.GAME_OVER
	_night_active = false
	_simulation_finished = true
	get_parent().get_node("PowerOutSequence").show_game_over()


func retry_current_night() -> void:
	if game_state != GameState.GAME_OVER:
		return
	animatronic_reset()
	start_night()


func advance_to_next_night() -> void:
	if game_state != GameState.NIGHT_WON or _simulation_finished:
		return
	if night >= 5:
		_simulation_finished = true
		print("All nights completed!")
		return
	night += 1
	print("Starting Night %d..." % night)
	start_night()
	animatronic_reset()
	all_animatronics_add_aggression()
	all_animatronics_decrease_movement_interval()


# All Animatronic Functions
func animatronic_reset() -> void:
	for animatronic in animatronics:
		animatronic.reset()

func all_animatronics_add_aggression() -> void:
	for animatronic in animatronics:
		animatronic.add_aggression()

func all_animatronic_movement_check() -> void:
	for animatronic in animatronics:
		animatronic.check_movement()

func all_animatronics_decrease_movement_interval() -> void:
	for animatronic in animatronics:
		animatronic.decrease_movement_interval()


# Main Game Loop -- night clock has priority over drain and both outage phases.
func _process(delta: float) -> void:
	if game_state == GameState.GAME_OVER or _simulation_finished:
		return
	if game_state == GameState.MUSIC_BOX_FAILED:
		_music_box.advance_failure(delta)
		return
	var sequence: Node = get_parent().get_node("PowerOutSequence")
	if game_state == GameState.NIGHT_WON:
		sequence.advance_victory(delta)
		return
	if not _night_active:
		return
	if get_night_elapsed() >= float(NIGHT_DURATIONS[night]):
		win_night()
		return

	if game_state == GameState.NORMAL:
		drain_power(delta)
		# Outage takes over if battery depletion happened on this frame.
		if game_state == GameState.NORMAL:
			_music_box.advance(delta)
	elif game_state == GameState.POWER_OUT:
		sequence.advance(delta)

	_tick_accumulator += delta
	while _tick_accumulator >= 1.0 and _night_active:
		_tick_accumulator -= 1.0
		_simulation_tick()


func _simulation_tick() -> void:
	var elapsed_time: float = get_night_elapsed()
	var hours: int = convert_elapsed_to_time(elapsed_time)
	print("Night %d | %d AM | %.2fs | Power %.1f%%" % [night, hours, elapsed_time, office_power])
	all_animatronic_movement_check()


# Dev note: Connect actual security cameras and doors to movement/power later.
# Names and paths are still placeholder FNAF test data, per the Python original.
