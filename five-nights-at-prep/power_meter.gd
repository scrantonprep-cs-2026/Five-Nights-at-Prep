class_name PowerMeter
extends CanvasLayer

## FNAF-1-style power HUD. Bottom-left panel: battery percentage and the usage
## bars (one bar always lit; each active device adds one, capped at five).
## Top-left corner of the viewport: the in-game clock (12-6 AM). Both read from
## the FNAP_Beta_Code script.

const MARGIN := 18.0
const BAR_W := 14.0
const BAR_H := 34.0
const BAR_GAP := 6.0
const PAD := 12.0
const LABEL_H := 16.0
const MAX_BARS := 5
const CLOCK_MARGIN := 24.0
const CLOCK_H := 20.0

## Per-bar colour, cool (low usage) to hot (high usage).
const BAR_COLORS := [
	Color(0.36, 0.85, 0.35),
	Color(0.62, 0.86, 0.28),
	Color(0.93, 0.85, 0.22),
	Color(0.96, 0.55, 0.18),
	Color(0.96, 0.22, 0.16),
]
const BAR_OFF := Color(0.15, 0.15, 0.17)

var _office: Office
var _cameras: CameraSystem

# Reference to the FNAP script (at /Office/AIandSystems).
var _fnap

# Power percentage display (top-left).
var _power_label: Label

# In-game clock display (top-left, 12-6 AM format).
var _clock_label: Label

var _root: Control
var _bg: Panel
var _label: Label
var _bars: Array[Panel] = []
var _level := 0
## Last whole percent shown on the battery label (display only).
var _last_shown_percent: int = -1


func _ready() -> void:
	layer = 20
	_office = get_parent() as Office
	if _office != null:
		_cameras = _office.get_node_or_null("CameraSystem") as CameraSystem
		_fnap = _office.get_node("AIandSystems")
	_build()
	_layout()
	get_viewport().size_changed.connect(_layout)
	_level = -1
	_update()


func _process(_delta: float) -> void:
	_update()


func _build() -> void:
	_root = Control.new()
	_root.name = "PowerUsage"
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_bg = Panel.new()
	_bg.name = "Background"
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg.add_theme_stylebox_override("panel", _box(Color(0.06, 0.06, 0.08, 0.72), Color(0.34, 0.35, 0.4), 2, 8))
	_root.add_child(_bg)

	_label = Label.new()
	_label.name = "Label"
	_label.text = "USAGE"
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_size_override("font_size", 13)
	_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.92))
	_root.add_child(_label)

	# Power percentage label, living in the bottom-left power/usage HUD panel.
	_power_label = Label.new()
	_power_label.name = "PowerLabel"
	_power_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_power_label.add_theme_font_size_override("font_size", 14)
	_power_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.8))
	_root.add_child(_power_label)

	# Clock label: added straight to the CanvasLayer so it sits in the
	# top-left corner of the viewport, separate from the power/usage HUD.
	_clock_label = Label.new()
	_clock_label.name = "ClockLabel"
	_clock_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clock_label.add_theme_font_size_override("font_size", 14)
	_clock_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.8))
	add_child(_clock_label)

	for i in range(MAX_BARS):
		var bar := Panel.new()
		bar.name = "Bar%d" % (i + 1)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.add_theme_stylebox_override("panel", _box(BAR_OFF, Color(0, 0, 0, 0), 0, 3))
		_root.add_child(bar)
		_bars.append(bar)


func _layout() -> void:
	if _root == null:
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var content_w: float = MAX_BARS * BAR_W + (MAX_BARS - 1) * BAR_GAP
	var width: float = content_w + PAD * 2.0
	var height: float = PAD + LABEL_H + 2.0 + LABEL_H + 6.0 + BAR_H + PAD

	# Bottom-left power/usage HUD panel.
	_root.position = Vector2(MARGIN, vp.y - MARGIN - height)
	_bg.position = Vector2.ZERO
	_bg.size = Vector2(width, height)

	# Battery percent sits at the top of the panel, above the usage bars.
	_power_label.position = Vector2(PAD, PAD - 2.0)
	_power_label.size = Vector2(width - PAD * 2.0, LABEL_H)

	_label.position = Vector2(PAD, PAD + LABEL_H + 2.0)
	_label.size = Vector2(width - PAD * 2.0, LABEL_H)

	# Bar row Y position.
	var bar_y: float = PAD + LABEL_H + 2.0 + LABEL_H + 6.0
	for i in range(MAX_BARS):
		var bar: Panel = _bars[i]
		bar.position = Vector2(PAD + i * (BAR_W + BAR_GAP), bar_y)
		bar.size = Vector2(BAR_W, BAR_H)

	# Clock in the top-left corner of the viewport, clearly separate from the HUD.
	_clock_label.position = Vector2(CLOCK_MARGIN, CLOCK_MARGIN)
	_clock_label.size = Vector2(vp.x - CLOCK_MARGIN * 2.0, CLOCK_H)


func _update() -> void:
	var count := 1
	if _office != null:
		if _office.left_closed:
			count += 1
		if _office.right_closed:
			count += 1
		if _office.left_light_on:
			count += 1
		if _office.right_light_on:
			count += 1
		if _office.vent_closed:
			count += 1
	if _cameras != null and _cameras.is_monitor_up():
		count += 1

	var level: int = clampi(count, 1, MAX_BARS)
	if level != _level:
		_level = level
		for i in range(MAX_BARS):
			var box: StyleBoxFlat = _bars[i].get_theme_stylebox("panel")
			box.bg_color = BAR_COLORS[i] if i < level else BAR_OFF

	if _fnap == null:
		return

	# Battery: display-only whole percent. The stored power stays a float; the
	# label only rewrites when the next integer is reached, so it steps cleanly
	# 100 -> 99 -> 98 with no jitter, animation, or decimals.
	var shown: int = clampi(ceili(_fnap.office_power), 0, 100)
	if shown != _last_shown_percent:
		_last_shown_percent = shown
		_power_label.text = "Power: %d%%" % shown

	# In-game clock: convert elapsed time since night start to 12-6 AM format.
	var elapsed: float = _fnap.get_night_elapsed()
	var hours: int = int(elapsed / 60.0)
	if hours == 0:
		hours = 12
	_clock_label.text = "%d AM" % hours


func _box(fill: Color, border: Color, border_w: int, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(border_w)
	box.set_corner_radius_all(radius)
	return box
