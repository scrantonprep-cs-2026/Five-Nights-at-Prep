class_name CameraSystem
extends CanvasLayer

## The existing office monitor; no second camera or power system.
signal monitor_opened
const MAP_IMAGE_PATH = "res://assets/maps/FNAP_Camera_Map_Transparent.png"
const FLIP_FRAMES_PATH = "res://assets/monitor_flip/MonitorFlip.tres"
const CCTV_STATIC_SHADER = preload("res://assets/cctv_ambient_static.gdshader")
## Camera IDs, NOT the unrelated AI room-number dictionary.
const CAMERA_PHOTO_PATHS = {
	1: "res://CameraShots/Henfling-2.jpeg",
	2: "res://CameraShots/Bellermine-1.jpeg",
	3: "res://CameraShots/SpanishRoom.jpeg",
	4: "res://CameraShots/GillisRoom.jpeg",
	5: "res://CameraShots/AdminHall.jpeg",
	6: "res://CameraShots/LeftHall.jpeg",
	7: "res://CameraShots/RightHall.jpeg",
}
## Fraction of overflow cropped from the left/top (0 = top/left, 1 = bottom/right).
## Slightly lower classroom framing trades unused ceiling for desks/whiteboards.
## These normalized cover positions work at any viewport size; no JPEG edits.
const PHOTO_CROP_POSITIONS = {
	1: Vector2(0.5, 0.20),
	3: Vector2(0.5, 0.62),
	4: Vector2(0.5, 0.66),
	5: Vector2(0.5, 0.56),
	6: Vector2(0.5, 0.60),
	7: Vector2(0.5, 0.52),
}
const CAMERAS: Array[Dictionary] = [
	{"name": "Yondr Room", "norm": Vector2(0.142, 0.061), "color": Color(0.055, 0.075, 0.070)},
	{"name": "Bellarmine", "norm": Vector2(0.381, 0.262), "color": Color(0.080, 0.065, 0.050)},
	{"name": "Right Classroom", "norm": Vector2(0.903, 0.567), "color": Color(0.045, 0.060, 0.090)},
	{"name": "Left Classroom", "norm": Vector2(0.104, 0.663), "color": Color(0.080, 0.050, 0.075)},
	{"name": "Admin", "norm": Vector2(0.493, 0.168), "color": Color(0.065, 0.080, 0.045)},
	{"name": "Left Hall", "norm": Vector2(0.299, 0.759), "color": Color(0.085, 0.045, 0.045)},
	{"name": "Right Hall", "norm": Vector2(0.642, 0.760), "color": Color(0.040, 0.080, 0.085)},
]
@export_group("CCTV Ambient Static")
## Transparent idle grain; the source photographs are never regraded.
@export_range(0.0, 0.2, 0.005) var static_intensity: float = 0.10:
	set(value):
		static_intensity = value
		_update_static_settings()
## Speckle size in viewport pixels, independent of photo resolution/crop.
@export_range(0.5, 3.0, 0.25) var static_grain_size: float = 1.25:
	set(value):
		static_grain_size = value
		_update_static_settings()
@export_range(1.0, 60.0, 1.0) var static_updates_per_second: float = 30.0:
	set(value):
		static_updates_per_second = value
		_update_static_settings()
## Additional opacity in faint drifting bands. Set to 0 for grain only.
@export_range(0.0, 0.05, 0.001) var static_band_strength: float = 0.016:
	set(value):
		static_band_strength = value
		_update_static_settings()

@export_group("CCTV Camera Switch Burst")
@export_range(0.15, 0.25, 0.01) var switch_static_duration: float = 0.20
@export_range(0.0, 1.0, 0.01) var switch_static_opacity: float = 0.90:
	set(value):
		switch_static_opacity = value
		_update_static_settings()
@export_range(20.0, 60.0, 1.0) var switch_static_updates_per_second: float = 48.0:
	set(value):
		switch_static_updates_per_second = value
		_update_static_settings()

