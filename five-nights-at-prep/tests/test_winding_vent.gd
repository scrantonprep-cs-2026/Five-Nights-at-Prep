class_name WindingVentContractTests
extends Node

func test_windup_configuration_leaves_winding_balance_unchanged() -> void:
	var box: MusicBox = MusicBox.new()
	assert(MusicBox.WINDUP_SOUND_PATH == "res://windup2.wav")
	assert(MusicBox.WINDUP_INTERVAL_MSEC == 400)
	assert(is_equal_approx(box.windup_volume_db, -12.0))
	assert(is_equal_approx(box.wind_rate, 4.0))
	assert(box.night_durations == PackedFloat32Array([60, 50, 40, 30, 20]))
	assert(is_equal_approx(box.failure_delay, 15.0))
	assert(box._next_windup_at_msec == 0 and not box.is_winding())
	box.free()

func test_vent_page_uses_full_contained_map_and_passive_controls() -> void:
	var tracker: VentTracker = VentTracker.new()
	tracker.size = Vector2(1104, 494)
	tracker._layout()
	assert(tracker._map_image.texture.resource_path == "res://assets/maps/Retro Ventilation Network Map.png")
	assert(tracker._map_image.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
	assert(tracker._map_image.expand_mode == TextureRect.EXPAND_IGNORE_SIZE)
	var native_size: Vector2 = tracker._map_image.texture.get_size()
	var image_rect: Rect2 = tracker.get_map_display_rect()
	assert(is_equal_approx(image_rect.size.x / native_size.x, image_rect.size.y / native_size.y))
	assert(image_rect.position.x >= tracker._map_image.position.x - 0.001)
	assert(image_rect.position.y >= tracker._map_image.position.y - 0.001)
	assert(image_rect.end.x <= tracker._map_image.position.x + tracker._map_image.size.x + 0.001)
	assert(image_rect.end.y <= tracker._map_image.position.y + tracker._map_image.size.y + 0.001)
	for control: Control in [tracker, tracker._map_image, tracker._background, tracker._markers_layer, tracker._heading, tracker._gate_status, tracker._contact_status]:
		assert(control.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	tracker.refresh_gate_status()
	assert(tracker._gate_status.text == "STATUS UNAVAILABLE", "Do not invent a gate state without the office")
	tracker.free()

func test_contact_hook_is_empty_until_called_and_supports_update_remove_clear() -> void:
	var tracker: VentTracker = VentTracker.new()
	tracker.size = Vector2(1104, 494)
	tracker._layout()
	assert(tracker.get_contact_count() == 0 and tracker._markers_layer.get_child_count() == 0)
	assert(tracker._contact_status.text == "TRACKER STANDBY\nNO CONTACT DATA")
	assert(not tracker.update_contact(&"", Vector2(0.5, 0.5)))
	assert(not tracker.update_contact(&"invalid", Vector2(2.0, 0.5)))
	assert(not tracker.update_contact(&"invalid", Vector2(NAN, 0.5)))
	assert(tracker.update_contact(&"unit_contact", Vector2(0.25, 0.75)))
	assert(tracker.update_contact(&"unit_contact", Vector2(0.6, 0.4)))
	assert(tracker.get_contact_count() == 1 and tracker._markers_layer.get_child_count() == 1)
	var marker: Label = tracker._markers[&"unit_contact"] as Label
	var rect: Rect2 = tracker.get_map_display_rect()
	var center: Vector2 = tracker._markers_layer.position + marker.position + marker.size * 0.5
	assert(center.is_equal_approx(rect.position + rect.size * Vector2(0.6, 0.4)))
	tracker.remove_contact(&"unit_contact")
	assert(tracker.get_contact_count() == 0 and tracker._markers_layer.get_child_count() == 0)
	assert(tracker.update_contact(&"unit_contact", Vector2(0, 1)))
	tracker.clear_contacts()
	assert(tracker.get_contact_count() == 0 and tracker._markers_layer.get_child_count() == 0)
	assert(tracker._contact_status.text.contains("NO CONTACT DATA"))
	tracker.free()
