class_name PowerOutSequence
extends Node

## Alpha timings, in real seconds. Only FNAP_Beta_Code advances this controller.
@export_range(0.1, 60.0) var red_light_duration: float = 20.0
@export_range(0.1, 60.0) var blackout_min_duration: float = 3.0
@export_range(0.1, 60.0) var blackout_max_duration: float = 5.0
## Selected once per outage, never rerolled while waiting in darkness.
var blackout_duration: float = 0.0
@export_range(0.1, 30.0) var victory_display_duration: float = 2.0

enum Phase { IDLE, RED, BLACK, GAME_OVER, WON, MUSIC_BOX_WAIT }
var phase: Phase = Phase.IDLE
var phase_elapsed: float = 0.0
var _victory_elapsed: float = 0.0
var _office: Node
var _systems: Node
var _environment: Environment
var _normal_ambient: float = 0.0
var _normal_background: Color
var _normal_ceiling_visible: bool = true
var _cover: ColorRect
var _outcome: Label
var _retry: Button
var _power_down_sound: AudioStreamPlayer
var _victory_chime_sound: AudioStreamPlayer
@onready var emergency_light: OmniLight3D = $EmergencyRedLight
@onready var piano: AudioStreamPlayer = $PowerOutPiano

func _ready() -> void:
	_office = get_parent()
	_systems = _office.get_node("AIandSystems")
	var world: WorldEnvironment = _office.get_node("WorldEnvironment") as WorldEnvironment
	# Keep retry/restoration local to this instance, including test subviewports.
	_environment = world.environment.duplicate() as Environment
	world.environment = _environment
	_normal_ambient = _environment.ambient_light_energy
	_normal_background = _environment.background_color
	var ceiling: OmniLight3D = _office.get_node("CeilingLight") as OmniLight3D
	_normal_ceiling_visible = ceiling.visible
	_power_down_sound = AudioStreamPlayer.new()
	_power_down_sound.name = "PowerDownSound"
	var power_down_stream: AudioStreamWAV = preload("res://powerdown.wav").duplicate() as AudioStreamWAV
	power_down_stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	_power_down_sound.stream = power_down_stream
	add_child(_power_down_sound)
	_victory_chime_sound = AudioStreamPlayer.new()
	_victory_chime_sound.name = "VictoryChime"
	_victory_chime_sound.stream = WestminsterChime.make_stream(false)
	add_child(_victory_chime_sound)
	_build_overlay()
	get_viewport().size_changed.connect(_layout)
	_layout()

func _build_overlay() -> void:
	var overlay: CanvasLayer = CanvasLayer.new()
	overlay.name = "BlackoutOverlay"
	overlay.layer = 50
	add_child(overlay)
	_cover = ColorRect.new()
	_cover.name = "BlackoutCover"
	_cover.color = Color.BLACK
	_cover.visible = false
	overlay.add_child(_cover)
	_outcome = Label.new()
	_outcome.name = "OutcomeLabel"
	_outcome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_outcome.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_outcome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_outcome.add_theme_font_size_override("font_size", 32)
	_outcome.visible = false
	_cover.add_child(_outcome)
	_retry = Button.new()
	_retry.name = "RetryNight"
	_retry.text = "RETRY CURRENT NIGHT"
	_retry.visible = false
	_retry.pressed.connect(_retry_current_night)
	_cover.add_child(_retry)

func _layout() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_cover.position = Vector2.ZERO
	_cover.size = vp
	_outcome.position = Vector2(20, vp.y * 0.32)
	_outcome.size = Vector2(vp.x - 40, 130)
	_retry.size = Vector2(240, 46)
	_retry.position = Vector2((vp.x - 240) * 0.5, vp.y * 0.65)

