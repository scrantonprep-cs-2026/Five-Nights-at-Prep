class_name CCTVFeedTests
extends Node

const EXPECTED_PHOTOS = {
	1: "res://CameraShots/Henfling-2.jpeg",
	2: "res://CameraShots/Bellermine-1.jpeg",
	3: "res://CameraShots/SpanishRoom.jpeg",
	4: "res://CameraShots/GillisRoom.jpeg",
	5: "res://CameraShots/AdminHall.jpeg",
	6: "res://CameraShots/LeftHall.jpeg",
	7: "res://CameraShots/RightHall.jpeg",
}
const EXPECTED_CROPS = {
	1: Vector2(0.5, 0.20),
	3: Vector2(0.5, 0.62),
	4: Vector2(0.5, 0.66),
	5: Vector2(0.5, 0.56),
	6: Vector2(0.5, 0.60),
	7: Vector2(0.5, 0.52),
}

func _make_monitor() -> CameraSystem:
	var monitor: CameraSystem = CameraSystem.new()
	monitor._load_feed_photos()
	monitor._build_ui()
	monitor._build_map()
	monitor._feed.size = Vector2(1152, 648)
	return monitor

func test_exact_resources_and_all_seven_photo_feeds() -> void:
	assert(CameraSystem.CAMERA_PHOTO_PATHS == EXPECTED_PHOTOS)
	assert(CameraSystem.PHOTO_CROP_POSITIONS == EXPECTED_CROPS)
	assert(CameraSystem.CAMERAS.size() == 7)
	assert(CameraSystem.CAMERAS[0]["name"] == "Yondr Room")
	assert(CameraSystem.CAMERAS[1]["name"] == "Bellarmine")
	for camera_id: int in EXPECTED_PHOTOS:
		var path: String = EXPECTED_PHOTOS[camera_id]
		assert(FileAccess.file_exists(path), "Exact source path must exist: " + path)
		assert(ResourceLoader.exists(path), "Photograph must be imported: " + path)
		var photo: Texture2D = load(path) as Texture2D
		assert(photo != null and photo.resource_path == path and photo.get_width() > 0 and photo.get_height() > 0)
	assert(CameraSystem.CAMERA_PHOTO_PATHS.has(1))
	assert(CameraSystem.CAMERA_PHOTO_PATHS.has(2))

func test_feed_refresh_maps_all_seven_and_clears_stale_photos() -> void:
	var monitor: CameraSystem = _make_monitor()
	assert(monitor._camera_buttons.size() == 7)
	# Exercise the new CAM2 photograph alongside every preserved feed.
	for camera_id: int in [1, 2, 1, 3, 1, 5, 1, 7, 1, 4, 6, 2, 1]:
		monitor.current_camera_id = camera_id
		monitor._refresh_feed()
		assert(monitor._room_label.text == CameraSystem.CAMERAS[camera_id - 1]["name"])
		assert(monitor._feed_label.text.begins_with("CAM %d  /  " % camera_id))
		if EXPECTED_PHOTOS.has(camera_id):
			assert(monitor._feed_photo.texture.resource_path == EXPECTED_PHOTOS[camera_id])
			assert(monitor._feed_photo.visible)
			assert(not monitor._feed_label.text.contains("TEMPORARY"))
		else:
			assert(monitor._feed_photo.texture == null)
			assert(not monitor._feed_photo.visible)
			assert(monitor._feed_label.text.contains("TEMPORARY CCTV FEED"))
		assert(monitor._static_overlay.visible and monitor._rec_indicator.visible)
	monitor.free()

func test_cover_is_uniform_gap_free_and_resolution_independent() -> void:
	var sizes: Array[Vector2] = [Vector2(1152, 648), Vector2(960, 540), Vector2(1280, 800), Vector2(900, 700)]
	for camera_id: int in EXPECTED_PHOTOS:
		var photo: Texture2D = load(EXPECTED_PHOTOS[camera_id]) as Texture2D
		var original_size: Vector2 = photo.get_size()
		var crop_position: Vector2 = CameraSystem.PHOTO_CROP_POSITIONS.get(camera_id, Vector2(0.5, 0.5))
		for feed_size: Vector2 in sizes:
			var rect: Rect2 = CameraSystem.get_photo_cover_rect(original_size, feed_size, crop_position)
			assert(is_equal_approx(rect.size.x / original_size.x, rect.size.y / original_size.y), "Cover must use one scale, never distort")
			assert(rect.position.x <= 0.001 and rect.position.y <= 0.001)
			assert(rect.end.x >= feed_size.x - 0.001 and rect.end.y >= feed_size.y - 0.001, "No letterbox gaps")
		var full: Rect2 = CameraSystem.get_photo_cover_rect(original_size, sizes[0], crop_position)
		var small: Rect2 = CameraSystem.get_photo_cover_rect(original_size, sizes[1], crop_position)
		assert(full.position.is_equal_approx(small.position * 1.2))
		assert(full.size.is_equal_approx(small.size * 1.2))

