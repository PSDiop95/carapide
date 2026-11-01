class_name StationPanel
extends ColorRect
## Écran de la Station : les paliers, le prochain à ramasser, le temps de recharge.

signal claim_pressed

const SHADE: Color = Color(0.0, 0.0, 0.0, 0.8)
const FONT_SIZE: int = 36
const TITLE_FONT_SIZE: int = 48
const SEPARATION: int = 24
const BUTTON_SIZE: Vector2 = Vector2(480.0, 100.0)
const TAKEN_COLOR: Color = Color(1.0, 1.0, 1.0, 0.4)
const WAITING_COLOR: Color = Color(1.0, 1.0, 1.0, 0.7)
const SECONDS_PER_HOUR: int = 3600
const SECONDS_PER_MINUTE: int = 60

var claim_button: Button = Button.new()
var close_button: Button = Button.new()
var recharge_label: Label = Label.new()
var tier_labels: Array[Label] = []

var _column: VBoxContainer = VBoxContainer.new()


func _ready() -> void:
	color = SHADE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_column.alignment = BoxContainer.ALIGNMENT_CENTER
	_column.add_theme_constant_override("separation", SEPARATION)
	_column.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_column)
	var title: Label = Label.new()
	title.text = tr("STATION_TITLE")
	title.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_column.add_child(title)
	recharge_label.add_theme_font_size_override("font_size", FONT_SIZE)
	recharge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_column.add_child(recharge_label)
	_add_button(claim_button, "")
	_add_button(close_button, tr("PANEL_CLOSE"))
	claim_button.pressed.connect(claim_pressed.emit)
	close_button.pressed.connect(hide)


## À appeler une fois avant la première ouverture : une ligne par palier.
func build_tiers(tier_coins: PackedInt32Array) -> void:
	for index: int in tier_coins.size():
		var label: Label = Label.new()
		label.text = tr("STATION_TIER") % [index + 1, tier_coins[index]]
		label.add_theme_font_size_override("font_size", FONT_SIZE)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_column.add_child(label)
		_column.move_child(label, index + 2)
		tier_labels.append(label)


## Paliers pris estompés, palier courant en clair.
func show_state(next_tier: int, action_text: String, enabled: bool, seconds_left: int) -> void:
	for index: int in tier_labels.size():
		var shade: Color = Color.WHITE if index == next_tier else (TAKEN_COLOR if index < next_tier else WAITING_COLOR)
		tier_labels[index].add_theme_color_override("font_color", shade)
	claim_button.text = action_text
	claim_button.disabled = not enabled
	recharge_label.text = _recharge_text(seconds_left)


func set_waiting(waiting: bool) -> void:
	claim_button.disabled = waiting
	close_button.disabled = waiting


func _recharge_text(seconds_left: int) -> String:
	if seconds_left <= 0:
		return ""
	var hours: int = int(float(seconds_left) / float(SECONDS_PER_HOUR))
	var minutes: int = int(float(seconds_left % SECONDS_PER_HOUR) / float(SECONDS_PER_MINUTE))
	return tr("STATION_RECHARGE") % [hours, minutes]


func _add_button(button: Button, text: String) -> void:
	button.text = text
	button.custom_minimum_size = BUTTON_SIZE
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", FONT_SIZE)
	_column.add_child(button)
