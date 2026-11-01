class_name BlockedPopup
extends ColorRect
## Pop-up de la gare bloquée : booster conseillé par le solveur, puis Garage, puis Recommencer.
## Maintenir hors des boutons efface la pop-up, le temps de regarder la carte.

signal advice_pressed
signal garage_pressed
signal restart_pressed

const SHADE: Color = Color(0.0, 0.0, 0.0, 0.6)
const TITLE_FONT_SIZE: int = 48
const FONT_SIZE: int = 32
const BUTTON_SIZE: Vector2 = Vector2(460.0, 110.0)
const SEPARATION: int = 28
const HINT_FONT_SIZE: int = 26

var advice_button: Button = Button.new()
var garage_button: Button = Button.new()
var restart_button: Button = Button.new()


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
	_prepare(garage_button, column)
	garage_button.pressed.connect(garage_pressed.emit)
	_prepare(restart_button, column)
	restart_button.text = tr("BLOCKED_RESTART")
	restart_button.pressed.connect(restart_pressed.emit)
	var hint: Label = Label.new()
	hint.text = tr("BLOCKED_HOLD_HINT")
	hint.add_theme_font_size_override("font_size", HINT_FONT_SIZE)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(hint)
	hide()


## Texte vide : ce choix n'est pas proposé.
func open(advice_text: String, garage_text: String) -> void:
	advice_button.text = advice_text
	advice_button.visible = not advice_text.is_empty()
	garage_button.text = garage_text
	garage_button.visible = not garage_text.is_empty()
	modulate.a = 1.0
	show()


func _gui_input(event: InputEvent) -> void:
	var press: InputEventMouseButton = event as InputEventMouseButton
	if press != null and press.button_index == MOUSE_BUTTON_LEFT:
		modulate.a = 0.0 if press.pressed else 1.0


func _prepare(button: Button, column: VBoxContainer) -> void:
	button.custom_minimum_size = BUTTON_SIZE
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", FONT_SIZE)
	column.add_child(button)