## One visual-only countdown, replaced (never added to) on each actual change.
var _switch_burst_remaining: float = 0.0
var _switch_burst_duration: float = 0.0

var current_camera_id: int = 1
var _photo_textures: Dictionary = {}
var _feed_photo: TextureRect
var _static_overlay: ColorRect
var _static_material: ShaderMaterial
var _rec_indicator: HBoxContainer
var _tablet_button: Button
var _ipad: Panel
var _feed: ColorRect
var _feed_label: Label
var _room_label: Label
var _close_button: Button
var _map_area: Control
var _map_image: TextureRect
var _hotspots: Control
var _map_backing: ColorRect
var _camera_tab: Button
var _vent_tab: Button
var _vent_tracker: VentTracker
var _camera_buttons: Array[Button] = []
var _flip_sprite: AnimatedSprite2D
var _map_tex_size: Vector2 = Vector2(1323, 1189)
var _vent_selected: bool = false
var _is_open: bool = false
var _flipping: bool = false
var _monitor_enabled: bool = true
@onready var camera_system_up_sound: AudioStreamPlayer = $CamerasUp
@onready var camera_system_down_sound: AudioStreamPlayer = $CamerasDown
@onready var camera_switch_sound: AudioStreamPlayer = $CameraSwitchSound

## Hard shutdown also cancels an in-progress flip; no second hover trigger.
func set_monitor_enabled(enabled: bool) -> void:
	_cancel_camera_switch_burst()
	_monitor_enabled = enabled
	_is_open = false
	_flipping = false
	_flip_sprite.stop()
	camera_system_up_sound.stop()
	camera_system_down_sound.stop()
	camera_switch_sound.stop()
	_flip_sprite.visible = false
	_ipad.visible = false
	_tablet_button.disabled = not enabled
	_tablet_button.visible = enabled
	_close_button.disabled = not enabled
	_vent_tracker.clear_contacts()

func _ready() -> void:
	layer = 10
	_load_feed_photos()
	_build_ui()
	_build_map()
	_build_flip()
	_layout()
	get_viewport().size_changed.connect(_layout)
	_refresh_feed()
	_ipad.visible = false
	_cancel_camera_switch_burst()

## Resolve once on startup, so a camera switch only swaps a cached texture.
## Missing assigned files get an explicit warning and an honest placeholder.
func _load_feed_photos() -> void:
	for camera_id: int in CAMERA_PHOTO_PATHS:
		var path: String = CAMERA_PHOTO_PATHS[camera_id]
		var photo: Texture2D = null
		if ResourceLoader.exists(path):
			photo = load(path) as Texture2D
		if photo == null:
			push_warning("CameraSystem: CAM %d photo unavailable: %s; keeping placeholder." % [camera_id, path])
		else:
			_photo_textures[camera_id] = photo

func _build_feed_visuals() -> void:
	# Children of the ORIGINAL feed, before all map/label/tab siblings.
	_feed.clip_contents = true
	_feed_photo = TextureRect.new()
	_feed_photo.name = "Photo"
	_feed_photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_feed_photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_feed_photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_feed.add_child(_feed_photo)
	_static_overlay = ColorRect.new()
	_static_overlay.name = "AmbientStatic"
	_static_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_static_material = ShaderMaterial.new()
	_static_material.shader = CCTV_STATIC_SHADER
	_static_overlay.material = _static_material
	_update_static_settings()
	_feed.add_child(_static_overlay)
	_static_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Small, non-flashing recording mark, clear of the close button and map.
	_rec_indicator = HBoxContainer.new()
	_rec_indicator.name = "RecordingIndicator"
	_rec_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rec_indicator.add_theme_constant_override("separation", 6)
	var dot: Label = _make_label("RedDot", 14)
	dot.text = "●"
	dot.add_theme_color_override("font_color", Color(0.75, 0.12, 0.10))
	_rec_indicator.add_child(dot)
	var rec: Label = _make_label("REC", 14)
	rec.text = "REC"
	_rec_indicator.add_child(rec)
	_ipad.add_child(_rec_indicator)

