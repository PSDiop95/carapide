extends GutTest


func test_starts_at_first_level() -> void:
	assert_eq(LevelProgress.current_level(SaveService.new(), 10), 1)


func test_win_advances_and_is_saved() -> void:
	var save: SaveService = SaveService.new()
	assert_eq(LevelProgress.record_win(save, 1, 10), 2)
	assert_eq(LevelProgress.current_level(save, 10), 2)


func test_win_on_last_level_returns_to_first() -> void:
	var save: SaveService = SaveService.new()
	assert_true(LevelProgress.is_last(10, 10))
	assert_eq(LevelProgress.record_win(save, 10, 10), 1)
	assert_eq(LevelProgress.current_level(save, 10), 1)


func test_saved_level_beyond_catalog_is_clamped() -> void:
	var save: SaveService = SaveService.new()
	save.set_int(LevelProgress.KEY, 42)
	assert_eq(LevelProgress.current_level(save, 10), 10)


func test_progress_survives_restart_on_disk() -> void:
	var path: String = "user://test_level_progress.json"
	LevelProgress.record_win(FileSaveService.new(path), 3, 10)
	assert_eq(LevelProgress.current_level(FileSaveService.new(path), 10), 4)
	DirAccess.remove_absolute(path)
