class_name OfficeMechanismLockTests
extends Node

## Guard-only contracts. Actual movement, input, sounds and reset are checked live.
func _make_guard_only_office() -> Office:
	var office: Office = Office.new()
	office.left_door = Node3D.new()
	office.right_door = Node3D.new()
	office.vent_cover = CSGBox3D.new()
	office.add_child(office.left_door)
	office.add_child(office.right_door)
	office.add_child(office.vent_cover)
	return office

func _set_closed_flags(office: Office, closed: bool) -> void:
	office.left_closed = closed
	office.right_closed = closed
	office.vent_closed = closed

func _request_all_toggles(office: Office) -> void:
	# No sounds/buttons are installed: a blocked call must return BEFORE effects.
	office._toggle_left_door()
	office._toggle_right_door()
	office._toggle_vent()

func test_short_lock_uses_original_door_and_vent_travel_times() -> void:
	assert(is_equal_approx(absf(Office.DOOR_OPEN_Y - Office.DOOR_CLOSED_Y) / Office.DOOR_SPEED, 0.375))
	assert(is_equal_approx(absf(Office.VENT_OPEN_Y - Office.VENT_CLOSED_Y) / Office.VENT_SPEED, 0.38))

func test_both_endpoints_unlock_only_at_the_current_target() -> void:
	var mechanism: Node3D = Node3D.new()
	for target: float in [Office.DOOR_OPEN_Y, Office.DOOR_CLOSED_Y, Office.VENT_OPEN_Y, Office.VENT_CLOSED_Y]:
		mechanism.position.y = target
		assert(not Office._mechanism_is_moving(mechanism, target))
		mechanism.position.y = target + 0.0001
		assert(Office._mechanism_is_moving(mechanism, target))
		mechanism.position.y = target - 0.0001
		assert(Office._mechanism_is_moving(mechanism, target))
	mechanism.free()

func test_each_mechanism_has_an_independent_lock() -> void:
	var office: Office = _make_guard_only_office()
	office.left_door.position.y = (Office.DOOR_OPEN_Y + Office.DOOR_CLOSED_Y) * 0.5
	office.right_door.position.y = Office.DOOR_OPEN_Y
	office.vent_cover.position.y = Office.VENT_OPEN_Y
	assert(Office._mechanism_is_moving(office.left_door, Office.DOOR_OPEN_Y))
	assert(not Office._mechanism_is_moving(office.right_door, Office.DOOR_OPEN_Y))
	assert(not Office._mechanism_is_moving(office.vent_cover, Office.VENT_OPEN_Y))
	office.free()

func test_in_transit_spam_never_flips_flags_or_reaches_sound_side_effects() -> void:
	var office: Office = _make_guard_only_office()
	for closed: bool in [false, true]:
		_set_closed_flags(office, closed)
		office.left_door.position.y = (Office.DOOR_OPEN_Y + Office.DOOR_CLOSED_Y) * 0.5
		office.right_door.position.y = office.left_door.position.y
		office.vent_cover.position.y = (Office.VENT_OPEN_Y + Office.VENT_CLOSED_Y) * 0.5
		for request: int in range(50):
			_request_all_toggles(office)
			assert(office.left_closed == closed and office.right_closed == closed and office.vent_closed == closed)
	assert(office.get_child_count() == 3, "No timers, queued commands or additional controllers")
	office.free()

func test_just_changed_target_is_busy_even_before_the_first_movement_frame() -> void:
	var office: Office = _make_guard_only_office()
	for closed: bool in [false, true]:
		_set_closed_flags(office, closed)
		office.left_door.position.y = Office.DOOR_OPEN_Y if closed else Office.DOOR_CLOSED_Y
		office.right_door.position.y = office.left_door.position.y
		office.vent_cover.position.y = Office.VENT_OPEN_Y if closed else Office.VENT_CLOSED_Y
		_request_all_toggles(office)
		assert(office.left_closed == closed and office.right_closed == closed and office.vent_closed == closed)
	office.free()

func test_power_lock_still_blocks_settled_mechanisms() -> void:
	var office: Office = _make_guard_only_office()
	office._has_power = false
	_set_closed_flags(office, false)
	office.left_door.position.y = Office.DOOR_OPEN_Y
	office.right_door.position.y = Office.DOOR_OPEN_Y
	office.vent_cover.position.y = Office.VENT_OPEN_Y
	_request_all_toggles(office)
	assert(not office.left_closed and not office.right_closed and not office.vent_closed)
	office.free()
