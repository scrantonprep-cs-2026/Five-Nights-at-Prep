class_name OfficeKeyboardShortcutTests
extends Node

const ACTIONS = [&"office_toggle_left_door", &"office_toggle_right_door", &"office_toggle_vent_gate"]
const KEYS = [KEY_A, KEY_D, KEY_W]

func test_input_map_has_three_distinct_keyboard_bindings() -> void:
	for index: int in range(ACTIONS.size()):
		assert(InputMap.has_action(ACTIONS[index]))
		var events: Array[InputEvent] = InputMap.action_get_events(ACTIONS[index])
		assert(events.size() == 1)
		assert(events[0] is InputEventKey)
		var binding: InputEventKey = events[0] as InputEventKey
		assert(binding.physical_keycode == KEYS[index])
		var press: InputEventKey = InputEventKey.new()
		press.physical_keycode = KEYS[index]
		press.pressed = true
		for other: int in range(ACTIONS.size()):
			assert(press.is_action_pressed(ACTIONS[other], false, true) == (other == index))

func test_releases_and_key_repeat_are_not_action_presses() -> void:
	for index: int in range(ACTIONS.size()):
		var event: InputEventKey = InputEventKey.new()
		event.physical_keycode = KEYS[index]
		assert(not event.is_action_pressed(ACTIONS[index], false, true))
		event.pressed = true
		assert(event.is_action_pressed(ACTIONS[index], false, true))
		event.echo = true
		assert(event.is_echo())
		assert(not event.is_action_pressed(ACTIONS[index], false, true))

func test_modified_keys_do_not_match_exact_gameplay_shortcuts() -> void:
	for index: int in range(ACTIONS.size()):
		var event: InputEventKey = InputEventKey.new()
		event.physical_keycode = KEYS[index]
		event.pressed = true
		event.ctrl_pressed = true
		assert(not event.is_action_pressed(ACTIONS[index], false, true))
