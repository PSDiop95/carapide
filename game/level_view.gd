class_name LevelView
extends Node3D
## Scène d'un niveau. Transmet les taps à GameRules et rejoue les événements renvoyés ;
## n'écrit jamais l'état de jeu.

signal passengers_counted(remaining: int)
signal level_ended(won: bool)
signal queue_blocks_changed(blocks: Array[QueueBlock])
signal vehicle_moved
signal tap_blocked
signal rescue_needed
signal replay_finished
signal vehicle_targeted(vehicle_id: int)

const CAMERA_DISTANCE: float = 40.0
const CAMERA_HEIGHT_MARGIN: float = 1.0
const BACKGROUND_COLOR: Color = Color(0.86, 0.86, 0.84)
const BOARD_COLOR: Color = Color(0.5, 0.5, 0.52)
const AMBIENT_ENERGY: float = 0.7
const SUN_ANGLES: Vector3 = Vector3(-60.0, -30.0, 0.0)

var camera: Camera3D = Camera3D.new()
var layout: LevelLayout
## Faux pendant une pop-up, un tutoriel ou une pub : aucun tap n'atteint le plateau.
var input_enabled: bool = true
## Vrai pendant la visée du Coxeur : le tap désigne un véhicule, sans le sortir.
var targeting: bool = false
## Vrai si l'interface couvre ce point : un tap sur un bouton ne doit pas sortir le véhicule dessous.
var tap_guard: Callable = Callable()

var _rules: GameRules
var _config: PresentationConfig
var _level: LevelData
var _palette: ViewPalette
var _queue_view: QueueView = QueueView.new()
var _station_view: StationView = StationView.new()
var _vehicles: Dictionary[int, VehicleView] = {}
var _replay: ReplayQueue = ReplayQueue.new()
var _playing: bool = false
var _remaining: int = 0
var _moving: int = 0
var _gestures: GestureTracker
var _zoom: CameraZoom
var _frame_size: float = 0.0
var _frame_position: Vector3 = Vector3.ZERO
## Véhicules affichés dans la rangée Garage, dans l'ordre.
var _garage_row: PackedInt32Array = PackedInt32Array()


## Sans `access` : partie sans booster, comportement du build de playtest A.
func setup(level: LevelData, config: PresentationConfig, access: BoosterAccess = null, coxeur_visible: bool = false) -> void:
	_level = level
	_config = config
	_rules = GameRules.new(level, access)
	layout = LevelLayout.new(level, coxeur_visible, access != null)
	_palette = ViewPalette.new(config)
	_remaining = level.total_passengers()
	_build_environment()
	_build_board()
	_station_view.setup(layout, config, _palette)
	_station_view.critical_entered.connect(_on_critical_entered)
	add_child(_station_view)
	_queue_view.blocks_changed.connect(queue_blocks_changed.emit)
	add_child(_queue_view)
	_queue_view.setup(level, layout, _palette, config.queue_sign_count)
	_gestures = GestureTracker.new(config.tap_move_threshold)
	_zoom = CameraZoom.new(config.zoom_max)
	for vehicle: LevelVehicle in level.vehicles:
		_add_vehicle(vehicle)
	add_child(camera)
	frame_camera()
	get_viewport().size_changed.connect(frame_camera)
	passengers_counted.emit.call_deferred(_remaining)
	queue_blocks_changed.emit.call_deferred(_queue_view.current_blocks())


func frame_camera() -> void:
	var tilt: float = deg_to_rad(_config.camera_tilt_degrees)
	var center: Vector3 = Vector3(0.0, 0.0, (layout.top_z() + layout.bottom_z()) * 0.5)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	var view_size: Vector2 = get_viewport().get_visible_rect().size
	var needed_height: float = (layout.bottom_z() - layout.top_z()) * sin(tilt) + CAMERA_HEIGHT_MARGIN
	_frame_size = maxf(layout.scene_width(), needed_height * view_size.x / view_size.y)
	_frame_position = center + Vector3(0.0, sin(tilt), cos(tilt)) * CAMERA_DISTANCE
	camera.look_at_from_position(_frame_position, center)
	var half_width: float = layout.board_width * 0.5
	_zoom.set_board(Vector2(-half_width, (center.z - layout.board_height) * sin(tilt)), Vector2(half_width, center.z * sin(tilt)))
	_apply_zoom()


