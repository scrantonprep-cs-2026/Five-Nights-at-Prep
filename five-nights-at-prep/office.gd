class_name Office
extends Node3D

const DOOR_CLOSED_Y := 1.1
const DOOR_OPEN_Y := 3.35
const DOOR_SPEED := 6.0

const VENT_CLOSED_Y := 1.0
const VENT_OPEN_Y := 1.95
const VENT_SPEED := 2.5

## Preserve the existing office's complete left/right look range.
const PAN_MAX_DEG := 22.0
## Small integration steps keep acceleration consistent through moderate FPS drops.
const PAN_STEP_SECONDS := 1.0 / 120.0

@export_group("Office Camera Panning")
## Normalized distance from center; 0.15 means a neutral 15% of the full width.
@export_range(0.0, 0.4, 0.01) var pan_deadzone: float = 0.15
@export_range(1.0, 3.0, 0.05) var pan_curve_exponent: float = 1.5
@export_range(85.0, 150.0, 1.0) var pan_max_speed_deg: float = 110.0
@export_range(100.0, 2000.0, 25.0) var pan_acceleration_deg: float = 750.0
@export_range(100.0, 2000.0, 25.0) var pan_deceleration_deg: float = 1000.0

@onready var _systems: FNAPSystems = $AIandSystems
@onready var player: Camera3D = $Player
@onready var camera_system: CameraSystem = $CameraSystem
@onready var music_box: MusicBox = $Desk/MusicBox
@onready var left_door: Node3D = $LeftDoor
@onready var right_door: Node3D = $RightDoor
@onready var vent_cover: CSGBox3D = $VentCover
@onready var left_hall_light: OmniLight3D = $HallLeftLight
@onready var right_hall_light: OmniLight3D = $HallRightLight
@onready var left_door_button: OfficeButton = $LeftDoorButton
@onready var left_light_button: OfficeButton = $LeftLightButton
@onready var right_door_button: OfficeButton = $RightDoorButton
@onready var right_light_button: OfficeButton = $RightLightButton
@onready var vent_button: OfficeButton = $VentButton
@onready var left_sound: AudioStreamPlayer3D = $LeftDoorSound
@onready var right_sound: AudioStreamPlayer3D = $RightDoorSound
@onready var vent_sound: AudioStreamPlayer3D = $VentDoorSound
@onready var left_light_sound: AudioStreamPlayer3D = $LeftDoorLight
@onready var right_light_sound: AudioStreamPlayer3D = $RightDoorLight
@onready var button_click_sound: AudioStreamPlayer3D = $ButtonClickSound



var left_closed: bool = false
var right_closed: bool = false
var vent_closed: bool = false
var left_light_on: bool = false
var right_light_on: bool = false

var _pan: float = 0.0
var _pan_velocity_deg: float = 0.0
var _mouse_pos: Vector2 = Vector2.ZERO
var _pan_pointer_valid: bool = false
## Native has_focus() stays false for some editor-embedded macOS windows.
## Track logical focus signals; require fresh pointer input after any focus loss.
var _pan_window_focused: bool = true
var _has_power: bool = true
var _music_box_frozen: bool = false


func _ready() -> void:
	_mouse_pos = get_viewport().get_visible_rect().size * 0.5

	left_door_button.pressed.connect(_toggle_left_door)
	left_light_button.pressed.connect(_toggle_left_light)
	right_door_button.pressed.connect(_toggle_right_door)
	right_light_button.pressed.connect(_toggle_right_light)
	vent_button.pressed.connect(_toggle_vent)
	camera_system.monitor_opened.connect(_turn_off_lights)
	camera_system.monitor_opened.connect(_stop_pan)
	get_window().mouse_exited.connect(_on_pan_input_lost)
	get_window().focus_exited.connect(_on_pan_focus_lost)
	get_window().focus_entered.connect(_on_pan_focus_returned)
	get_viewport().size_changed.connect(_on_pan_input_lost)

	reset_night()


func _input(event: InputEvent) -> void:
	# Observe position only. Never capture the cursor or consume office/GUI input.
	if event is InputEventMouseMotion:
		_mouse_pos = event.position
	elif event is InputEventMouseButton and event.pressed:
		_mouse_pos = event.position
	else:
		return
	_pan_pointer_valid = get_viewport().get_visible_rect().has_point(_mouse_pos)