func _update_static_settings() -> void:
	if _static_material == null:
		return
	_static_material.set_shader_parameter("intensity", clampf(static_intensity, 0.0, 0.2))
	_static_material.set_shader_parameter("grain_size", maxf(static_grain_size, 0.5))
	_static_material.set_shader_parameter("updates_per_second", maxf(static_updates_per_second, 1.0))
	_static_material.set_shader_parameter("band_strength", clampf(static_band_strength, 0.0, 0.05))
	_static_material.set_shader_parameter("burst_opacity", clampf(switch_static_opacity, 0.0, 1.0))
	_static_material.set_shader_parameter("burst_updates_per_second", clampf(switch_static_updates_per_second, 20.0, 60.0))

## Starts at peak opacity BEFORE the cached texture/label swap in this same frame.
## A short peak masks the cut, followed by a smooth reveal; no delayed feed state.
func _start_camera_switch_burst() -> void:
	_switch_burst_duration = clampf(switch_static_duration, 0.15, 0.25)
	_switch_burst_remaining = _switch_burst_duration
	_static_material.set_shader_parameter("burst_amount", 1.0)
	set_process(true)

func _cancel_camera_switch_burst() -> void:
	_switch_burst_remaining = 0.0
	_switch_burst_duration = 0.0
	if _static_material != null:
		_static_material.set_shader_parameter("burst_amount", 0.0)
	set_process(false)

## CPU work only during the 0.2s transition. Idle animation stays GPU/TIME driven.
func _process(delta: float) -> void:
	if not _monitor_enabled or not _is_open or _flipping or _vent_selected:
		_cancel_camera_switch_burst()
		return
	_switch_burst_remaining = maxf(0.0, _switch_burst_remaining - delta)
	if _switch_burst_remaining <= 0.0:
		_cancel_camera_switch_burst()
		return
	# First quarter holds peak snow; last three quarters reveal the new feed.
	var remaining_ratio: float = _switch_burst_remaining / _switch_burst_duration
	_static_material.set_shader_parameter("burst_amount", smoothstep(0.0, 0.75, remaining_ratio))

## One UNIFORM scale, clipped by CameraFeed, with configurable overflow alignment.
static func get_photo_cover_rect(photo_size: Vector2, feed_size: Vector2, crop_position: Vector2 = Vector2(0.5, 0.5)) -> Rect2:
	if photo_size.x <= 0.0 or photo_size.y <= 0.0:
		return Rect2(Vector2.ZERO, feed_size)
	var cover_scale: float = maxf(feed_size.x / photo_size.x, feed_size.y / photo_size.y)
	var covered_size: Vector2 = photo_size * cover_scale
	var alignment: Vector2 = crop_position.clamp(Vector2.ZERO, Vector2.ONE)
	return Rect2((feed_size - covered_size) * alignment, covered_size)

func _layout_feed_photo() -> void:
	if _feed_photo.texture == null:
		return
	var crop_position: Vector2 = PHOTO_CROP_POSITIONS.get(current_camera_id, Vector2(0.5, 0.5))
	var photo_rect: Rect2 = get_photo_cover_rect(_feed_photo.texture.get_size(), _feed.size, crop_position)
	_feed_photo.position = photo_rect.position
	_feed_photo.size = photo_rect.size

