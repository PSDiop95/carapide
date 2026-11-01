class_name WheelPanel
extends ColorRect
## Écran de la Roue : disque, barre x/10, bouton de tour. Rejoue un tirage déjà fait.

signal spin_pressed
signal spin_finished

const SHADE: Color = Color(0.0, 0.0, 0.0, 0.8)
const FONT_SIZE: int = 36
const TITLE_FONT_SIZE: int = 48
const SEPARATION: int = 24
const BUTTON_SIZE: Vector2 = Vector2(480.0, 90.0)
const BAR_SIZE: Vector2 = Vector2(480.0, 28.0)
const POINTER_SIZE: Vector2 = Vector2(16.0, 44.0)

var dial: WheelDial = WheelDial.new()
var spin_button: Button = Button.new()
var close_button: Button = Button.new()
var progress_label: Label = Label.new()
var progress_bar: ProgressBar = ProgressBar.new()
var result_label: Label = Label.new()

var _config: PresentationConfig
var _spinning: bool = false


func setup(config: PresentationConfig, cell_texts: PackedStringArray) -> void:
	_config = config
	dial.setup(cell_texts)


func _ready() -> void:
	color = SHADE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var column: VBoxContainer = VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", SEPARATION)
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(column)
	column.add_child(_label(Label.new(), tr("WHEEL_TITLE"), TITLE_FONT_SIZE))
	column.add_child(_build_dial())
	column.add_child(_label(result_label, "", FONT_SIZE))
	column.add_child(_label(progress_label, "", FONT_SIZE))
	progress_bar.custom_minimum_size = BAR_SIZE
	progress_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	progress_bar.show_percentage = false
	column.add_child(progress_bar)
	column.add_child(_button(spin_button, ""))
	column.add_child(_button(close_button, tr("PANEL_CLOSE")))
	spin_button.pressed.connect(spin_pressed.emit)
	close_button.pressed.connect(hide)


func show_progress(count: int, goal: int) -> void:
	progress_label.text = tr("WHEEL_PROGRESS") % [count, goal]
	progress_bar.max_value = goal
	progress_bar.value = count


## Texte vide : aucun tour disponible. Le bouton reste affiché, grisé.
func show_spin_action(text: String, enabled: bool) -> void:
	spin_button.text = text
	spin_button.disabled = not enabled or _spinning


func set_waiting(waiting: bool) -> void:
	spin_button.disabled = waiting
	close_button.disabled = waiting


func is_spinning() -> bool:
	return _spinning


## Le résultat est déjà décidé et crédité : le disque ne fait que le montrer.
func play_spin(index: int, result_text: String) -> void:
	_spinning = true
	set_waiting(true)
	result_label.text = ""
	var target: float = dial.target_rotation(index, dial.rotation, _config.wheel_spin_turns)
	var tween: Tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(dial, "rotation", target, _config.wheel_spin_seconds)
	await tween.finished
	_spinning = false
	set_waiting(false)
	result_label.text = result_text
	spin_finished.emit()


func _build_dial() -> Control:
	var holder: Control = Control.new()
	holder.custom_minimum_size = Vector2(WheelDial.RADIUS, WheelDial.RADIUS) * 2.0
	holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(dial)
	var pointer: ColorRect = ColorRect.new()
	pointer.color = Color.BLACK
	pointer.size = POINTER_SIZE
	pointer.position = Vector2(WheelDial.RADIUS - POINTER_SIZE.x * 0.5, -POINTER_SIZE.y * 0.5)
	pointer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(pointer)
	return holder


func _label(label: Label, text: String, font_size: int) -> Label:
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _button(button: Button, text: String) -> Button:
	button.text = text
	button.custom_minimum_size = BUTTON_SIZE
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", FONT_SIZE)
	return button
