class_name VehicleView
extends Node3D
## Véhicule gris : boîte colorée et flèche sur le toit. Rejoue ce qu'on lui demande, sans décider.

const VISUAL_LENGTH_GAP: float = 0.08
const HEIGHT: float = 0.6
const LIFT_WHILE_EXITING: float = 0.5
const DEPART_DISTANCE: float = 20.0
const PARKED_ANGLE: float = PI * 0.5
const LOAD_LABEL_PIXEL_SIZE: float = 0.012
const LOAD_LABEL_FONT_SIZE: int = 64

var _body: MeshInstance3D = MeshInstance3D.new()
var _arrow: MeshInstance3D = MeshInstance3D.new()
var _load_label: Label3D = null
var _capacity: int = 0
var _highlight_material: Material


func setup(vehicle: LevelVehicle, world_position: Vector3, palette: ViewPalette) -> void:
	_capacity = vehicle.capacity
	_highlight_material = palette.highlight_material
	position = world_position
	rotation.y = deg_to_rad(vehicle.angle)
	_body.mesh = palette.body_mesh(vehicle.length, vehicle.width)
	_body.material_override = palette.dest_material(vehicle.dest)
	_body.position.y = HEIGHT * 0.5
	add_child(_body)
	_arrow.mesh = palette.arrow_mesh
	_arrow.material_override = palette.arrow_material
	_arrow.position.y = HEIGHT + 0.01
	add_child(_arrow)


## Sort tout droit jusqu'au bord, puis rejoint la place de gare.
func drive_to_slot(exit_world: Vector3, slot_world: Vector3, duration: float) -> void:
	var half: float = duration * 0.5
	var tween: Tween = create_tween()
	tween.tween_property(self, "position", exit_world + Vector3.UP * LIFT_WHILE_EXITING, half)
	var turn: float = rotation.y + wrapf(PARKED_ANGLE - rotation.y, -PI, PI)
	tween.tween_property(self, "position", slot_world, half)
	tween.parallel().tween_property(self, "rotation:y", turn, half)
	await tween.finished
	_arrow.visible = false
	_show_load(0)


func set_loaded(loaded: int) -> void:
	_show_load(loaded)


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
	var normal: Material = _body.material_override
	if normal == _highlight_material:
		return
	_body.material_override = _highlight_material
	var tween: Tween = create_tween()
	tween.tween_interval(duration)
	tween.tween_callback(_restore_material.bind(normal))


func _restore_material(material: Material) -> void:
	_body.material_override = material


func _show_load(loaded: int) -> void:
	if _load_label == null:
		_load_label = Label3D.new()
		_load_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_load_label.no_depth_test = true
		_load_label.pixel_size = LOAD_LABEL_PIXEL_SIZE
		_load_label.font_size = LOAD_LABEL_FONT_SIZE
		_load_label.position.y = HEIGHT + 0.3
		add_child(_load_label)
	_load_label.text = "%d/%d" % [loaded, _capacity]
