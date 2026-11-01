class_name LevelView
extends Node3D
## Scène d'un niveau. Transmet les taps à GameRules et rejoue les événements renvoyés ;
## n'écrit jamais l'état de jeu.

signal passengers_counted(remaining: int)
signal level_ended(won: bool)

const CAMERA_DISTANCE: float = 40.0
const CAMERA_HEIGHT_MARGIN: float = 1.0
const BACKGROUND_COLOR: Color = Color(0.86, 0.86, 0.84)
const BOARD_COLOR: Color = Color(0.5, 0.5, 0.52)
const AMBIENT_ENERGY: float = 0.7
const SUN_ANGLES: Vector3 = Vector3(-60.0, -30.0, 0.0)

var camera: Camera3D = Camera3D.new()
var layout: LevelLayout

var _rules: GameRules
var _config: PresentationConfig
var _level: LevelData
var _palette: ViewPalette
var _queue_view: QueueView = QueueView.new()
var _station_view: StationView = StationView.new()
var _vehicles: Dictionary[int, VehicleView] = {}
var _pending: Array[GameEvent] = []
var _playing: bool = false
var _remaining: int = 0


func setup(level: LevelData, config: PresentationConfig) -> void:
	_level = level
	_config = config
	_rules = GameRules.new(level)
	layout = LevelLayout.new(level)
	_palette = ViewPalette.new(config)
	_remaining = level.total_passengers()
	_build_environment()
	_build_board()
	_station_view.setup(layout, config)
	add_child(_station_view)
	_queue_view.setup(level, layout, _palette)
	add_child(_queue_view)
	for vehicle: LevelVehicle in level.vehicles:
		_add_vehicle(vehicle)
	add_child(camera)
	frame_camera()
	get_viewport().size_changed.connect(frame_camera)
	passengers_counted.emit.call_deferred(_remaining)


func frame_camera() -> void:
	var tilt: float = deg_to_rad(_config.camera_tilt_degrees)
	var center: Vector3 = Vector3(0.0, 0.0, (layout.top_z() + layout.bottom_z()) * 0.5)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	var view_size: Vector2 = get_viewport().get_visible_rect().size
	var needed_height: float = (layout.bottom_z() - layout.top_z()) * sin(tilt) + CAMERA_HEIGHT_MARGIN
	camera.size = maxf(layout.scene_width(), needed_height * view_size.x / view_size.y)
	camera.position = center + Vector3(0.0, sin(tilt), cos(tilt)) * CAMERA_DISTANCE
	camera.look_at_from_position(camera.position, center)


func _unhandled_input(event: InputEvent) -> void:
	var touch: InputEventScreenTouch = event as InputEventScreenTouch
	if touch != null and touch.pressed:
		_handle_tap(touch.position)


func _handle_tap(screen_position: Vector2) -> void:
	var board_point: Vector2 = screen_to_board(screen_position)
	var vehicle_id: int = _rules.vehicle_at(board_point.x, board_point.y, _config.tap_tolerance)
	if vehicle_id == BoardLogic.NO_VEHICLE:
		return
	for event: GameEvent in _rules.tap(vehicle_id):
		if event.type == GameEvent.Type.BLOCKED:
			_play_blocked(event)
		else:
			_pending.append(event)
	_play_pending()


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
	while not _pending.is_empty():
		var event: GameEvent = _pending.pop_front()
		await _play_event(event)
	_playing = false


func _play_event(event: GameEvent) -> void:
	match event.type:
		GameEvent.Type.MOVED:
			_station_view.vehicle_arrived()
			var exit_world: Vector3 = layout.exit_point(_level.vehicles[event.vehicle_id])
			await _vehicles[event.vehicle_id].drive_to_slot(exit_world, layout.slot_world(event.slot), _config.exit_duration)
		GameEvent.Type.BOARDED:
			await _play_boarding(event)
		GameEvent.Type.DEPARTED:
			_station_view.vehicle_departed()
			var view: VehicleView = _vehicles[event.vehicle_id]
			_vehicles.erase(event.vehicle_id)
			await view.depart(_config.depart_duration)
		GameEvent.Type.WON:
			level_ended.emit(true)
		GameEvent.Type.LOST:
			level_ended.emit(false)


func _play_boarding(event: GameEvent) -> void:
	var view: VehicleView = _vehicles[event.vehicle_id]
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