func _build_ui() -> void:
	var root: Control = Control.new()
	root.name = "UIRoot"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_ipad = Panel.new()
	_ipad.name = "IPad"
	_ipad.add_theme_stylebox_override("panel", _flat_box(Color(0.025, 0.025, 0.03), Color.TRANSPARENT, 0, 0))
	root.add_child(_ipad)
	_feed = ColorRect.new()
	_feed.name = "CameraFeed"
	_feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ipad.add_child(_feed)
	_build_feed_visuals()
	_feed_label = _make_label("FeedLabel", 26)
	_ipad.add_child(_feed_label)
	_map_backing = ColorRect.new()
	_map_backing.name = "MapBacking"
	_map_backing.color = Color(0, 0, 0, 0.18)
	_map_backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ipad.add_child(_map_backing)
	_map_area = Control.new()
	_map_area.name = "MapArea"
	_map_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ipad.add_child(_map_area)
	_map_image = TextureRect.new()
	_map_image.name = "MapImage"
	_map_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_map_image.stretch_mode = TextureRect.STRETCH_SCALE
	_map_image.texture = load(MAP_IMAGE_PATH) as Texture2D
	if _map_image.texture != null:
		_map_tex_size = _map_image.texture.get_size()
	else:
		push_error("CameraSystem: required transparent map missing: " + MAP_IMAGE_PATH)
	_map_area.add_child(_map_image)
	_hotspots = Control.new()
	_hotspots.name = "Hotspots"
	_hotspots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_area.add_child(_hotspots)
	_room_label = _make_label("RoomName", 24)
	_ipad.add_child(_room_label)
	_vent_tracker = VentTracker.new()
	_vent_tracker.name = "VentTracker"
	_vent_tracker.gate_source = get_parent()
	_ipad.add_child(_vent_tracker)
	_camera_tab = _make_button("CamerasTab", "CAMERAS")
	_camera_tab.pressed.connect(_select_tab.bind(false))
	_ipad.add_child(_camera_tab)
	_vent_tab = _make_button("VentTrackerTab", "VENT TRACKER")
	_vent_tab.pressed.connect(_select_tab.bind(true))
	_ipad.add_child(_vent_tab)
	_close_button = _make_button("CloseButton", "X")
	_close_button.pressed.connect(_close_monitor)
	_ipad.add_child(_close_button)
	# Original monitor hover trigger and styling, last child for GUI picking.
	_tablet_button = Button.new()
	_tablet_button.name = "TabletButton"
	_tablet_button.text = "MONITOR"
	_tablet_button.focus_mode = Control.FOCUS_NONE
	_tablet_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_tablet_button.add_theme_font_size_override("font_size", 18)
	_tablet_button.add_theme_color_override("font_color", Color(0.14, 0.14, 0.16))
	_tablet_button.add_theme_stylebox_override("normal", _flat_box(Color(0.55, 0.56, 0.58), Color(0.30, 0.30, 0.32), 2, 8))
	_tablet_button.add_theme_stylebox_override("hover", _flat_box(Color(0.68, 0.69, 0.71), Color(0.30, 0.30, 0.32), 2, 8))
	_tablet_button.add_theme_stylebox_override("pressed", _flat_box(Color(0.45, 0.46, 0.48), Color(0.30, 0.30, 0.32), 2, 8))
	_tablet_button.mouse_entered.connect(_on_tablet_hovered)
	_tablet_button.z_index = 10
	root.add_child(_tablet_button)

func _make_label(node_name: String, font_size: int) -> Label:
	var label: Label = Label.new()
	label.name = node_name
	var mono: SystemFont = SystemFont.new()
	mono.font_names = PackedStringArray(["Menlo", "DejaVu Sans Mono", "Courier New", "monospace"])
	label.add_theme_font_override("font", mono)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(0.9, 0.92, 0.9))
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	return label

func _make_button(node_name: String, text: String) -> Button:
	var button: Button = Button.new()
	button.name = node_name
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_stylebox_override("normal", _flat_box(Color(0.04, 0.04, 0.04, 0.8), Color(0.6, 0.6, 0.6), 1, 0))
	button.add_theme_stylebox_override("hover", _flat_box(Color(0.35, 0.35, 0.35, 0.5), Color.WHITE, 1, 0))
	button.add_theme_stylebox_override("pressed", _flat_box(Color(0.35, 0.5, 0.35, 0.45), Color.WHITE, 1, 0))
	return button