func occupied_slots() -> int:
	return _rules.occupied_slots()


func head_dest() -> String:
	return _rules.head_dest()


func is_playing() -> bool:
	return _rules.status == GameRules.Status.PLAYING


func is_blocked() -> bool:
	return _rules.status == GameRules.Status.BLOCKED


func can_use_coxeur(vehicle_id: int) -> bool:
	return _rules.can_use_coxeur(vehicle_id)


func can_use_apprenti() -> bool:
	return _rules.can_use_apprenti()


func advise(access: BoosterAccess) -> BoosterAdvice:
	return BoosterSolver.advise(_rules, access)


func tutorial_vehicle() -> int:
	return _rules.tutorial_vehicle()


func level_vehicle(vehicle_id: int) -> LevelVehicle:
	return _level.vehicles[vehicle_id]


func can_use_dioule() -> bool:
	return _rules.can_use_dioule()


func play_coxeur(vehicle_id: int) -> void:
	_apply(_rules.use_coxeur(vehicle_id))


func play_apprenti() -> void:
	_apply(_rules.use_apprenti())


## Mélange choisi par le solveur ; vide si aucun n'est soluble (booster alors non consommé).
func compute_dioule(max_nodes: int) -> PackedStringArray:
	return DiouleMixer.mix(_rules, max_nodes)


func play_dioule(dests: PackedStringArray) -> void:
	_apply(_rules.use_dioule(dests))


func can_use_garage() -> bool:
	return _rules.can_use_garage()


func play_garage() -> void:
	_apply(_rules.use_garage())


func play_abandon() -> void:
	_apply(_rules.abandon())


## Mesure : sort le premier véhicule libre, comme un tap.
func measure_tap() -> void:
	var free: PackedInt32Array = _rules.free_vehicles()
	if not free.is_empty():
		_apply(_rules.tap(free[0]))


func _unhandled_input(event: InputEvent) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null and button.pressed:
		if input_enabled:
			_handle_wheel(button)
		return
	var gesture: GestureTracker.Kind = _gestures.process(event)
	if not input_enabled:
		return
	match gesture:
		GestureTracker.Kind.TAP:
			_handle_tap(_gestures.position)
		GestureTracker.Kind.PAN:
			_pan_screen(_gestures.delta)
		GestureTracker.Kind.PINCH:
			_pan_screen(_gestures.delta)
			_zoom.zoom_at(_gestures.factor, _screen_anchor(_gestures.position))
			_apply_zoom()


func _handle_wheel(button: InputEventMouseButton) -> void:
	var step: float = _config.zoom_wheel_step
	if button.button_index == MOUSE_BUTTON_WHEEL_UP:
		_zoom.zoom_at(step, _screen_anchor(button.position))
	elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_zoom.zoom_at(1.0 / step, _screen_anchor(button.position))
	_apply_zoom()


## Déplace la vue pour que le décor suive le doigt.
func _pan_screen(screen_delta: Vector2) -> void:
	var units_per_pixel: float = camera.size / get_viewport().get_visible_rect().size.x
	_zoom.pan_by(Vector2(-screen_delta.x, screen_delta.y) * units_per_pixel)
	_apply_zoom()


## Point écran par rapport au centre, dans le plan caméra, en unités à ×1.
func _screen_anchor(at: Vector2) -> Vector2:
	var view_size: Vector2 = get_viewport().get_visible_rect().size
	var offset: Vector2 = at - view_size * 0.5
	return Vector2(offset.x, -offset.y) * _frame_size / view_size.x


