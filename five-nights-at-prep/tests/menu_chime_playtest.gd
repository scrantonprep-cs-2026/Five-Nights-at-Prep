class_name MenuChimePlaytest
extends PrepMainMenu

## Live observer. L seeks near the end to test the real decoder's loop quickly;
## 7/8 resize to the usual two test sizes. Play uses the unmodified menu handler.
var _previous_position: float = 0.0
var _loop_wraps: int = 0
var _report_elapsed: float = 0.0

func _ready() -> void:
	super._ready()
	assert(menu_chime.playing)
	assert((menu_chime.stream as AudioStreamMP3).loop)
	assert(menu_chime.stream != WestminsterChime.SOURCE)
	print("MENU AUDIO TEST: L=seek near end, 7/8=resize; real Play handler opens office")

func _process(delta: float) -> void:
	assert(menu_chime.playing)
	assert(get_tree().root.find_children("AIandSystems", "", true, false).is_empty(), "Night must not start behind the title screen")
	var position_seconds: float = menu_chime.get_playback_position()
	if position_seconds + 5.0 < _previous_position:
		_loop_wraps += 1
		print("MENU CHIME LOOPED: wraps=%d position=%.3f playing=%s" % [_loop_wraps, position_seconds, menu_chime.playing])
	_previous_position = position_seconds
	_report_elapsed += delta
	if _report_elapsed >= 0.75:
		_report_elapsed = 0.0
		print("MENU CHIME SNAPSHOT: size=%s playing=%s position=%.3f loop=%s wraps=%d title=%s" % [size, menu_chime.playing, position_seconds, (menu_chime.stream as AudioStreamMP3).loop, _loop_wraps, (get_node("Center/Content/Title") as Label).text])

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.is_pressed() or event.is_echo():
		return
	match (event as InputEventKey).keycode:
		KEY_L:
			menu_chime.seek(maxf(0.0, menu_chime.stream.get_length() - 0.6))
			print("MENU TEST: seek near natural end; loop mode unchanged")
		KEY_7:
			get_window().size = Vector2i(960, 540)
		KEY_8:
			get_window().size = Vector2i(1152, 648)

func _exit_tree() -> void:
	super._exit_tree()
	assert(not menu_chime.playing)
	print("MENU CHIME EXIT: stopped=%s wraps=%d" % [not menu_chime.playing, _loop_wraps])
