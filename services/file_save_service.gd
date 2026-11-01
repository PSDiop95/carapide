class_name FileSaveService
extends SaveService
## Sauvegarde locale JSON (hors ligne, GDD §8).

var _path: String


func _init(path: String) -> void:
	_path = path
	_read()


func set_int(key: String, value: int) -> void:
	super.set_int(key, value)
	var file: FileAccess = FileAccess.open(_path, FileAccess.WRITE)
	if file == null:
		push_error("Sauvegarde impossible : %s" % _path)
		return
	file.store_string(JSON.stringify(_values))


func _read() -> void:
	if not FileAccess.file_exists(_path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_path))
	if parsed is Dictionary:
		_values = parsed
