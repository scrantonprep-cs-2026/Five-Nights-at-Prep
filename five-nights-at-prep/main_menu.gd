class_name PrepMainMenu
extends Control

const OFFICE_SCENE_PATH = "res://scenes/office.tscn"

var _starting: bool = false
@onready var play_button: Button = $Center/Content/PlayButton
@onready var menu_chime: AudioStreamPlayer = $MenuChime

func _ready() -> void:
	menu_chime.stream = WestminsterChime.make_stream(true)
	menu_chime.play()
	play_button.grab_focus.call_deferred()

func _on_play_pressed() -> void:
	if _starting:
		return
	_starting = true
	play_button.disabled = true
	menu_chime.stop()
	# Load the existing office only after Play: no hidden night/battery countdown.
	var error: Error = get_tree().change_scene_to_file(OFFICE_SCENE_PATH)
	if error != OK:
		_starting = false
		play_button.disabled = false
		menu_chime.play()
		push_error("Main menu could not open the office: %s" % error_string(error))

func _exit_tree() -> void:
	if is_instance_valid(menu_chime):
		menu_chime.stop()
