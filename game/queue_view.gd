class_name QueueView
extends Node3D
## File en cubes : un MultiMesh par destination, soit 1 draw call par couleur.
## Un pictogramme flotte au-dessus du premier cube de chaque bloc visible.

signal blocks_changed(blocks: Array[QueueBlock])

const CUBE_SIZE: float = 0.38
const CUBE_HEIGHT_OFFSET: float = 0.19
const HEAD_MARKER_HEIGHT: float = 0.02
const HEAD_MARKER_SCALE: float = 0.6
const SIGN_HEIGHT: float = 0.5
const SIGN_RADIUS: float = 0.26

var _layout: LevelLayout
var _palette: ViewPalette
var _queue: Array[QueueBlock] = []
## Destination de chaque passager, dans l'ordre de la file.
var _passengers: PackedStringArray = PackedStringArray()
var _head: int = 0
var _meshes: Dictionary[String, MultiMesh] = {}
var _signs: Array[MeshInstance3D] = []


func setup(level: LevelData, layout: LevelLayout, palette: ViewPalette, sign_count: int) -> void:
	_layout = layout
	_palette = palette
	_queue = level.queue
	var cube: BoxMesh = BoxMesh.new()
	cube.size = Vector3.ONE * CUBE_SIZE
	for block: QueueBlock in level.queue:
		for _index: int in block.count:
			_passengers.append(block.dest)
	var totals: Dictionary[String, int] = level.passengers_by_dest()
	for dest: String in totals:
		_meshes[dest] = _build_multimesh(cube, totals[dest], layout, palette, dest)
	for _index: int in sign_count:
		_signs.append(_add_sign())
	_add_head_marker(palette)
	_refresh()


func advance(amount: int) -> void:
	_head = mini(_head + amount, _passengers.size())
	_refresh()


## L'Apprenti a réordonné la file : `blocks` est ce qu'il reste, tête d'abord.
func replace_remaining(blocks: Array[QueueBlock]) -> void:
	_queue = blocks
	_head = 0
	_passengers = PackedStringArray()
	for block: QueueBlock in blocks:
		for _index: int in block.count:
			_passengers.append(block.dest)
	_refresh()


func current_blocks() -> Array[QueueBlock]:
	return QueueDisplay.remaining_blocks(_queue, _head)


## Flèche fixe vers la gare : montre quel passager embarque.
func _add_head_marker(palette: ViewPalette) -> void:
	var marker: MeshInstance3D = MeshInstance3D.new()
	marker.mesh = palette.arrow_mesh
	marker.material_override = palette.arrow_material
	marker.position = _layout.head_marker_world() + Vector3.UP * HEAD_MARKER_HEIGHT
	marker.rotation.y = -PI * 0.5
	marker.scale = Vector3.ONE * HEAD_MARKER_SCALE
	add_child(marker)


func _add_sign() -> MeshInstance3D:
	var board_sign: MeshInstance3D = MeshInstance3D.new()
	board_sign.material_override = _palette.picto_material
	board_sign.scale = Vector3.ONE * SIGN_RADIUS
	board_sign.visible = false
	add_child(board_sign)
	return board_sign


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
	var blocks: Array[QueueBlock] = current_blocks()
	_place_signs(blocks, visible_count)
	blocks_changed.emit(blocks)


func _place_signs(blocks: Array[QueueBlock], visible_count: int) -> void:
	var rank: int = 0
	for index: int in _signs.size():
		var board_sign: MeshInstance3D = _signs[index]
		board_sign.visible = index < blocks.size() and rank < visible_count
		if not board_sign.visible:
			continue
		board_sign.mesh = _palette.picto_mesh(blocks[index].dest)
		board_sign.position = _layout.queue_world(rank) + Vector3.UP * SIGN_HEIGHT
		rank += blocks[index].count
