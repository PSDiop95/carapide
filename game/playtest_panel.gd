class_name PlaytestPanel
extends ColorRect
## Écran caché du playtest : partage du CSV, changement de testeur.

signal new_tester_requested

const SHADE: Color = Color(0.0, 0.0, 0.0, 0.85)
const FONT_SIZE: int = 30
const STATUS_FONT_SIZE: int = 22
const BUTTON_SIZE: Vector2 = Vector2(560.0, 96.0)
const SEPARATION: int = 20
const EXPORT_FILE: String = "carapide_playtest.csv"

var _title: Label = Label.new()
var _summary: Label = Label.new()
var _status: Label = Label.new()


func _ready() -> void:
	color = SHADE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column: VBoxContainer = VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", SEPARATION)
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(column)
	_prepare_label(_title, FONT_SIZE)
	column.add_child(_title)
	_prepare_label(_summary, FONT_SIZE)
	column.add_child(_summary)
	column.add_child(_button("PLAYTEST_COPY", _copy))
	column.add_child(_button("PLAYTEST_SAVE", _save))
	column.add_child(_button("PLAYTEST_NEW_TESTER", _new_tester))
	column.add_child(_button("PLAYTEST_CLOSE", hide))
	_prepare_label(_status, STATUS_FONT_SIZE)
	column.add_child(_status)
	hide()


func open() -> void:
	_title.text = tr("PLAYTEST_TITLE")
	_summary.text = tr("PLAYTEST_SUMMARY") % [Services.analytics.tester, Services.analytics.row_count()]
	_status.text = ""
	show()


func _copy() -> void:
	DisplayServer.clipboard_set(Services.analytics.csv_text())
	_status.text = tr("PLAYTEST_COPIED")


func _save() -> void:
	var path: String = OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS).path_join(EXPORT_FILE)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_status.text = tr("PLAYTEST_SAVE_FAILED")
		return
	file.store_string(Services.analytics.csv_text())
	file.close()
	_status.text = tr("PLAYTEST_SAVED") % path


func _new_tester() -> void:
	new_tester_requested.emit()
	hide()


func _button(key: String, action: Callable) -> Button:
	var button: Button = Button.new()
	button.text = tr(key)
	button.custom_minimum_size = BUTTON_SIZE
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_size_override("font_size", FONT_SIZE)
	button.pressed.connect(action)
	return button


func _prepare_label(label: Label, font_size: int) -> void:
	label.add_theme_font_size_override("font_size", font_size)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
