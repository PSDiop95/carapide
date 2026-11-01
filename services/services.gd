extends Node
## Point d'accès aux services (autoload `Services`). Mocks par défaut, aucun SDK.

const SAVE_PATH: String = "user://progress.json"

var save: SaveService = FileSaveService.new(SAVE_PATH)
var analytics: AnalyticsService = AnalyticsService.new()
