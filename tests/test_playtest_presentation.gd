extends GutTest
## Logique pure de la présentation du build de playtest.

const THRESHOLD: float = 14.0
const CSV_PATH: String = "user://test_playtest.csv"
const PATH_SAMPLES: int = 120

var _catalog: VehicleCatalog


func before_all() -> void:
	_catalog = VehicleCatalog.load_default()


func _touch(index: int, at: Vector2, pressed: bool) -> InputEventScreenTouch:
	var event: InputEventScreenTouch = InputEventScreenTouch.new()
	event.index = index
	event.position = at
	event.pressed = pressed
	return event


func _drag(index: int, at: Vector2) -> InputEventScreenDrag:
	var event: InputEventScreenDrag = InputEventScreenDrag.new()
	event.index = index
	event.position = at
	return event


func _moved(slot: int) -> GameEvent:
	return GameEvent.moved(0, slot)


func _departed(slot: int) -> GameEvent:
	var event: GameEvent = GameEvent.new(GameEvent.Type.DEPARTED)
	event.slot = slot
	return event


func test_every_picto_is_distinct_and_triangulates() -> void:
	var seen: Dictionary[String, bool] = {}
	for shape: String in PictoShapes.NAMES:
		var outline: PackedVector2Array = PictoShapes.points(shape)
		assert_gt(Geometry2D.triangulate_polygon(outline).size(), 0, shape)
		seen[str(outline)] = true
	assert_eq(seen.size(), 8)


func _vehicle_view(palette: ViewPalette) -> VehicleView:
	var level: LevelData = LevelLoader.load_file(LevelCatalog.level_paths()[0], VehicleCatalog.load_default()).level
	var view: VehicleView = VehicleView.new()
	view.setup(level.vehicles[0], Vector3.ZERO, palette)
	add_child_autofree(view)
	return view


func test_roof_merges_arrow_and_picto_in_one_surface_at_their_place() -> void:
	var palette: ViewPalette = ViewPalette.new(PresentationConfig.load_default())
	var dest: String = PresentationConfig.load_default().dest_pictos.keys()[0]
	var center: Vector3 = Vector3(-1.0, 0.6, 0.0)
	var heading: float = 0.7
	var roof: ArrayMesh = palette.roof_mesh(dest, Vector3.ZERO, center, 0.3, heading)
	assert_eq(roof.get_surface_count(), 1)
	var points: PackedVector3Array = roof.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var arrow_count: int = palette.arrow_mesh.surface_get_array_len(0)
	assert_eq(points.size(), arrow_count + palette.picto_mesh(dest).surface_get_array_len(0))
	var source: PackedVector3Array = palette.picto_mesh(dest).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var node: Node3D = Node3D.new()
	node.position = center
	node.rotation.y = -heading
	node.scale = Vector3.ONE * 0.3
	assert_almost_eq(points[arrow_count], node.transform * source[0], Vector3.ONE * 0.0001, "Même place que le nœud séparé")
	node.free()


func test_still_vehicle_uses_the_roof_moving_vehicle_the_separate_nodes() -> void:
	var view: VehicleView = _vehicle_view(ViewPalette.new(PresentationConfig.load_default()))
	assert_true(view._roof.visible)
	assert_false(view._arrow.visible)
	assert_false(view._picto.visible)
	view._set_heading(1.0)
	assert_false(view._roof.visible)
	assert_true(view._arrow.visible)
	assert_true(view._picto.visible)
	view._finish_parking()
	assert_false(view._roof.visible)
	assert_false(view._arrow.visible, "Garé : plus de flèche")
	assert_true(view._picto.visible)


func test_dioule_redraws_the_roof_of_a_still_vehicle() -> void:
	var config: PresentationConfig = PresentationConfig.load_default()
	var palette: ViewPalette = ViewPalette.new(config)
	var view: VehicleView = _vehicle_view(palette)
	var before: Mesh = view._roof.mesh
	var other: String = config.dest_pictos.keys()[1]
	view._show_dest(other, palette)
	assert_true(view._roof.visible)
	assert_ne(view._roof.mesh, before)


func test_every_destination_has_its_own_picto_and_name() -> void:
	var config: PresentationConfig = PresentationConfig.load_default()
	var pictos: Dictionary[String, bool] = {}
	for dest: String in config.dest_colors:
		pictos[config.picto_of(dest)] = true
		assert_true(PictoShapes.NAMES.has(config.picto_of(dest)), dest)
		assert_string_starts_with(config.name_key_of(dest), "DEST_")
	assert_eq(pictos.size(), 8)


func test_remaining_blocks_tell_the_truth_past_the_display_cap() -> void:
	var queue: Array[QueueBlock] = [QueueBlock.new("a", 24), QueueBlock.new("b", 300), QueueBlock.new("a", 4)]
	var blocks: Array[QueueBlock] = QueueDisplay.remaining_blocks(queue, 10)
	assert_eq(blocks.size(), 3)
	assert_eq(blocks[0].count, 14)
	assert_eq(blocks[1].count, 300)
	assert_eq(QueueDisplay.remaining_blocks(queue, 24)[0].dest, "b")


