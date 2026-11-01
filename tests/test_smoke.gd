extends GutTest


func test_save_service_mock_returns_default_then_value() -> void:
	var save: SaveService = SaveService.new()
	assert_eq(save.get_int("level", 1), 1)
	save.set_int("level", 4)
	assert_eq(save.get_int("level", 1), 4)


func test_file_save_service_persists_between_instances() -> void:
	var path: String = "user://test_progress.json"
	var first: FileSaveService = FileSaveService.new(path)
	first.set_int("level", 7)
	var second: FileSaveService = FileSaveService.new(path)
	assert_eq(second.get_int("level", 1), 7)
	DirAccess.remove_absolute(path)


func test_analytics_mock_records_events() -> void:
	var analytics: AnalyticsService = AnalyticsService.new()
	analytics.log_event("level_start")
	assert_eq(analytics.logged_events, ["level_start"] as Array[String])