func _build_map() -> void:
	for i: int in range(CAMERAS.size()):
		var button: Button = _make_button("CAM%d" % (i + 1), "")
		button.tooltip_text = "CAM %d — %s" % [i + 1, CAMERAS[i]["name"]]
		button.add_theme_stylebox_override("normal", _flat_box(Color.TRANSPARENT, Color.TRANSPARENT, 0, 0))
		button.pressed.connect(_on_camera_pressed.bind(i + 1))
		_hotspots.add_child(button)
		_camera_buttons.append(button)

func _on_camera_pressed(camera_id: int) -> void:
	if not _is_open or _flipping or _vent_selected:
		return
	var next_camera_id: int = clampi(camera_id, 1, CAMERAS.size())
	if next_camera_id == current_camera_id:
		return
	_start_camera_switch_burst()
	current_camera_id = next_camera_id
	camera_switch_sound.play()
	_refresh_feed()
	print("CameraSystem: CAM %d — %s" % [current_camera_id, _room_label.text])

func _refresh_feed() -> void:
	var camera: Dictionary = CAMERAS[current_camera_id - 1]
	_feed.color = camera["color"]
	# Assign null for placeholders too: never leave a prior camera's photo behind.
	_feed_photo.texture = _photo_textures.get(current_camera_id) as Texture2D
	var has_photo: bool = _feed_photo.texture != null
	_feed_photo.visible = has_photo and not _vent_selected
	_static_overlay.visible = not _vent_selected
	_rec_indicator.visible = not _vent_selected
	_feed_label.text = "CAM %d  /  %s" % [current_camera_id, camera["name"]]
	if not has_photo:
		_feed_label.text += "\nTEMPORARY CCTV FEED" if not CAMERA_PHOTO_PATHS.has(current_camera_id) else "\nPHOTO UNAVAILABLE — TEMPORARY CCTV FEED"
	_layout_feed_photo()
	_room_label.text = camera["name"]
	for i: int in range(_camera_buttons.size()):
		var selected: bool = i + 1 == current_camera_id
		_camera_buttons[i].add_theme_stylebox_override("normal", _flat_box(Color(0.45, 0.65, 0.45, 0.30) if selected else Color.TRANSPARENT, Color(0.8, 1, 0.8) if selected else Color.TRANSPARENT, 1 if selected else 0, 0))
	_map_area.visible = not _vent_selected
	_map_backing.visible = not _vent_selected
	_room_label.visible = not _vent_selected
	_feed_label.visible = not _vent_selected
	_feed.visible = not _vent_selected
	_vent_tracker.visible = _vent_selected
	if _vent_selected:
		_vent_tracker.refresh_gate_status()

func _select_tab(vent: bool) -> void:
	if not _is_open or _flipping:
		return
	if vent:
		_cancel_camera_switch_burst()
	_vent_selected = vent
	_refresh_feed()

func _build_flip() -> void:
	_flip_sprite = AnimatedSprite2D.new()
	_flip_sprite.name = "MonitorFlip"
	_flip_sprite.centered = true
	_flip_sprite.z_index = 100
	_flip_sprite.visible = false
	if ResourceLoader.exists(FLIP_FRAMES_PATH):
		_flip_sprite.sprite_frames = load(FLIP_FRAMES_PATH)
	else:
		push_warning("CameraSystem: monitor flip frames not found at " + FLIP_FRAMES_PATH)
	_flip_sprite.animation_finished.connect(_on_flip_finished)
	add_child(_flip_sprite)

func _on_tablet_hovered() -> void:
	if not _monitor_enabled or _flipping:
		return
	if _is_open:
		_close_monitor()
	else:
		_open_monitor()

func is_monitor_up() -> bool:
	return _is_open

