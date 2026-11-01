class_name Hud
extends CanvasLayer
## Interface : niveau en cours, passagers restants, écrans de fin.

signal primary_pressed

const FONT_SIZE: int = 36
const TITLE_FONT_SIZE: int = 56
const STATS_FONT_SIZE: int = 20
const MARGIN: float = 24.0
const PANEL_SEPARATION: int = 32
const BUTTON_MIN_SIZE: Vector2 = Vector2(360.0, 110.0)
const SHADE_COLOR: Color = Color(0.0, 0.0, 0.0, 0.55)
const STATS_REFRESH_SECONDS: float = 0.5

var primary_button: Button = Button.new()
var result_title: Label = Label.new()

var _level_label: Label = Label.new()
var _passengers_label: Label = Label.new()
var _stats_label: Label = Label.new()
var _end_screen: ColorRect = ColorRect.new()


func _ready() -> void:
	_add_top_label(_level_label, Control.PRESET_TOP_LEFT, HORIZONTAL_ALIGNMENT_LEFT)
	_add_top_label(_passengers_label, Control.PRESET_TOP_RIGHT, HORIZONTAL_ALIGNMENT_RIGHT)
	_build_end_screen()
	if OS.is_debug_build():
		_build_stats()
	hide_result()


func set_level(level_number: int) -> void:
	_level_label.text = tr("LEVEL_LABEL") % level_number


func set_passengers(remaining: int) -> void:
	_passengers_label.text = tr("PASSENGERS_LABEL") % remaining


func show_result(title_key: String, button_key: String) -> void:
	result_title.text = tr(title_key)
	primary_button.text = tr(button_key)
	_end_screen.visible = true


func hide_result() -> void:
	_end_screen.visible = false


func is_result_visible() -> bool:
	return _end_screen.visible


func _add_top_label(label: Label, preset: Control.LayoutPreset, alignment: HorizontalAlignment) -> void:
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.add_theme_color_override("font_color", Color.BLACK)
	label.horizontal_alignment = alignment
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_MINSIZE, int(MARGIN))
	label.grow_horizontal = Control.GROW_DIRECTION_BEGIN if preset == Control.PRESET_TOP_RIGHT else Control.GROW_DIRECTION_END
	add_child(label)


func _build_end_screen() -> void:
	_end_screen.color = SHADE_COLOR
	_end_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_end_screen)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", PANEL_SEPARATION)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	_end_screen.add_child(column)
	result_title.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(result_title)
	primary_button.custom_minimum_size = BUTTON_MIN_SIZE
	primary_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	primary_button.add_theme_font_size_override("font_size", FONT_SIZE)
	primary_button.pressed.connect(primary_pressed.emit)
	column.add_child(primary_button)


func _build_stats() -> void:
	_stats_label.add_theme_font_size_override("font_size", STATS_FONT_SIZE)
	_stats_label.add_theme_color_override("font_color", Color.BLACK)
	_stats_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stats_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, int(MARGIN))
	_stats_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(_stats_label)
	var timer: Timer = Timer.new()
	timer.wait_time = STATS_REFRESH_SECONDS
	timer.autostart = true
	timer.timeout.connect(_refresh_stats)
	add_child(timer)


func _refresh_stats() -> void:
	var fps: float = Performance.get_monitor(Performance.TIME_FPS)
	var draw_calls: float = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	_stats_label.text = "%d fps, %d draw calls" % [int(fps), int(draw_calls)]