## Keyboard shortcuts share the mouse toggles, including sounds and indicators.
## Event edges only: ignore OS key-repeat, and never queue input across a lock.
func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	if not _has_power or _music_box_frozen or camera_system.is_monitor_busy():
		return
	if _systems.game_state != FNAPSystems.GameState.NORMAL or not _systems._night_active or _systems.office_power <= 0.0:
		return
	# Input can arrive before this frame's clock/power update. Guard 6 AM too.
	var night_length: float = float(FNAPSystems.NIGHT_DURATIONS.get(_systems.night, 360.0))
	if _systems.get_night_elapsed() >= night_length:
		return
	if event.is_action_pressed(&"office_toggle_left_door", false, true):
		_toggle_left_door()
	elif event.is_action_pressed(&"office_toggle_right_door", false, true):
		_toggle_right_door()
	elif event.is_action_pressed(&"office_toggle_vent_gate", false, true):
		_toggle_vent()
	else:
		return
	get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _music_box_frozen:
		return
	_update_pan(delta)

	left_door.position.y = move_toward(
		left_door.position.y,
		DOOR_CLOSED_Y if left_closed else DOOR_OPEN_Y,
		DOOR_SPEED * delta
	)
	right_door.position.y = move_toward(
		right_door.position.y,
		DOOR_CLOSED_Y if right_closed else DOOR_OPEN_Y,
		DOOR_SPEED * delta
	)
	vent_cover.position.y = move_toward(
		vent_cover.position.y,
		VENT_CLOSED_Y if vent_closed else VENT_OPEN_Y,
		VENT_SPEED * delta
	)


## Positive Camera3D Y rotation looks LEFT in this office, so invert cursor X.
func get_pan_target_speed(mouse_x: float, viewport_width: float) -> float:
	if viewport_width <= 0.0:
		return 0.0
	var normalized_x: float = clampf(mouse_x / viewport_width * 2.0 - 1.0, -1.0, 1.0)
	var deadzone: float = clampf(pan_deadzone, 0.0, 0.95)
	var amount: float = clampf((absf(normalized_x) - deadzone) / (1.0 - deadzone), 0.0, 1.0)
	var strength: float = pow(amount, maxf(1.0, pan_curve_exponent))
	return -signf(normalized_x) * maxf(0.0, pan_max_speed_deg) * strength


func _update_pan(delta: float) -> void:
	# Locks stop momentum, not the angle. Include BOTH flip directions, power-out,
	# outcomes, and winding (so the desk screen cannot move away during a hold).
	if not _has_power or _music_box_frozen or camera_system.is_monitor_busy() or music_box.is_winding():
		_stop_pan()
		return
	if not _pan_pointer_valid or not _pan_window_focused:
		_stop_pan()
		return
	var target_speed: float = get_pan_target_speed(_mouse_pos.x, get_viewport().get_visible_rect().size.x)
	_integrate_pan(target_speed, delta)


func _integrate_pan(target_speed: float, delta: float) -> void:
	var remaining: float = maxf(0.0, delta)
	while remaining > 0.0:
		var step: float = minf(remaining, PAN_STEP_SECONDS)
		# Reverse by braking through zero first; never jump the velocity's sign.
		var phase_target: float = 0.0 if _pan_velocity_deg * target_speed < 0.0 else target_speed
		var rate: float = pan_deceleration_deg if absf(phase_target) < absf(_pan_velocity_deg) else pan_acceleration_deg
		rate = maxf(1.0, rate)
		var ramp_time: float = minf(step, absf(phase_target - _pan_velocity_deg) / rate)
		var old_speed: float = _pan_velocity_deg
		_pan_velocity_deg = move_toward(old_speed, phase_target, rate * ramp_time)
		# Integrate the acceleration ramp plus any time already at target speed.
		var travel: float = (old_speed + _pan_velocity_deg) * 0.5 * ramp_time
		travel += _pan_velocity_deg * (step - ramp_time)
		_pan = clampf(_pan + travel, -PAN_MAX_DEG, PAN_MAX_DEG)
		if (_pan >= PAN_MAX_DEG and _pan_velocity_deg > 0.0) or (_pan <= -PAN_MAX_DEG and _pan_velocity_deg < 0.0):
			_stop_pan()
			break
		remaining = maxf(0.0, remaining - step)
	# No pitch/roll changes, angle interpolation, target-angle snapping or recenter.
	player.rotation.y = deg_to_rad(_pan)


func _stop_pan() -> void:
	_pan_velocity_deg = 0.0


func _on_pan_focus_lost() -> void:
	_pan_window_focused = false
	_on_pan_input_lost()


func _on_pan_focus_returned() -> void:
	_pan_window_focused = true
	_on_pan_input_lost()


func _on_pan_input_lost() -> void:
	# Require fresh in-viewport input after exit, focus loss or a resize.
	_pan_pointer_valid = false
	_mouse_pos = get_viewport().get_visible_rect().size * 0.5
	_stop_pan()