## Query existing flip state without changing monitor behavior or power usage.
func is_monitor_busy() -> bool:
	return _is_open or _flipping

func _open_monitor() -> void:
	if not _monitor_enabled or _is_open or _flipping or _flip_sprite.sprite_frames == null:
		return
	_is_open = true
	_flipping = true
	_ipad.visible = false
	_flip_sprite.visible = true
	_flip_sprite.play("flip_up")
	camera_system_down_sound.stop()
	camera_system_up_sound.play()
	monitor_opened.emit()

func _close_monitor() -> void:
	if not _monitor_enabled or not _is_open or _flipping or _flip_sprite.sprite_frames == null:
		return
	_cancel_camera_switch_burst()
	_is_open = false
	_flipping = true
	_ipad.visible = false
	_flip_sprite.visible = true
	_flip_sprite.play("flip_down")
	camera_system_up_sound.stop()
	camera_system_down_sound.play()

func _on_flip_finished() -> void:
	_flip_sprite.visible = false
	_flipping = false
	_ipad.visible = _is_open

func _flat_box(fill: Color, border: Color, border_w: int, radius: int) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(border_w)
	box.set_corner_radius_all(radius)
	return box

func _layout() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_ipad.position = Vector2.ZERO
	_ipad.size = vp
	_feed.size = vp
	_layout_feed_photo()
	_rec_indicator.position = Vector2(vp.x - 154, 26)
	_rec_indicator.size = Vector2(70, 24)
	_tablet_button.size = Vector2(180, 46)
	_tablet_button.position = Vector2((vp.x - 180) * 0.5, vp.y - 60)
	_close_button.position = Vector2(vp.x - 64, 20)
	_close_button.size = Vector2(40, 40)
	_camera_tab.position = Vector2(160, 20)
	_camera_tab.size = Vector2(140, 36)
	_vent_tab.position = Vector2(312, 20)
	_vent_tab.size = Vector2(170, 36)
	_feed_label.position = Vector2(40, 100)
	_feed_label.size = Vector2(vp.x - 80, 90)
	# Separate contain-style page, clear of the unchanged navigation and flip UI.
	_vent_tracker.position = Vector2(24, 78)
	_vent_tracker.size = Vector2(maxf(1.0, vp.x - 48.0), maxf(1.0, vp.y - 154.0))
	# Image and overlay have identical dimensions; all marker positions scale together.
	var map_width: float = minf(vp.x * 0.37, (vp.y - 150.0) * _map_tex_size.x / _map_tex_size.y)
	var map_size: Vector2 = Vector2(map_width, map_width * _map_tex_size.y / _map_tex_size.x)
	_map_area.size = map_size
	_map_area.position = vp - map_size - Vector2(20, 20)
	_map_backing.position = _map_area.position
	_map_backing.size = map_size
	_map_image.size = map_size
	_hotspots.size = map_size
	_room_label.position = _map_area.position - Vector2(0, 40)
	_room_label.size = Vector2(map_size.x, 36)
	var hit_size: Vector2 = Vector2(84, 80) * (map_width / _map_tex_size.x)
	for i: int in range(_camera_buttons.size()):
		var norm: Vector2 = CAMERAS[i]["norm"]
		_camera_buttons[i].size = hit_size
		_camera_buttons[i].position = norm * map_size - hit_size * 0.5
	_layout_flip()

func _layout_flip() -> void:
	if _flip_sprite == null or _flip_sprite.sprite_frames == null:
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_flip_sprite.position = vp * 0.5
	var frame_tex: Texture2D = _flip_sprite.sprite_frames.get_frame_texture("flip_up", 0)
	var frame_size: Vector2 = frame_tex.get_size() if frame_tex != null else Vector2(1280, 720)
	var s: float = maxf(vp.x / frame_size.x, vp.y / frame_size.y)
	_flip_sprite.scale = Vector2(s, s)
