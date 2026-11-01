class_name VehicleView
extends Node3D
## Véhicule gris : boîte colorée, flèche et pictogramme sur le toit. Rejoue ce qu'on lui demande, sans décider.

signal parked

const HEIGHT: float = 0.6
const DEPART_DISTANCE: float = 20.0
const PARKED_ANGLE: float = PI * 0.5
const ARROW_FORWARD: float = 0.2
const PICTO_REAR_INSET: float = 0.45
const PICTO_RADIUS: float = 0.3
const ROOF_LIFT: float = 0.01
const HEADING_LOOK_AHEAD: float = 0.05
const COUNT_LABEL_PIXEL_SIZE: float = 0.012
const COUNT_LABEL_FONT_SIZE: int = 64
const COUNT_LABEL_OUTLINE: int = 18
const COUNT_LABEL_GAP: float = 0.35
const PARKED_LABEL_Y: float = 0.02
const SHADOW_Y: float = 0.03
const SHADOW_MIN_SCALE: float = 0.5

var is_parked: bool = false

var _body: MeshInstance3D = MeshInstance3D.new()
var _arrow: MeshInstance3D = MeshInstance3D.new()
var _picto: MeshInstance3D = MeshInstance3D.new()
## Immobile sur le plateau : flèche et pictogramme réunis. Dès que le cap change, les deux nœuds reprennent.
var _roof: MeshInstance3D = MeshInstance3D.new()
var _count_label: Label3D = null
var _capacity: int = 0
var _length: float = 0.0
var _width: float = 0.0
var _highlight_material: Material
var _dest_material: Material
var _path: Curve3D = null
var _shadow: MeshInstance3D = null


func setup(vehicle: LevelVehicle, world_position: Vector3, palette: ViewPalette) -> void:
	_capacity = vehicle.capacity
	_length = vehicle.length
	_width = vehicle.width
	_highlight_material = palette.highlight_material
	position = world_position
	_body.mesh = palette.body_mesh(vehicle.length, vehicle.width)
	_dest_material = palette.dest_material(vehicle.dest)
	_body.material_override = _dest_material
	_body.position.y = HEIGHT * 0.5
	add_child(_body)
	_arrow.mesh = palette.arrow_mesh
	_arrow.material_override = palette.arrow_material
	_arrow.position = Vector3(ARROW_FORWARD, HEIGHT + ROOF_LIFT, 0.0)
	add_child(_arrow)
	_picto.mesh = palette.picto_mesh(vehicle.dest)
	_picto.material_override = palette.picto_material
	_picto.position = Vector3(-vehicle.length * 0.5 + PICTO_REAR_INSET, HEIGHT + ROOF_LIFT, 0.0)
	_picto.scale = Vector3.ONE * PICTO_RADIUS
	add_child(_picto)
	_set_heading(deg_to_rad(vehicle.angle))
	_roof.material_override = palette.picto_material
	add_child(_roof)
	_show_roof(vehicle.dest, palette)