func _sync_buttons() -> void:
	left_door_button.set_active(left_closed)
	right_door_button.set_active(right_closed)
	vent_button.set_active(vent_closed)
	left_light_button.set_active(left_light_on)
	right_light_button.set_active(right_light_on)


## Finish the CURRENT movement before accepting another key/click for that device.
## Full travel is ~0.38s. Locks are independent; ignored presses are never queued.
static func _mechanism_is_moving(mechanism: Node3D, target_y: float) -> bool:
	return not is_equal_approx(mechanism.position.y, target_y)


func _toggle_left_door() -> void:
	if not _has_power or _mechanism_is_moving(left_door, DOOR_CLOSED_Y if left_closed else DOOR_OPEN_Y):
		return
	button_click_sound.play()
	left_closed = not left_closed
	left_sound.play()
	_sync_buttons()


func _toggle_right_door() -> void:
	if not _has_power or _mechanism_is_moving(right_door, DOOR_CLOSED_Y if right_closed else DOOR_OPEN_Y):
		return
	button_click_sound.play()
	right_closed = not right_closed
	right_sound.play()
	_sync_buttons()


func _toggle_vent() -> void:
	if not _has_power or _mechanism_is_moving(vent_cover, VENT_CLOSED_Y if vent_closed else VENT_OPEN_Y):
		return
	button_click_sound.play()
	vent_closed = not vent_closed
	vent_sound.play()
	_sync_buttons()



func _toggle_left_light() -> void:
	if not _has_power:
		return
	button_click_sound.play()
	left_light_on = not left_light_on

	if left_light_on:
		right_light_on = false
		right_hall_light.visible = false
		right_light_sound.stop()
		left_light_sound.play()
	else:
		left_light_sound.stop()

	left_hall_light.visible = left_light_on
	_sync_buttons()



func _toggle_right_light() -> void:
	if not _has_power:
		return
	button_click_sound.play()
	right_light_on = not right_light_on

	if right_light_on:
		left_light_on = false
		left_hall_light.visible = false
		left_light_sound.stop()
		right_light_sound.play()
	else:
		right_light_sound.stop()

	right_hall_light.visible = right_light_on
	_sync_buttons()


## Kill the hall lights when the monitor comes up: you can't light the halls
## while looking at the cameras.
func _turn_off_lights() -> void:
	if not left_light_on and not right_light_on:
		return
	left_light_on = false
	right_light_on = false
	left_hall_light.visible = false
	right_hall_light.visible = false
	left_light_sound.stop()
	right_light_sound.stop()
	_sync_buttons()


## Power-out: the battery is empty, so every powered device dies and the wall
## buttons stop responding. Fired exactly once by FNAP_Beta_Code's drain.
func power_out() -> void:
	if not _has_power:
		return
	music_box.stop_winding()
	music_box.screen_mesh.visible = false
	_has_power = false
	_stop_pan()
	camera_system.set_monitor_enabled(false)
	left_closed = false
	right_closed = false
	vent_closed = false
	left_light_on = false
	right_light_on = false
	left_hall_light.visible = false
	right_hall_light.visible = false
	left_sound.stop()
	right_sound.stop()
	vent_sound.stop()
	left_light_sound.stop()
	right_light_sound.stop()
	button_click_sound.stop()
	_sync_buttons()
	get_node("PowerOutSequence").begin_outage()


## Used by initial setup, retry and the existing next-night progression.
func reset_night() -> void:
	_music_box_frozen = false
	music_box.reset_for_night(int(get_node("AIandSystems").night))
	_has_power = true
	left_closed = false
	right_closed = false
	vent_closed = false
	left_light_on = false
	right_light_on = false
	left_hall_light.visible = false
	right_hall_light.visible = false
	left_door.position.y = DOOR_OPEN_Y
	right_door.position.y = DOOR_OPEN_Y
	vent_cover.position.y = VENT_OPEN_Y
	left_sound.stop()
	right_sound.stop()
	vent_sound.stop()
	left_light_sound.stop()
	right_light_sound.stop()
	button_click_sound.stop()
	_pan = 0.0
	player.rotation.y = 0.0
	_on_pan_input_lost()
	camera_system.set_monitor_enabled(true)
	get_node("PowerOutSequence").reset_sequence()
	_sync_buttons()


func lock_night_controls() -> void:
	_has_power = false
	_stop_pan()
	music_box.stop_winding()
	camera_system.set_monitor_enabled(false)
	_turn_off_lights()


## Freeze in place without pausing the shared tree: only the 15s failure advances.
func freeze_for_music_box() -> void:
	_music_box_frozen = true
	lock_night_controls()
	left_sound.stop()
	right_sound.stop()
	vent_sound.stop()
	button_click_sound.stop()
