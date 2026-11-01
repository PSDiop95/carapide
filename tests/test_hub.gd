extends GutTest
## Hub : réglages, préchargement, file en MultiMesh, passage hub/niveau.


func before_all() -> void:
	UiStrings.register()


func _hub(save: SaveService) -> HubScreen:
	var hub: HubScreen = HubScreen.new()
	hub.configure(PresentationConfig.load_default(), save)
	add_child_autofree(hub)
	return hub


func test_settings_default_on_and_survive_changes() -> void:
	var save: SaveService = SaveService.new()
	assert_true(GameSettings.is_enabled(save, GameSettings.MUSIC_KEY))
	GameSettings.set_enabled(false, save, GameSettings.MUSIC_KEY)
	assert_false(GameSettings.is_enabled(save, GameSettings.MUSIC_KEY))
	assert_true(GameSettings.is_enabled(save, GameSettings.EFFECTS_KEY))


func test_haptics_respect_the_setting() -> void:
	var service: HapticsService = HapticsService.new()
	service.vibrate(10)
	service.enabled = false
	service.vibrate(20)
	assert_eq(service.vibrations_ms, PackedInt32Array([10]))


func test_vibrations_toggle_reaches_the_service() -> void:
	var save: SaveService = SaveService.new()
	GameSettings.set_enabled(false, save, GameSettings.VIBRATIONS_KEY)
	assert_false(Services.haptics.enabled)
	GameSettings.set_enabled(true, save, GameSettings.VIBRATIONS_KEY)
	assert_true(Services.haptics.enabled)


func test_preloader_gives_the_prepared_level_and_handles_another_path() -> void:
	var paths: PackedStringArray = LevelCatalog.level_paths()
	var preloader: LevelPreloader = LevelPreloader.new(VehicleCatalog.load_default())
	preloader.start(paths[2])
	var prepared: LevelLoadResult = preloader.take(paths[2])
	assert_true(prepared.is_ok())
	assert_eq(prepared.level.id, 3)
	assert_same(preloader.take(paths[2]), prepared, "Pas de seconde lecture")
	assert_eq(preloader.take(paths[4]).level.id, 5)


func test_hub_shows_level_coins_and_eight_passengers_in_one_multimesh() -> void:
	var hub: HubScreen = _hub(SaveService.new())
	hub.show_level(7)
	hub.set_coins(140)
	assert_eq(hub.level_label.text, tr("HUB_LEVEL") % 7)
	assert_eq(hub.coins_label.text, tr("COINS_LABEL") % 140)
	assert_eq(hub.passengers.multimesh.instance_count, 8)


func test_passengers_move_over_time() -> void:
	var hub: HubScreen = _hub(SaveService.new())
	var before: Vector2 = hub.passenger_position(0)
	hub._process(0.3)
	assert_ne(hub.passenger_position(0), before)


func test_shop_is_a_placeholder() -> void:
	var hub: HubScreen = _hub(SaveService.new())
	hub.shop_button.pressed.emit()
	assert_true(hub.hint_label.visible)
	assert_eq(hub.hint_label.text, tr("HUB_SOON"))


func test_language_offers_only_french() -> void:
	var hub: HubScreen = _hub(SaveService.new())
	assert_eq(hub.settings_panel.language_button.selected, 0)
	assert_true(hub.settings_panel.language_button.is_item_disabled(1))


func test_play_is_announced_not_acted_on() -> void:
	var hub: HubScreen = _hub(SaveService.new())
	watch_signals(hub)
	hub.play_button.pressed.emit()
	assert_signal_emitted(hub, "play_pressed")
