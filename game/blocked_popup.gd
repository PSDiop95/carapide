class_name BlockedPopup
extends ColorRect
## Pop-up de la gare bloquée : le booster conseillé par le solveur, ou abandonner.

signal advice_pressed
signal abandon_pressed

const SHADE: Color = Color(0.0, 0.0, 0.0, 0.6)
const TITLE_FONT_SIZE: int = 48
const FONT_SIZE: int = 32
const BUTTON_SIZE: Vector2 = Vector2(460.0, 110.0)
const SEPARATION: int = 28

var advice_button: Button = Button.new()
var abandon_button: Button = Button.new()


func _ready() -> void:
	color = SHADE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column: VBoxContainer = VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", SEPARATION)
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(column)
	var title: Label = Label.new()
	title.text = tr("BLOCKED_TITLE")
	title.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	_prepare(advice_button, column)
	advice_button.pressed.connect(advice_pressed.emit)
	_prepare(abandon_button, column)
	abandon_button.text = tr("BLOCKED_ABANDON")
	abandon_button.pressed.connect(abandon_pressed.emit)
	hide()


## `advice_text` vide : aucun booster à proposer, seul l'abandon reste.
func open(advice_text: String) -> void:
	advice_button.text = advice_text
	advice_button.visible = not advice_text.is_empty()
	show()


func _prepare(button: Button, column: VBoxContainer) -> void:
	button.custom_minimum_size = BUTTON_SIZE
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", FONT_SIZE)
	column.add_child(button)
