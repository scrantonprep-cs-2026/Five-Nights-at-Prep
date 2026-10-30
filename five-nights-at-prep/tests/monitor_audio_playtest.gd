class_name MonitorAudioPlaytest
extends PowerOutPlaytest

## Read-only live audio instrumentation. Drive the actual monitor with mouse input.
var _up_was_playing: bool = false
var _down_was_playing: bool = false
var _up_starts: int = 0
var _down_starts: int = 0
var _up_peak: float = -200.0
var _down_peak: float = -200.0
var _master: int = 0
var _switch_was_playing: bool = false
var _switch_starts: int = 0
var _switch_peak: float = -200.0
@onready var _switch: AudioStreamPlayer = $Office/CameraSystem/CameraSwitchSound
@onready var _up: AudioStreamPlayer = $Office/CameraSystem/CamerasUp
@onready var _down: AudioStreamPlayer = $Office/CameraSystem/CamerasDown

func _ready() -> void:
	super._ready()
	_master = AudioServer.get_bus_index(&"Master")
	print("MONITOR AUDIO: driver=%s master_muted=%s master_volume=%.1fdB" % [
		AudioServer.get_driver_name(), AudioServer.is_bus_mute(_master), AudioServer.get_bus_volume_db(_master)])

func _process(_delta: float) -> void:
	var up_playing: bool = _up.playing
	var down_playing: bool = _down.playing
	var peak: float = maxf(AudioServer.get_bus_peak_volume_left_db(_master, 0), AudioServer.get_bus_peak_volume_right_db(_master, 0))
	if up_playing and not _up_was_playing:
		_up_starts += 1
		_up_peak = -200.0
		print("MONITOR AUDIO: UP started #%d, monitor=%s" % [_up_starts, office.camera_system.is_monitor_up()])
	if down_playing and not _down_was_playing:
		_down_starts += 1
		_down_peak = -200.0
		print("MONITOR AUDIO: DOWN started #%d, monitor=%s" % [_down_starts, office.camera_system.is_monitor_up()])
	if up_playing:
		_up_peak = maxf(_up_peak, peak)
	if down_playing:
		_down_peak = maxf(_down_peak, peak)
	if _up_was_playing and not up_playing:
		print("MONITOR AUDIO: UP stopped, measured Master peak=%.2fdBFS non_silent=%s" % [_up_peak, _up_peak > -60.0])
	if _down_was_playing and not down_playing:
		print("MONITOR AUDIO: DOWN stopped, measured Master peak=%.2fdBFS non_silent=%s" % [_down_peak, _down_peak > -60.0])
	_up_was_playing = up_playing
	_down_was_playing = down_playing
	var switch_playing: bool = _switch.playing
	if switch_playing and not _switch_was_playing:
		_switch_starts += 1
		_switch_peak = -200.0
		print("MONITOR AUDIO: SWITCH started #%d, CAM %d" % [_switch_starts, office.camera_system.current_camera_id])
	if switch_playing:
		_switch_peak = maxf(_switch_peak, peak)
	if _switch_was_playing and not switch_playing:
		print("MONITOR AUDIO: SWITCH stopped, measured Master peak=%.2fdBFS non_silent=%s" % [_switch_peak, _switch_peak > -60.0])
	_switch_was_playing = switch_playing