## Suit le trajet à vitesse lissée puis s'annonce garé. `duration` calculée par la scène.
func drive_along(path: Curve3D, duration: float) -> void:
	_path = path
	var tween: Tween = create_tween()
	tween.tween_method(_follow_path, 0.0, path.get_baked_length(), duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	_finish_parking()


## Vol du Coxeur : arc en cloche, ombre au sol qui rétrécit avec la hauteur.
func fly_to(target: Vector3, duration: float, arc_height: float, shadow_material: Material) -> void:
	_add_shadow(shadow_material)
	var start: Vector3 = position
	var tween: Tween = create_tween()
	tween.tween_method(_fly_step.bind(start, target, arc_height, rotation.y), 0.0, 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	_shadow.queue_free()
	_finish_parking()


## Rangée Garage : le véhicule rétrécit, à plat, sans quitter la scène.
func move_to_garage(target: Vector3, ratio: float, duration: float) -> void:
	is_parked = false
	var tween: Tween = create_tween().set_parallel()
	tween.tween_property(self, "position", target, duration)
	tween.tween_property(self, "scale", Vector3.ONE * ratio, duration)
	tween.tween_method(_set_heading, rotation.y, 0.0, duration)
	await tween.finished


## Retour à une place de la gare, passagers conservés.
func return_from_garage(target: Vector3, duration: float) -> void:
	var tween: Tween = create_tween().set_parallel()
	tween.tween_property(self, "position", target, duration)
	tween.tween_property(self, "scale", Vector3.ONE, duration)
	tween.tween_method(_set_heading, rotation.y, PARKED_ANGLE, duration)
	await tween.finished
	is_parked = true
	parked.emit()


func set_loaded(loaded: int) -> void:
	_show_remaining(_capacity - loaded)


func depart(duration: float) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(self, "position:z", position.z - DEPART_DISTANCE, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.finished
	queue_free()


func bump(distance: float, duration: float) -> void:
	var forward: Vector3 = Vector3(cos(rotation.y), 0.0, -sin(rotation.y))
	var start: Vector3 = position
	var tween: Tween = create_tween()
	tween.tween_property(self, "position", start + forward * distance, duration * 0.5)
	tween.tween_property(self, "position", start, duration * 0.5)


func highlight(duration: float) -> void:
	if _body.material_override == _highlight_material:
		return
	_body.material_override = _highlight_material
	var tween: Tween = create_tween()
	tween.tween_interval(duration)
	tween.tween_callback(_restore_material)


## Saut du Dioulé : la couleur change au sommet, le pictogramme avec.
func hop_to_dest(dest: String, palette: ViewPalette, delay: float, duration: float, height: float) -> void:
	var ground: float = position.y
	var tween: Tween = create_tween()
	tween.tween_interval(delay)
	tween.tween_property(self, "position:y", ground + height, duration * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_show_dest.bind(dest, palette))
	tween.tween_property(self, "position:y", ground, duration * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _fly_step(progress: float, start: Vector3, target: Vector3, arc_height: float, start_heading: float) -> void:
	var height: float = arc_height * sin(PI * progress)
	position = start.lerp(target, progress) + Vector3.UP * height
	_set_heading(lerp_angle(start_heading, PARKED_ANGLE, progress))
	_shadow.position.y = SHADOW_Y - height
	var ratio: float = 1.0 - (1.0 - SHADOW_MIN_SCALE) * height / maxf(arc_height, 0.001)
	_shadow.scale = Vector3(ratio, 1.0, ratio)


func _add_shadow(material: Material) -> void:
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(_length, _width)
	_shadow = MeshInstance3D.new()
	_shadow.mesh = plane
	_shadow.material_override = material
	_shadow.position.y = SHADOW_Y
	add_child(_shadow)


func _finish_parking() -> void:
	_set_heading(PARKED_ANGLE)
	_arrow.visible = false
	_show_remaining(_capacity)
	is_parked = true
	parked.emit()


func _follow_path(distance: float) -> void:
	position = _path.sample_baked(distance)
	var ahead: Vector3 = _path.sample_baked(minf(distance + HEADING_LOOK_AHEAD, _path.get_baked_length()))
	var direction: Vector3 = ahead - position
	if direction.length_squared() > 0.0:
		_set_heading(atan2(-direction.z, direction.x))


## Le pictogramme garde le même sens que sur les pancartes, quel que soit le cap.
func _set_heading(angle: float) -> void:
	rotation.y = angle
	_picto.rotation.y = -angle
	if _roof.visible:
		_roof.visible = false
		_arrow.visible = true
		_picto.visible = true


func _show_roof(dest: String, palette: ViewPalette) -> void:
	_roof.mesh = palette.roof_mesh(dest, _arrow.position, _picto.position, PICTO_RADIUS, rotation.y)
	_roof.visible = true
	_arrow.visible = false
	_picto.visible = false


func _restore_material() -> void:
	_body.material_override = _dest_material


func _show_dest(dest: String, palette: ViewPalette) -> void:
	_dest_material = palette.dest_material(dest)
	if _body.material_override != _highlight_material:
		_body.material_override = _dest_material
	_picto.mesh = palette.picto_mesh(dest)
	if _roof.visible:
		_show_roof(dest, palette)


## Passagers manquants avant le départ, sous le véhicule garé.
func _show_remaining(remaining: int) -> void:
	if _count_label == null:
		_count_label = Label3D.new()
		_count_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_count_label.no_depth_test = true
		_count_label.pixel_size = COUNT_LABEL_PIXEL_SIZE
		_count_label.font_size = COUNT_LABEL_FONT_SIZE
		_count_label.outline_size = COUNT_LABEL_OUTLINE
		_count_label.position = Vector3(-_length * 0.5 - COUNT_LABEL_GAP, PARKED_LABEL_Y, 0.0)
		add_child(_count_label)
	_count_label.text = str(remaining)
