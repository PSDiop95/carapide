extends Node
## Point d'entrée : charge le niveau courant et affiche sa vue.

var view: LevelView = null

var _catalog: VehicleCatalog
var _config: PresentationConfig


func _ready() -> void:
	_catalog = VehicleCatalog.load_default()
	_config = PresentationConfig.load_default()
	_start_level(LevelCatalog.level_paths()[0])


func _start_level(path: String) -> void:
	var loaded: LevelLoadResult = LevelLoader.load_file(path, _catalog)
	if not loaded.is_ok():
		push_error("Niveau invalide : %s" % "; ".join(loaded.errors))
		return
	if view != null:
		view.queue_free()
	view = LevelView.new()
	add_child(view)
	view.setup(loaded.level, _config)
	Events.level_started.emit(loaded.level.id)