func _apply_zoom() -> void:
	camera.size = _frame_size / _zoom.zoom
	camera.position = _frame_position + camera.basis.x * _zoom.pan.x + camera.basis.y * _zoom.pan.y


func _handle_tap(screen_position: Vector2) -> void:
	if tap_guard.is_valid() and tap_guard.call(screen_position):
		return
	var board_point: Vector2 = screen_to_board(screen_position)
	var vehicle_id: int = _rules.vehicle_at(board_point.x, board_point.y, _config.tap_tolerance)
	if vehicle_id == BoardLogic.NO_VEHICLE:
		return
	if targeting:
		vehicle_targeted.emit(vehicle_id)
		return
	_apply(_rules.tap(vehicle_id))


func _apply(events: Array[GameEvent]) -> void:
	for event: GameEvent in events:
		_dispatch(event)
	_play_pending()


func _dispatch(event: GameEvent) -> void:
	if event.type == GameEvent.Type.BLOCKED:
		tap_blocked.emit()
		_play_blocked(event)
		return
	if event.type == GameEvent.Type.MOVED:
		vehicle_moved.emit()
	if _replay.add(event):
		_start_move(event)


## Rayon écran : intersection avec le plan des toits, sans physique.
func screen_to_board(screen_position: Vector2) -> Vector2:
	var origin: Vector3 = camera.project_ray_origin(screen_position)
	var direction: Vector3 = camera.project_ray_normal(screen_position)
	var travel: float = (LevelLayout.ROOF_HEIGHT - origin.y) / direction.y
	return layout.world_to_board(origin + direction * travel)


## Position écran du toit d'un véhicule.
func vehicle_screen_position(vehicle: LevelVehicle) -> Vector2:
	var world: Vector3 = layout.board_to_world(vehicle.pos_x, vehicle.pos_y) + Vector3.UP * LevelLayout.ROOF_HEIGHT
	return camera.unproject_position(world)


func _play_blocked(event: GameEvent) -> void:
	_vehicles[event.vehicle_id].bump(_config.bump_distance, _config.bump_duration)
	_vehicles[event.blocker_id].highlight(_config.blocked_highlight_duration)


func _play_pending() -> void:
	if _playing:
		return
	_playing = true
	while not _replay.is_empty():
		await _play_event(_replay.next())
	_playing = false
	await _wait_for_moves()
	if not _playing:
		replay_finished.emit()


func _play_event(event: GameEvent) -> void:
	match event.type:
		GameEvent.Type.MOVED, GameEvent.Type.FLEW:
			_start_move(event)
		GameEvent.Type.QUEUE_REORDERED:
			_queue_view.replace_remaining(event.blocks)
		GameEvent.Type.DESTINATIONS_CHANGED:
			await _play_dioule(event)
		GameEvent.Type.GARAGED:
			await _play_garaged(event)
		GameEvent.Type.RECALLED:
			await _play_recalled(event)
		GameEvent.Type.RESCUE_NEEDED:
			await _wait_for_moves()
			if is_blocked():
				rescue_needed.emit()
		GameEvent.Type.BOARDED:
			await _play_boarding(event)
		GameEvent.Type.DEPARTED:
			_station_view.vehicle_departed(event.slot)
			var view: VehicleView = _vehicles[event.vehicle_id]
			_vehicles.erase(event.vehicle_id)
			await view.depart(_config.depart_duration)
		GameEvent.Type.WON:
			await _wait_for_moves()
			level_ended.emit(true)
		GameEvent.Type.LOST:
			await _wait_for_moves()
			level_ended.emit(false)