func test_remaining_blocks_merge_neighbours_without_touching_the_level() -> void:
	var queue: Array[QueueBlock] = [QueueBlock.new("a", 4), QueueBlock.new("a", 4)]
	var blocks: Array[QueueBlock] = QueueDisplay.remaining_blocks(queue, 0)
	assert_eq(blocks.size(), 1)
	assert_eq(blocks[0].count, 8)
	assert_eq(queue[0].count, 4, "Le niveau reste immuable")


func test_danger_levels_follow_free_slots() -> void:
	assert_eq(StationView.danger_for(2, 1, 0), StationView.Danger.NORMAL)
	assert_eq(StationView.danger_for(1, 1, 0), StationView.Danger.WARNING)
	assert_eq(StationView.danger_for(0, 1, 0), StationView.Danger.CRITICAL)


func test_replay_starts_moves_at_once_while_boarding_runs() -> void:
	var replay: ReplayQueue = ReplayQueue.new()
	assert_true(replay.add(_moved(0)))
	assert_false(replay.add(GameEvent.new(GameEvent.Type.BOARDED)))
	assert_true(replay.add(_moved(1)), "Une autre place n'attend pas le chargement")


func test_replay_holds_move_until_its_slot_is_visually_free() -> void:
	var replay: ReplayQueue = ReplayQueue.new()
	assert_true(replay.add(_moved(0)))
	assert_false(replay.add(_departed(0)))
	assert_false(replay.add(_moved(0)), "La place se libère seulement au rejeu du départ")
	assert_false(replay.add(_moved(0)), "Déjà promise au véhicule en attente")
	assert_eq(replay.next().type, GameEvent.Type.DEPARTED)
	assert_eq(replay.next().type, GameEvent.Type.MOVED)


func test_exit_paths_never_come_back_over_the_board() -> void:
	for path: String in LevelCatalog.level_paths():
		var level: LevelData = LevelLoader.load_file(path, _catalog).level
		var layout: LevelLayout = LevelLayout.new(level)
		for vehicle: LevelVehicle in level.vehicles:
			for slot: int in level.slots:
				_assert_path_stays_out(layout, vehicle, slot, path)


func _assert_path_stays_out(layout: LevelLayout, vehicle: LevelVehicle, slot: int, label: String) -> void:
	var curve: Curve3D = ExitPath.build(layout, vehicle, slot)
	var left_board: bool = false
	var length: float = curve.get_baked_length()
	var board: Rect2 = Rect2(0.0, 0.0, layout.board_width, layout.board_height)
	for step: int in PATH_SAMPLES + 1:
		var point: Vector2 = layout.world_to_board(curve.sample_baked(length * float(step) / float(PATH_SAMPLES)))
		var inside: bool = board.has_point(point)
		if left_board and inside:
			fail_test("%s véhicule %d place %d : retour sur le plateau en %s" % [label, vehicle.id, slot, point])
			return
		left_board = left_board or not inside
	var end: Vector3 = curve.sample_baked(length)
	assert_true(end.distance_to(layout.slot_world(slot)) < 0.01, "%s : arrive à sa place" % label)


func test_exit_path_follows_arrow_first() -> void:
	var level: LevelData = LevelLoader.load_file(LevelCatalog.level_paths()[0], _catalog).level
	var layout: LevelLayout = LevelLayout.new(level)
	var vehicle: LevelVehicle = level.vehicles[0]
	var points: PackedVector2Array = ExitPath.waypoints(layout, vehicle, 0)
	var direction: Vector2 = points[0].direction_to(points[1])
	assert_almost_eq(direction.angle_to(Vector2.from_angle(deg_to_rad(vehicle.angle))), 0.0, 0.001)


func test_exit_duration_budget_is_respected_by_config() -> void:
	assert_lte(PresentationConfig.load_default().exit_max_duration, 0.6)


func test_short_press_is_a_tap() -> void:
	var gestures: GestureTracker = GestureTracker.new(THRESHOLD)
	assert_eq(gestures.process(_touch(0, Vector2(10, 10), true)), GestureTracker.Kind.NONE)
	assert_eq(gestures.process(_touch(0, Vector2(12, 10), false)), GestureTracker.Kind.TAP)
	assert_eq(gestures.position, Vector2(12, 10))


func test_small_jitter_stays_a_tap() -> void:
	var gestures: GestureTracker = GestureTracker.new(THRESHOLD)
	gestures.process(_touch(0, Vector2(10, 10), true))
	assert_eq(gestures.process(_drag(0, Vector2(15, 10))), GestureTracker.Kind.NONE)
	assert_eq(gestures.process(_touch(0, Vector2(15, 10), false)), GestureTracker.Kind.TAP)


func test_drag_is_a_pan_and_never_a_tap() -> void:
	var gestures: GestureTracker = GestureTracker.new(THRESHOLD)
	gestures.process(_touch(0, Vector2(10, 10), true))
	assert_eq(gestures.process(_drag(0, Vector2(40, 10))), GestureTracker.Kind.PAN)
	assert_eq(gestures.delta, Vector2(30, 0))
	assert_eq(gestures.process(_touch(0, Vector2(40, 10), false)), GestureTracker.Kind.NONE)


