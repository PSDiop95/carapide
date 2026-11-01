class_name QueueView
extends Node3D
## File en cubes : un MultiMesh par destination, soit 1 draw call par couleur.

const CUBE_SIZE: float = 0.38
const CUBE_HEIGHT_OFFSET: float = 0.19

var _layout: LevelLayout
## Destination de chaque passager, dans l'ordre de la file.
var _passengers: PackedStringArray = PackedStringArray()
var _head: int = 0
var _meshes: Dictionary[String, MultiMesh] = {}


func setup(level: LevelData, layout: LevelLayout, palette: ViewPalette) -> void:
	_layout = layout
	var cube: BoxMesh = BoxMesh.new()
	cube.size = Vector3.ONE * CUBE_SIZE
	for block: QueueBlock in level.queue:
		for _index: int in block.count:
			_passengers.append(block.dest)
	var totals: Dictionary[String, int] = level.passengers_by_dest()
	for dest: String in totals:
		_meshes[dest] = _build_multimesh(cube, totals[dest], layout, palette, dest)
	_refresh()


func advance(amount: int) -> void:
	_head = mini(_head + amount, _passengers.size())
	_refresh()


func _build_multimesh(cube: BoxMesh, total: int, layout: LevelLayout, palette: ViewPalette, dest: String) -> MultiMesh:
	var multimesh: MultiMesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = cube
	multimesh.instance_count = mini(total, layout.queue_capacity())
	var instance: MultiMeshInstance3D = MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	instance.material_override = palette.dest_material(dest)
	add_child(instance)
	return multimesh


func _refresh() -> void:
	var used: Dictionary[String, int] = {}
	var visible_count: int = mini(_layout.queue_capacity(), _passengers.size() - _head)
	for rank: int in visible_count:
		var dest: String = _passengers[_head + rank]
		var index: int = used.get(dest, 0)
		var at: Vector3 = _layout.queue_world(rank) + Vector3.UP * CUBE_HEIGHT_OFFSET
		_meshes[dest].set_instance_transform(index, Transform3D(Basis.IDENTITY, at))
		used[dest] = index + 1
	for dest: String in _meshes:
		var count: int = used.get(dest, 0)
		_meshes[dest].visible_instance_count = count