func begin_outage() -> void:
	if phase != Phase.IDLE:
		return
	phase = Phase.RED
	phase_elapsed = 0.0
	blackout_duration = randf_range(
		minf(blackout_min_duration, blackout_max_duration),
		maxf(blackout_min_duration, blackout_max_duration))
	_office.get_node("CeilingLight").visible = false
	_environment.ambient_light_energy = 0.0
	_environment.background_color = Color(0.006, 0.001, 0.001)
	emergency_light.visible = true
	_power_down_sound.play()
	if piano.stream != null:
		piano.play()
	print("POWER_OUT: RED emergency light")

func advance(delta: float) -> void:
	# No await/Timer callbacks: retry/win simply cancels the current phase.
	if phase != Phase.RED and phase != Phase.BLACK:
		return
	phase_elapsed += delta
	if phase == Phase.RED and phase_elapsed >= red_light_duration:
		phase = Phase.BLACK
		phase_elapsed = 0.0
		emergency_light.visible = false
		_cover.visible = true
		print("POWER_OUT: TOTAL BLACKOUT (%.2f seconds)" % blackout_duration)
	elif phase == Phase.BLACK and phase_elapsed >= blackout_duration:
		# Authority rechecks 6 AM even on the exact attack frame.
		_systems.request_power_out_attack()

func show_music_box_wait() -> void:
	phase = Phase.MUSIC_BOX_WAIT
	phase_elapsed = 0.0
	piano.stop()
	_power_down_sound.stop()
	_victory_chime_sound.stop()
	emergency_light.visible = false
	_cover.color = Color(0, 0, 0, 0.85)
	_cover.visible = true
	_outcome.text = "MUSIC BOX EMPTY\n..."
	_outcome.add_theme_font_size_override("font_size", 26)
	_outcome.visible = true
	_retry.visible = false

func show_game_over(reason: String = "POWER-OUT ATTACK — ALPHA PLACEHOLDER") -> void:
	phase = Phase.GAME_OVER
	piano.stop()
	_victory_chime_sound.stop()
	emergency_light.visible = false
	_cover.color = Color.BLACK
	_cover.visible = true
	_outcome.text = "GAME OVER\n" + reason
	_outcome.add_theme_font_size_override("font_size", 26)
	_outcome.visible = true
	_retry.visible = true
	print("POWER_OUT: GAME_OVER")

func show_victory(final_night: bool) -> void:
	# The authoritative 6 AM win calls this once; never restart an active cue.
	if phase == Phase.WON:
		return
	phase = Phase.WON
	phase_elapsed = 0.0
	_victory_elapsed = 0.0
	piano.stop()
	_power_down_sound.stop()
	emergency_light.visible = false
	_cover.color = Color.BLACK
	_cover.visible = true
	_outcome.text = "6 AM\nALL NIGHTS COMPLETE" if final_night else "6 AM\nNIGHT COMPLETE"
	_outcome.visible = true
	_retry.visible = false
	_victory_chime_sound.play()
	print("POWER_OUT: NIGHT_WON — pending attack cancelled")

func advance_victory(delta: float) -> void:
	if phase != Phase.WON:
		return
	_victory_elapsed += delta
	# Keep the existing minimum display time, but don't truncate the recording
	# or let it spill into gameplay. The authoritative night stays frozen at 6 AM.
	if _victory_elapsed >= victory_display_duration and not _victory_chime_sound.playing:
		_systems.advance_to_next_night()

func reset_sequence() -> void:
	phase = Phase.IDLE
	phase_elapsed = 0.0
	blackout_duration = 0.0
	_victory_elapsed = 0.0
	_power_down_sound.stop()
	_victory_chime_sound.stop()
	piano.stop()
	emergency_light.visible = false
	_cover.color = Color.BLACK
	_cover.visible = false
	_outcome.visible = false
	_retry.visible = false
	_environment.ambient_light_energy = _normal_ambient
	_environment.background_color = _normal_background
	_office.get_node("CeilingLight").visible = _normal_ceiling_visible

func _retry_current_night() -> void:
	_systems.retry_current_night()

func _exit_tree() -> void:
	if is_instance_valid(piano):
		piano.stop()
	if is_instance_valid(_victory_chime_sound):
		_victory_chime_sound.stop()
