class_name Hud
extends CanvasLayer
## Interface : niveau en cours, passagers restants, pancartes de file, écrans de fin.

signal primary_pressed
signal new_tester_requested
signal boosters_toggled
signal bonus_pressed

const FONT_SIZE: int = 36
const TITLE_FONT_SIZE: int = 56
const STATS_FONT_SIZE: int = 20
const MARGIN: float = 24.0
const PANEL_SEPARATION: int = 32
const BUTTON_MIN_SIZE: Vector2 = Vector2(360.0, 110.0)
const SHADE_COLOR: Color = Color(0.0, 0.0, 0.0, 0.55)
const STATS_REFRESH_SECONDS: float = 0.5
const CHIPS_TOP: float = 84.0
const CHIPS_SEPARATION: int = 8
const MORE_FONT_SIZE: int = 26
## Écran de partage du CSV : 5 taps sur le titre (Prompt 02 A6).
const HIDDEN_TAPS: int = 5
const HIDDEN_WINDOW_MS: int = 3000
const STATS_TOP: float = 150.0

var primary_button: Button = Button.new()
var level_button: Button = Button.new()
var playtest_panel: PlaytestPanel = PlaytestPanel.new()
var result_title: Label = Label.new()
var result_detail: Label = Label.new()
var bonus_button: Button = Button.new()
var apprentice: ApprenticeCheer = ApprenticeCheer.new()
## Sous l'écran de fin : barre, pop-up et tutoriel des boosters.
var booster_layer: Control = Control.new()

var _chips_row: HBoxContainer = HBoxContainer.new()
var _chips: Array[QueueChip] = []
var _more_label: Label = Label.new()
var _config: PresentationConfig
var _hidden_taps: HiddenTapDetector = HiddenTapDetector.new(HIDDEN_TAPS, HIDDEN_WINDOW_MS)
var _passengers_label: Label = Label.new()
var _stats_label: Label = Label.new()
var _end_screen: ColorRect = ColorRect.new()
var _coins_label: Label = Label.new()
var _ad_curtain: ColorRect = ColorRect.new()


## À appeler avant d'entrer dans l'arbre.
func configure(config: PresentationConfig) -> void:
	_config = config


func _ready() -> void:
	booster_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	booster_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(booster_layer)
	_build_chips()
	_add_top_label(_passengers_label, Control.PRESET_TOP_RIGHT, HORIZONTAL_ALIGNMENT_RIGHT)
	_build_end_screen()
	_build_level_button()
	add_child(playtest_panel)
	playtest_panel.new_tester_requested.connect(new_tester_requested.emit)
	playtest_panel.boosters_toggled.connect(boosters_toggled.emit)
	if OS.is_debug_build():
		_build_stats()
	_build_coins()
	_build_ad_curtain()
	hide_result()


func set_level(level_number: int) -> void:
	level_button.text = tr("LEVEL_LABEL") % level_number


func set_passengers(remaining: int) -> void:
	_passengers_label.text = tr("PASSENGERS_LABEL") % remaining


## Pancartes des prochains blocs, la tête à gauche ; le reste est résumé en « +N ».
func set_queue_blocks(blocks: Array[QueueBlock]) -> void:
	for index: int in _chips.size():
		var chip: QueueChip = _chips[index]
		chip.visible = index < blocks.size()
		if chip.visible:
			var block: QueueBlock = blocks[index]
			var text: String = "%s %d" % [tr(_config.name_key_of(block.dest)), block.count]
			chip.show_block(_config.color_of(block.dest), _config.picto_of(block.dest), text, index == 0)
	var hidden: int = blocks.size() - _chips.size()
	_more_label.visible = hidden > 0
	_more_label.text = tr("QUEUE_MORE") % hidden


## Textes affichés sur les pancartes, pour la vérification de bout en bout.
func chip_texts() -> PackedStringArray:
	var texts: PackedStringArray = PackedStringArray()
	for chip: QueueChip in _chips:
		if chip.visible:
			texts.append(chip.label_text())
	return texts


func show_result(title_key: String, button_key: String) -> void:
	result_title.text = tr(title_key)
	primary_button.text = tr(button_key)
	_end_screen.visible = true
	_set_play_interface_visible(false)


## Écran de victoire : l'apprenti célèbre au-dessus du titre.
func show_victory(title_key: String, button_key: String) -> void:
	show_result(title_key, button_key)
	apprentice.visible = true


