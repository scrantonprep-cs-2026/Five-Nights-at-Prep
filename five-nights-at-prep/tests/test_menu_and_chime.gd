class_name MenuAndChimeTests
extends Node

func test_project_starts_at_the_title_menu() -> void:
	assert(String(ProjectSettings.get_setting("application/run/main_scene")) == "res://scenes/main_menu.tscn")
	assert(PrepMainMenu.OFFICE_SCENE_PATH == "res://scenes/office.tscn")
	assert(ResourceLoader.exists(PrepMainMenu.OFFICE_SCENE_PATH))

func test_black_title_menu_has_one_wired_play_button_and_no_running_office() -> void:
	var packed: PackedScene = load("res://scenes/main_menu.tscn") as PackedScene
	var menu: PrepMainMenu = packed.instantiate() as PrepMainMenu
	assert(menu != null)
	var background: ColorRect = menu.get_node("Background") as ColorRect
	var title: Label = menu.get_node("Center/Content/Title") as Label
	var play: Button = menu.get_node("Center/Content/PlayButton") as Button
	var audio: AudioStreamPlayer = menu.get_node("MenuChime") as AudioStreamPlayer
	assert(background.color == Color.BLACK)
	assert(background.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	assert(title.text == "Five Nights at Prep")
	assert(play.text == "Play" and not play.disabled)
	assert(play.pressed.is_connected(Callable(menu, "_on_play_pressed")))
	assert(menu.find_children("*", "Camera3D", true, false).is_empty())
	assert(menu.find_children("AIandSystems", "", true, false).is_empty())
	assert(not audio.autoplay, "Ready configures a private loop resource before playing")
	menu.free()

func test_uploaded_recording_remains_the_unmodified_nonlooping_source() -> void:
	assert(WestminsterChime.SOURCE_PATH == "res://addons/DUFA WESTMINSTER CHIME LONGCASE GRANDFATHER CLOCK - sodaclublad.mp3")
	assert(WestminsterChime.SOURCE is AudioStreamMP3)
	assert(not WestminsterChime.SOURCE.loop)
	assert(WestminsterChime.SOURCE.get_length() > 0.0)

func test_menu_and_victory_have_independent_loop_settings() -> void:
	var menu_stream: AudioStreamMP3 = WestminsterChime.make_stream(true)
	var victory_stream: AudioStreamMP3 = WestminsterChime.make_stream(false)
	assert(menu_stream != victory_stream and menu_stream != WestminsterChime.SOURCE and victory_stream != WestminsterChime.SOURCE)
	assert(menu_stream.loop and not victory_stream.loop)
	assert(is_zero_approx(menu_stream.loop_offset))
	assert(is_zero_approx(victory_stream.loop_offset))
	assert(is_equal_approx(menu_stream.get_length(), victory_stream.get_length()))
	menu_stream.loop = false
	assert(not WestminsterChime.SOURCE.loop and not victory_stream.loop)
	menu_stream.loop = true
	assert(not WestminsterChime.SOURCE.loop and not victory_stream.loop)