func test_two_fingers_pinch_and_never_tap() -> void:
	var gestures: GestureTracker = GestureTracker.new(THRESHOLD)
	gestures.process(_touch(0, Vector2(100, 100), true))
	gestures.process(_touch(1, Vector2(200, 100), true))
	assert_eq(gestures.process(_drag(1, Vector2(300, 100))), GestureTracker.Kind.PINCH)
	assert_almost_eq(gestures.factor, 2.0, 0.001)
	assert_eq(gestures.process(_touch(1, Vector2(300, 100), false)), GestureTracker.Kind.NONE)
	assert_eq(gestures.process(_touch(0, Vector2(100, 100), false)), GestureTracker.Kind.NONE)


func test_zoom_is_bounded() -> void:
	var zoom: CameraZoom = CameraZoom.new(1.8)
	zoom.set_board(Vector2(-5, -6), Vector2(5, 2))
	zoom.zoom_at(10.0, Vector2.ZERO)
	assert_eq(zoom.zoom, 1.8)
	zoom.zoom_at(0.01, Vector2.ZERO)
	assert_eq(zoom.zoom, 1.0)


func test_no_pan_at_zoom_one_and_board_bound_at_max_zoom() -> void:
	var zoom: CameraZoom = CameraZoom.new(1.8)
	zoom.set_board(Vector2(-5, -6), Vector2(5, 2))
	zoom.pan_by(Vector2(100, 100))
	assert_eq(zoom.pan, Vector2.ZERO)
	zoom.zoom_at(1.8, Vector2.ZERO)
	zoom.pan_by(Vector2(100, 100))
	assert_eq(zoom.pan, Vector2(5, 2))
	zoom.pan_by(Vector2(-100, -100))
	assert_eq(zoom.pan, Vector2(-5, -6))


func test_zoom_keeps_anchor_under_the_finger() -> void:
	var zoom: CameraZoom = CameraZoom.new(1.8)
	zoom.set_board(Vector2(-5, -6), Vector2(5, 6))
	var anchor: Vector2 = Vector2(1, 1)
	var before: Vector2 = zoom.pan + anchor / zoom.zoom
	zoom.zoom_at(1.5, anchor)
	assert_almost_eq((zoom.pan + anchor / zoom.zoom).distance_to(before), 0.0, 0.001)


func test_hidden_taps_need_five_within_the_window() -> void:
	var detector: HiddenTapDetector = HiddenTapDetector.new(5, 3000)
	for at: int in [0, 100, 200, 300]:
		assert_false(detector.register(at))
	assert_true(detector.register(400))
	assert_false(detector.register(500), "La série repart de zéro")


func test_hidden_taps_too_slow_do_not_count() -> void:
	var detector: HiddenTapDetector = HiddenTapDetector.new(5, 3000)
	for at: int in [0, 1000, 2000, 3000, 4000]:
		assert_false(detector.register(at))


func test_telemetry_reports_fail_details_and_duration() -> void:
	var analytics: AnalyticsService = AnalyticsService.new()
	var telemetry: LevelTelemetry = LevelTelemetry.new(analytics)
	telemetry.level_started(4, 1000)
	telemetry.vehicle_moved()
	telemetry.vehicle_moved()
	telemetry.tap_blocked()
	telemetry.level_failed(4, "pikine", 13500)
	telemetry.level_restarted()
	assert_eq(analytics.logged_events, ["level_start", "tap_blocked", "level_fail", "level_restart"] as Array[String])
	var fail: Dictionary = analytics.logged_params[2]
	var occupied: int = fail["occupied_slots"]
	var head: String = fail["head_dest"]
	var moves: int = fail["moves"]
	var blocked: int = fail["blocked_taps"]
	assert_eq(occupied, 4)
	assert_eq(head, "pikine")
	assert_eq(moves, 2)
	assert_eq(blocked, 1)
	var seconds: float = fail["duration_s"]
	assert_almost_eq(seconds, 12.5, 0.01)


func test_csv_appends_rows_across_instances() -> void:
	DirAccess.remove_absolute(CSV_PATH)
	var first: CsvAnalyticsService = CsvAnalyticsService.new(CSV_PATH)
	first.tester = 3
	first.log_event("level_start", {"level": 4})
	var second: CsvAnalyticsService = CsvAnalyticsService.new(CSV_PATH)
	second.log_event("level_fail", {"level": 4, "occupied_slots": 4, "head_dest": "yoff", "moves": 7, "duration_s": 12.5})
	assert_eq(second.row_count(), 2)
	var lines: PackedStringArray = second.csv_text().strip_edges().split("\n")
	assert_eq(lines[0], CsvAnalyticsService.HEADER)
	assert_string_starts_with(lines[1], "3,")
	assert_string_ends_with(lines[2], ",level_fail,4,4,yoff,7,,12.5,,,,,")
	DirAccess.remove_absolute(CSV_PATH)


func test_haptics_mock_records_duration() -> void:
	var haptics: HapticsService = HapticsService.new()
	haptics.vibrate(80)
	assert_eq(haptics.vibrations_ms[0], 80)
