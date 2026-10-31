class_name VentTracker
extends Control

## A read-only page inside the ORIGINAL monitor. No vent AI or power ownership.
const MAP_PATH = "res://assets/maps/Retro Ventilation Network Map.png"

## Assigned by CameraSystem to the real office; reads its actual vent_closed flag.
var gate_source: Node
var _map_image: TextureRect
var _markers_layer: Control
var _heading: Label
var _gate_status: Label
var _contact_status: Label
var _background: ColorRect
var _contacts: Dictionary = {}
var _markers: Dictionary = {}

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_background = ColorRect.new()
	_background.name = "Background"
	_background.color = Color(0.014, 0.018, 0.016)
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_background)
	_map_image = TextureRect.new()
	_map_image.name = "VentMap"
	_map_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_map_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_map_image.texture = load(MAP_PATH) as Texture2D
	if _map_image.texture == null:
		push_warning("VentTracker: required map unavailable: " + MAP_PATH)
	add_child(_map_image)
	_markers_layer = Control.new()
	_markers_layer.name = "ActualContacts"
	_markers_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_markers_layer)
	_heading = _make_label("Heading", "VENT NETWORK", 20)
	_gate_status = _make_label("GateStatus", "STATUS UNAVAILABLE", 17)
	_contact_status = _make_label("ContactStatus", "TRACKER STANDBY\nNO CONTACT DATA", 14)
	resized.connect(_layout)
	visibility_changed.connect(_on_visibility_changed)
	set_process(false)

func _ready() -> void:
	_layout()
	_on_visibility_changed()

func _make_label(node_name: String, text: String, font_size: int) -> Label:
	var label: Label = Label.new()
	label.name = node_name
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mono: SystemFont = SystemFont.new()
	mono.font_names = PackedStringArray(["Menlo", "DejaVu Sans Mono", "Courier New", "monospace"])
	label.add_theme_font_override("font", mono)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(0.72, 0.78, 0.74))
	add_child(label)
	return label

func _on_visibility_changed() -> void:
	set_process(is_visible_in_tree())
	if is_visible_in_tree():
		refresh_gate_status()

func _process(_delta: float) -> void:
	refresh_gate_status()

func refresh_gate_status() -> void:
	var state: Variant = gate_source.get("vent_closed") if is_instance_valid(gate_source) else null
	_gate_status.text = ("GATE CLOSED" if state else "GATE OPEN") if state is bool else "STATUS UNAVAILABLE"

## Future DATA INPUT ONLY: call for a real, current contact, never random dots.
## Coordinates are normalized over the ENTIRE original image, including its border.
## This does NOT establish vent nodes, routing, sensors, or AI/map correspondence.
## Returns false for an empty ID or coordinates outside [0, 1] (including NaN).
func update_contact(contact_id: StringName, normalized_position: Vector2) -> bool:
	if contact_id == &"" or not (normalized_position.x >= 0.0 and normalized_position.x <= 1.0 and normalized_position.y >= 0.0 and normalized_position.y <= 1.0):
		return false
	_contacts[contact_id] = normalized_position
	if not _markers.has(contact_id):
		var marker: Label = Label.new()
		marker.name = "Contact"
		marker.text = "●"
		marker.size = Vector2(18, 18)
		marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		marker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		marker.add_theme_font_size_override("font_size", 16)
		marker.add_theme_color_override("font_color", Color(0.85, 0.64, 0.32))
		_markers_layer.add_child(marker)
		_markers[contact_id] = marker
	_layout_markers()
	_refresh_contact_status()
	return true

## Call when a real contact is lost; no fabricated expiration/movement simulation.
func remove_contact(contact_id: StringName) -> void:
	if _markers.has(contact_id):
		var marker: Label = _markers[contact_id] as Label
		_markers_layer.remove_child(marker)
		marker.queue_free()
		_markers.erase(contact_id)
	_contacts.erase(contact_id)
	_refresh_contact_status()

## The monitor calls this on shutdown/reset, so detections cannot leak into retry.
func clear_contacts() -> void:
	for marker: Label in _markers.values():
		_markers_layer.remove_child(marker)
		marker.queue_free()
	_markers.clear()
	_contacts.clear()
	_refresh_contact_status()

func get_contact_count() -> int:
	return _contacts.size()

func _refresh_contact_status() -> void:
	_contact_status.text = "TRACKER STANDBY\nNO CONTACT DATA" if _contacts.is_empty() else "CONTACT DATA: %d" % _contacts.size()

## Actual contained IMAGE rectangle, not the larger letterboxed TextureRect.
func get_map_display_rect() -> Rect2:
	if _map_image.texture == null or _map_image.size.x <= 0.0 or _map_image.size.y <= 0.0:
		return Rect2()
	var native_size: Vector2 = _map_image.texture.get_size()
	var fit_scale: float = minf(_map_image.size.x / native_size.x, _map_image.size.y / native_size.y)
	var drawn_size: Vector2 = native_size * fit_scale
	return Rect2(_map_image.position + (_map_image.size - drawn_size) * 0.5, drawn_size)

func _layout_markers() -> void:
	var image_rect: Rect2 = get_map_display_rect()
	_markers_layer.position = image_rect.position
	_markers_layer.size = image_rect.size
	for contact_id: StringName in _contacts:
		var marker: Label = _markers[contact_id] as Label
		var normalized_position: Vector2 = _contacts[contact_id]
		marker.position = normalized_position * image_rect.size - marker.size * 0.5

func _layout() -> void:
	_background.size = size
	var sidebar_width: float = minf(220.0, size.x * 0.28)
	_map_image.position = Vector2(sidebar_width + 16.0, 0)
	_map_image.size = Vector2(maxf(1.0, size.x - sidebar_width - 16.0), maxf(1.0, size.y))
	_heading.position = Vector2(12, 12)
	_heading.size = Vector2(sidebar_width, 32)
	_gate_status.position = Vector2(12, 72)
	_gate_status.size = Vector2(sidebar_width, 30)
	_contact_status.position = Vector2(12, 128)
	_contact_status.size = Vector2(sidebar_width, 64)
	_layout_markers()
