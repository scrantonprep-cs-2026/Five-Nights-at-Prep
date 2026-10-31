class_name OfficeButton
extends Area3D

## A wall-mounted button the player clicks with the mouse. The plate shows
## `off_color` normally and `on_color` while the thing it controls is active.
## Emits `pressed` on a left click.

signal pressed

@export var off_color: Color = Color(0.85, 0.15, 0.12)
@export var on_color: Color = Color(0.2, 0.8, 0.3)

@onready var _mesh: MeshInstance3D = $Mesh

var _material: StandardMaterial3D
var _active: bool = false


func _ready() -> void:
	_material = StandardMaterial3D.new()
	_material.emission_enabled = true
	_material.emission_energy_multiplier = 0.4
	_mesh.material_override = _material
	_apply_color()

	mouse_entered.connect(_set_highlight.bind(true))
	mouse_exited.connect(_set_highlight.bind(false))


func set_active(active: bool) -> void:
	_active = active
	_apply_color()


func _input_event(_camera: Camera3D, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit()


func _apply_color() -> void:
	if _material == null:
		return
	var color: Color = on_color if _active else off_color
	_material.albedo_color = color
	_material.emission = color


func _set_highlight(on: bool) -> void:
	if _material != null:
		_material.emission_energy_multiplier = 0.9 if on else 0.4