## Lance le trajet sans attendre : les taps suivants ne font pas la queue derrière.
func _start_move(event: GameEvent) -> void:
	var vehicle: LevelVehicle = _level.vehicles[event.vehicle_id]
	_station_view.vehicle_arrived(event.slot, event.dest)
	if event.type == GameEvent.Type.FLEW:
		_moving += 1
		await _vehicles[event.vehicle_id].fly_to(layout.slot_world(event.slot), _config.coxeur_flight_duration, _config.coxeur_arc_height, _palette.shadow_material)
		_moving -= 1
		return
	var path: Curve3D = ExitPath.build(layout, vehicle, event.slot)
	var duration: float = clampf(path.get_baked_length() / _config.exit_speed, _config.exit_min_duration, _config.exit_max_duration)
	_moving += 1
	await _vehicles[event.vehicle_id].drive_along(path, duration)
	_moving -= 1


func _wait_for_moves() -> void:
	while _moving > 0:
		await get_tree().process_frame


func _on_critical_entered() -> void:
	Services.haptics.vibrate(_config.danger_vibration_ms)


## La gare redessinée d'abord : les véhicules quittent des places qui n'existent plus.
func _play_garaged(event: GameEvent) -> void:
	_station_view.rebuild_after_garage(event.count)
	_garage_row.append_array(event.garaged_ids)
	_arrange_garage_row()
	await get_tree().create_timer(_config.garage_move_duration).timeout


func _play_recalled(event: GameEvent) -> void:
	_garage_row.remove_at(_garage_row.find(event.vehicle_id))
	_arrange_garage_row()
	_station_view.vehicle_arrived(event.slot, event.dest)
	await _vehicles[event.vehicle_id].return_from_garage(layout.slot_world(event.slot), _config.garage_move_duration)


func _arrange_garage_row() -> void:
	for index: int in _garage_row.size():
		var target: Vector3 = layout.garage_world(index, _garage_row.size())
		_vehicles[_garage_row[index]].move_to_garage(target, _config.garage_vehicle_scale, _config.garage_move_duration)


## Vague de gauche à droite ; aucun tap pendant le saut.
func _play_dioule(event: GameEvent) -> void:
	input_enabled = false
	var ids: Array[int] = event.dests_by_vehicle.keys()
	ids.sort_custom(func(a: int, b: int) -> bool: return _level.vehicles[a].pos_x < _level.vehicles[b].pos_x)
	var hop: float = _config.dioule_hop_duration
	var step: float = (_config.dioule_wave_duration - hop) / float(maxi(ids.size() - 1, 1))
	for index: int in ids.size():
		_vehicles[ids[index]].hop_to_dest(event.dests_by_vehicle[ids[index]], _palette, float(index) * step, hop, _config.dioule_hop_height)
	await get_tree().create_timer(_config.dioule_wave_duration).timeout
	input_enabled = true


func _play_boarding(event: GameEvent) -> void:
	var view: VehicleView = _vehicles[event.vehicle_id]
	if not view.is_parked:
		await view.parked
	var loaded: int = event.loaded - event.count
	for _passenger: int in event.count:
		loaded += 1
		_remaining -= 1
		_queue_view.advance(1)
		view.set_loaded(loaded)
		passengers_counted.emit(_remaining)
		await get_tree().create_timer(1.0 / _config.boarding_rate).timeout


func _add_vehicle(vehicle: LevelVehicle) -> void:
	var view: VehicleView = VehicleView.new()
	view.setup(vehicle, layout.board_to_world(vehicle.pos_x, vehicle.pos_y), _palette)
	add_child(view)
	_vehicles[vehicle.id] = view


func _build_board() -> void:
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(layout.board_width, layout.board_height)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = BOARD_COLOR
	var board: MeshInstance3D = MeshInstance3D.new()
	board.mesh = plane
	board.material_override = material
	board.position = layout.board_to_world(layout.board_width * 0.5, layout.board_height * 0.5)
	add_child(board)


func _build_environment() -> void:
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = BACKGROUND_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.WHITE
	environment.ambient_light_energy = AMBIENT_ENERGY
	var world: WorldEnvironment = WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = SUN_ANGLES
	add_child(sun)
