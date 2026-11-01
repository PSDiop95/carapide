class_name SettingsPanel
extends ColorRect
## Réglages : musique, effets, vibrations, langue. Le français est la seule langue active.

const SHADE: Color = Color(0.0, 0.0, 0.0, 0.8)
const FONT_SIZE: int = 36
const TITLE_FONT_SIZE: int = 48
const SEPARATION: int = 28
const BUTTON_SIZE: Vector2 = Vector2(360.0, 90.0)

var music_toggle: CheckButton = CheckButton.new()
var effects_toggle: CheckButton = CheckButton.new()
var vibrations_toggle: CheckButton = CheckButton.new()
var language_button: OptionButton = OptionButton.new()
var close_button: Button = Button.new()

var _save: SaveService


func setup(save: SaveService) -> void:
	_save = save


func _ready() -> void:
	color = SHADE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var column: VBoxContainer = VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", SEPARATION)
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(column)
	var title: Label = Label.new()
	title.text = tr("SETTINGS_TITLE")
	title.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	_add_toggle(music_toggle, "SETTINGS_MUSIC", GameSettings.MUSIC_KEY, column)
	_add_toggle(effects_toggle, "SETTINGS_EFFECTS", GameSettings.EFFECTS_KEY, column)
	_add_toggle(vibrations_toggle, "SETTINGS_VIBRATIONS", GameSettings.VIBRATIONS_KEY, column)
	_add_language(column)
	close_button.text = tr("SETTINGS_CLOSE")
	_prepare(close_button, column)
	close_button.pressed.connect(hide)


func open() -> void:
	music_toggle.set_pressed_no_signal(GameSettings.is_enabled(_save, GameSettings.MUSIC_KEY))
	effects_toggle.set_pressed_no_signal(GameSettings.is_enabled(_save, GameSettings.EFFECTS_KEY))
	vibrations_toggle.set_pressed_no_signal(GameSettings.is_enabled(_save, GameSettings.VIBRATIONS_KEY))
	show()


func _add_toggle(toggle: CheckButton, key: String, setting: String, column: VBoxContainer) -> void:
	toggle.text = tr(key)
	_prepare(toggle, column)
	toggle.toggled.connect(GameSettings.set_enabled.bind(_save, setting))


func _add_language(column: VBoxContainer) -> void:
	language_button.add_item(tr("LANGUAGE_FR"))
	language_button.add_item(tr("LANGUAGE_SOON"))
	language_button.set_item_disabled(1, true)
	language_button.select(0)
	_prepare(language_button, column)


func _prepare(control: BaseButton, column: VBoxContainer) -> void:
	control.custom_minimum_size = BUTTON_SIZE
	control.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	control.focus_mode = Control.FOCUS_NONE
	control.add_theme_font_size_override("font_size", FONT_SIZE)
	column.add_child(control)