func hide_result() -> void:
	_end_screen.visible = false
	apprentice.visible = false
	_set_play_interface_visible(true)
	result_detail.visible = false
	bonus_button.visible = false


func show_coins_earned(detail: String) -> void:
	result_detail.text = detail
	result_detail.visible = true


func show_bonus(text: String) -> void:
	bonus_button.text = text
	bonus_button.visible = true


func hide_bonus() -> void:
	bonus_button.visible = false


## Négatif : solde masqué (boosters désactivés).
func set_coins(balance: int) -> void:
	_coins_label.visible = balance >= 0
	_coins_label.text = tr("COINS_LABEL") % balance


func show_ad_curtain() -> void:
	_ad_curtain.visible = true


func hide_ad_curtain() -> void:
	_ad_curtain.visible = false


func is_ad_curtain_visible() -> bool:
	return _ad_curtain.visible


## Vrai si ce point d'écran tombe sur un contrôle affiché par-dessus le plateau.
func covers_point(at: Vector2) -> bool:
	if _ad_curtain.visible or _end_screen.visible or playtest_panel.visible:
		return true
	if level_button.get_global_rect().has_point(at):
		return true
	for child: Node in booster_layer.get_children():
		var control: Control = child as Control
		if control != null and control.visible and control.get_global_rect().has_point(at):
			return true
	return false


func is_result_visible() -> bool:
	return _end_screen.visible


## Sous l'écran de fin, ces contrôles ne servent plus et coûtent des draw calls.
func _set_play_interface_visible(shown: bool) -> void:
	booster_layer.visible = shown
	_chips_row.visible = shown
	_passengers_label.visible = shown


func _build_level_button() -> void:
	level_button.flat = true
	level_button.add_theme_font_size_override("font_size", FONT_SIZE)
	level_button.add_theme_color_override("font_color", Color.BLACK)
	level_button.add_theme_color_override("font_hover_color", Color.BLACK)
	level_button.add_theme_color_override("font_pressed_color", Color.BLACK)
	level_button.focus_mode = Control.FOCUS_NONE
	level_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE, int(MARGIN))
	level_button.pressed.connect(_on_level_button_pressed)
	add_child(level_button)


func _on_level_button_pressed() -> void:
	if _hidden_taps.register(Time.get_ticks_msec()):
		playtest_panel.open()


func _build_chips() -> void:
	_chips_row.add_theme_constant_override("separation", CHIPS_SEPARATION)
	_chips_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chips_row.position = Vector2(float(CHIPS_SEPARATION), CHIPS_TOP)
	add_child(_chips_row)
	for _index: int in _config.queue_chip_count:
		var chip: QueueChip = QueueChip.new()
		_chips.append(chip)
		_chips_row.add_child(chip)
	_more_label.add_theme_font_size_override("font_size", MORE_FONT_SIZE)
	_more_label.add_theme_color_override("font_color", Color.BLACK)
	_more_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chips_row.add_child(_more_label)


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
	apprentice.configure(_config)
	apprentice.visible = false
	column.add_child(apprentice)
	result_title.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(result_title)
	result_detail.add_theme_font_size_override("font_size", FONT_SIZE)
	result_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(result_detail)
	primary_button.custom_minimum_size = BUTTON_MIN_SIZE
	primary_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	primary_button.add_theme_font_size_override("font_size", FONT_SIZE)
	primary_button.pressed.connect(primary_pressed.emit)
	column.add_child(primary_button)
	bonus_button.custom_minimum_size = BUTTON_MIN_SIZE
	bonus_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bonus_button.add_theme_font_size_override("font_size", FONT_SIZE)
	bonus_button.pressed.connect(bonus_pressed.emit)
	column.add_child(bonus_button)


func _build_coins() -> void:
	_add_top_label(_coins_label, Control.PRESET_CENTER_TOP, HORIZONTAL_ALIGNMENT_CENTER)
	_coins_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_coins_label.visible = false


func _build_ad_curtain() -> void:
	_ad_curtain.color = SHADE_COLOR
	_ad_curtain.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ad_curtain.visible = false
	add_child(_ad_curtain)
	var label: Label = Label.new()
	label.text = tr("AD_PLAYING")
	label.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ad_curtain.add_child(label)


func _build_stats() -> void:
	_stats_label.add_theme_font_size_override("font_size", STATS_FONT_SIZE)
	_stats_label.add_theme_color_override("font_color", Color.BLACK)
	_stats_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stats_label.position = Vector2(MARGIN, STATS_TOP)
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
