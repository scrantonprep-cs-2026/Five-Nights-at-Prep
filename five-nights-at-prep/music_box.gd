class_name MusicBox
extends Area3D

## Seconds a full wind lasts on each night. No additional office power usage.
@export var night_durations: PackedFloat32Array = PackedFloat32Array([60.0, 50.0, 40.0, 30.0, 20.0])
## Seconds of charge restored per real second while holding the desk screen.
@export_range(1.0, 60.0) var wind_rate: float = 4.0
@export_range(0.1, 60.0) var failure_delay: float = 15.0

const WINDUP_SOUND_PATH = "res://windup2.wav"
const WINDUP_INTERVAL_MSEC = 400
@export_group("Winding Sound")
## Provisional restrained level; the supplied WAV must be present for mix tuning.
@export_range(-40.0, 0.0, 0.5) var windup_volume_db: float = -12.0:
	set(value):
		windup_volume_db = value
		if is_instance_valid(_windup_sound):
			_windup_sound.volume_db = value
var _windup_sound: AudioStreamPlayer
## Monotonic start-to-start deadline, not a second winding state or looping sample.
var _next_windup_at_msec: int = 0

var full_duration: float = 60.0
var remaining_seconds: float = 60.0
var failure_elapsed: float = 0.0
var failed: bool = false
var _failure_complete: bool = false
var _winding: bool = false
var _office: Node
var _systems: Node
var _cameras: CameraSystem
var _ring_material: ShaderMaterial
@onready var screen_viewport: SubViewport = $ScreenViewport
@onready var screen_mesh: MeshInstance3D = $Screen
## Empty future sound slot; no placeholder music is fabricated.
@onready var failure_sound: AudioStreamPlayer = $FailureSound

func _ready() -> void:
	_office = get_parent().get_parent()
	_systems = _office.get_node("AIandSystems")
	_cameras = _office.get_node("CameraSystem") as CameraSystem
	_cameras.monitor_opened.connect(stop_winding)
	mouse_exited.connect(stop_winding)
	_build_windup_audio()
	_build_screen()
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_texture = screen_viewport.get_texture()
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	screen_mesh.material_override = material
	reset_for_night(int(_systems.night))

func duration_for_night(night_index: int) -> float:
	if night_durations.is_empty():
		return 60.0
	var index: int = clampi(night_index - 1, 0, night_durations.size() - 1)
	return maxf(1.0, float(night_durations[index]))

func reset_for_night(night_index: int) -> void:
	full_duration = duration_for_night(night_index)
	remaining_seconds = full_duration
	failure_elapsed = 0.0
	failed = false
	_failure_complete = false
	stop_winding()
	if is_instance_valid(failure_sound):
		failure_sound.stop()
	if is_instance_valid(screen_mesh):
		screen_mesh.visible = true
	_refresh_display()

## Called by the existing authoritative night loop, after its 6 AM check.
func advance(delta: float) -> void:
	if failed:
		return
	if _winding and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		stop_winding()
	remaining_seconds = clampf(remaining_seconds + (wind_rate if _winding else -1.0) * delta, 0.0, full_duration)
	_refresh_display()
	_advance_windup_audio()
	if remaining_seconds <= 0.0:
		_systems.on_music_box_empty()

func begin_failure() -> void:
	if failed:
		return
	failed = true
	remaining_seconds = 0.0
	failure_elapsed = 0.0
	stop_winding()
	if failure_sound.stream != null:
		failure_sound.play()
	_refresh_display()
	print("MUSIC BOX: empty; gameplay frozen, %.1fs before game over" % failure_delay)

func advance_failure(delta: float) -> void:
	if not failed or _failure_complete:
		return
	failure_elapsed = minf(failure_elapsed + delta, failure_delay)
	if failure_elapsed >= failure_delay:
		_failure_complete = true
		failure_sound.stop()
		_systems.finish_music_box_failure()

func stop_winding() -> void:
	_winding = false
	_cancel_windup_audio()
	_refresh_display()

func is_winding() -> bool:
	return _winding

func _input_event(_camera: Camera3D, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if not failed and _systems.can_wind_music_box() and not _cameras.is_monitor_up():
			if not _winding:
				_winding = true
				if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
					_play_windup_click()
			_refresh_display()
			get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
	# Release anywhere, including over GUI, cannot leave winding latched on.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		stop_winding()

func _build_screen() -> void:
	# One centered gauge only: no percentage, seconds, headings or hints.
	var background: ColorRect = ColorRect.new()
	background.name = "ScreenUI"
	background.color = Color(0.035, 0.035, 0.035)
	background.size = Vector2(408, 240)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_viewport.add_child(background)
	var ring: ColorRect = ColorRect.new()
	ring.name = "WindGauge"
	ring.position = Vector2(104, 20)
	ring.size = Vector2(200, 200)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring_material = ShaderMaterial.new()
	_ring_material.shader = preload("res://assets/music_box_ring.gdshader")
	ring.material = _ring_material
	background.add_child(ring)

func _refresh_display() -> void:
	if _ring_material == null:
		return
	var ratio: float = clampf(remaining_seconds / full_duration, 0.0, 1.0)
	_ring_material.set_shader_parameter("charge", ratio)
	# Keep the whole charge range monochrome rather than changing to red/yellow.
	_ring_material.set_shader_parameter("fill_color", Color(0.70, 0.70, 0.70))

func _build_windup_audio() -> void:
	_windup_sound = AudioStreamPlayer.new()
	_windup_sound.name = "WindupSound"
	_windup_sound.max_polyphony = 1
	_windup_sound.pitch_scale = 1.0
	_windup_sound.volume_db = windup_volume_db
	add_child(_windup_sound)
	if not ResourceLoader.exists(WINDUP_SOUND_PATH):
		push_warning("MusicBox: required winding sound missing: " + WINDUP_SOUND_PATH + "; winding remains functional, audio inactive.")
		return
	var source: AudioStreamWAV = load(WINDUP_SOUND_PATH) as AudioStreamWAV
	if source == null:
		push_warning("MusicBox: required WAV failed to load: " + WINDUP_SOUND_PATH)
		return
	# Private resource: never change the supplied WAV or its import settings.
	var one_shot: AudioStreamWAV = source.duplicate() as AudioStreamWAV
	one_shot.loop_mode = AudioStreamWAV.LOOP_DISABLED
	_windup_sound.stream = one_shot

func _play_windup_click() -> void:
	if not is_instance_valid(_windup_sound) or _windup_sound.stream == null:
		return
	# A single voice; even a very quick re-press cannot overlap an earlier click.
	_windup_sound.stop()
	_windup_sound.play()
	_next_windup_at_msec = Time.get_ticks_msec() + WINDUP_INTERVAL_MSEC

func _advance_windup_audio() -> void:
	if not _winding or not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or not _systems.can_wind_music_box() or _cameras.is_monitor_up():
		_cancel_windup_audio()
		return
	# One trigger at most per frame. After a hitch, schedule from NOW, not a debt.
	if _next_windup_at_msec > 0 and Time.get_ticks_msec() >= _next_windup_at_msec:
		_play_windup_click()

func _cancel_windup_audio() -> void:
	_next_windup_at_msec = 0
	if is_instance_valid(_windup_sound):
		_windup_sound.stop()

func _exit_tree() -> void:
	_cancel_windup_audio()