func test_single_transparent_static_is_below_ui_and_ignores_mouse() -> void:
	var monitor: CameraSystem = _make_monitor()
	assert(monitor._feed.clip_contents)
	assert(monitor._feed_photo.expand_mode == TextureRect.EXPAND_IGNORE_SIZE)
	assert(monitor._feed_photo.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_COVERED)
	assert(monitor._feed_photo.modulate == Color.WHITE)
	assert(monitor._feed_photo.self_modulate == Color.WHITE)
	assert(monitor._feed.get_child_count() == 2)
	assert(monitor._feed_photo.get_index() < monitor._static_overlay.get_index())
	for control: Control in [monitor._feed, monitor._feed_photo, monitor._static_overlay, monitor._rec_indicator]:
		assert(control.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	for control: Control in [monitor._map_area, monitor._feed_label, monitor._room_label, monitor._camera_tab, monitor._vent_tab, monitor._close_button, monitor._rec_indicator]:
		assert(monitor._feed.get_index() < control.get_index(), "Feed/effect stay below every UI sibling")
	var material_id: int = monitor._static_material.get_instance_id()
	for camera_id: int in range(1, 8):
		monitor.current_camera_id = camera_id
		monitor._refresh_feed()
		assert(monitor._static_material.get_instance_id() == material_id, "One reusable material, not per-camera effects")
	assert(is_equal_approx(monitor.static_intensity, 0.10))
	assert(is_equal_approx(monitor.static_grain_size, 1.25))
	assert(is_equal_approx(monitor.static_updates_per_second, 30.0))
	assert(is_equal_approx(monitor.static_band_strength, 0.016))
	monitor.static_intensity = 0.045
	monitor.static_grain_size = 1.25
	monitor.static_updates_per_second = 30.0
	assert(is_equal_approx(float(monitor._static_material.get_shader_parameter("intensity")), 0.045))
	assert(is_equal_approx(float(monitor._static_material.get_shader_parameter("grain_size")), 1.25))
	assert(is_equal_approx(float(monitor._static_material.get_shader_parameter("updates_per_second")), 30.0))
	monitor.free()

func test_vent_tracker_hides_photo_static_and_rec_without_changing_selection() -> void:
	var monitor: CameraSystem = _make_monitor()
	monitor.current_camera_id = 6
	monitor._refresh_feed()
	monitor._vent_selected = true
	monitor._refresh_feed()
	assert(not monitor._feed_photo.visible)
	assert(not monitor._static_overlay.visible)
	assert(not monitor._rec_indicator.visible)
	assert(not monitor._map_area.visible and not monitor._room_label.visible)
	assert(monitor._vent_tracker.visible)
	monitor._vent_selected = false
	monitor._refresh_feed()
	assert(monitor.current_camera_id == 6)
	assert(monitor._feed_photo.texture.resource_path == EXPECTED_PHOTOS[6])
	assert(monitor._feed_photo.visible and monitor._static_overlay.visible and monitor._rec_indicator.visible)
	monitor.free()

func test_unavailable_assigned_photo_falls_back_instead_of_retaining_prior_camera() -> void:
	var monitor: CameraSystem = _make_monitor()
	for camera_id: int in [1, 3]:
		monitor.current_camera_id = 7
		monitor._refresh_feed()
		assert(monitor._feed_photo.texture != null)
		# Simulate an unavailable cache without moving/editing any JPEG.
		monitor._photo_textures.erase(camera_id)
		monitor.current_camera_id = camera_id
		monitor._refresh_feed()
		assert(monitor._feed_photo.texture == null and not monitor._feed_photo.visible)
		assert(monitor._feed_label.text.contains("PHOTO UNAVAILABLE"))
		assert(monitor._room_label.text == CameraSystem.CAMERAS[camera_id - 1]["name"])
		assert(monitor._static_overlay.visible and monitor._camera_buttons.size() == 7)
	monitor.free()

func test_cam_one_uses_the_shared_cover_layout_at_both_target_sizes() -> void:
	var monitor: CameraSystem = _make_monitor()
	assert(monitor.current_camera_id == 1, "Initial monitor feed must now be the Yondr photograph")
	for feed_size: Vector2 in [Vector2(1152, 648), Vector2(960, 540)]:
		monitor._feed.size = feed_size
		monitor._refresh_feed()
		var native_size: Vector2 = monitor._feed_photo.texture.get_size()
		var expected: Rect2 = CameraSystem.get_photo_cover_rect(native_size, feed_size, EXPECTED_CROPS[1])
		assert(monitor._feed_photo.texture.resource_path == EXPECTED_PHOTOS[1])
		assert(monitor._feed_photo.visible and monitor._feed.clip_contents)
		assert(monitor._feed_photo.position.is_equal_approx(expected.position))
		assert(monitor._feed_photo.size.is_equal_approx(expected.size))
		assert(monitor._feed_photo.modulate == Color.WHITE and monitor._feed_photo.self_modulate == Color.WHITE)
		assert(monitor._feed_label.text == "CAM 1  /  Yondr Room")
		assert(monitor._static_overlay.visible and monitor._rec_indicator.visible)
	monitor.free()
