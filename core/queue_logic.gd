class_name QueueLogic
extends RefCounted
## File de passagers en blocs {destination, nombre}. Seule la tête embarque.
## Travaille sur sa propre copie : le LevelData reste immuable.

var _blocks: Array[QueueBlock] = []


func _init(source: Array[QueueBlock]) -> void:
	_blocks = _merged_copy(source)


func copy() -> QueueLogic:
	return QueueLogic.new(_blocks)


func is_empty() -> bool:
	return _blocks.is_empty()


func head_dest() -> String:
	return "" if is_empty() else _blocks[0].dest


func head_remaining() -> int:
	return 0 if is_empty() else _blocks[0].count


## Retire jusqu'à `amount` passagers du bloc de tête et renvoie le nombre retiré.
func take(amount: int) -> int:
	if is_empty():
		return 0
	var taken: int = mini(amount, _blocks[0].count)
	_blocks[0].count -= taken
	if _blocks[0].count == 0:
		_blocks.pop_front()
	return taken


func total_remaining() -> int:
	var total: int = 0
	for block: QueueBlock in _blocks:
		total += block.count
	return total


## Copie des blocs restants, tête d'abord.
func blocks() -> Array[QueueBlock]:
	return _merged_copy(_blocks)


func state_key() -> String:
	var key: String = ""
	for block: QueueBlock in _blocks:
		key += "%s:%d," % [block.dest, block.count]
	return key


## Vrai si remonter ces besoins changerait l'ordre de la file.
func would_reorder(needs: Array[QueueBlock]) -> bool:
	return not _same_blocks(_blocks, _prioritized(needs))


## Remonte en tête, dans l'ordre des besoins, les passagers demandés ; tri stable.
## Une destination à court remonte ce qu'il lui reste.
func prioritize(needs: Array[QueueBlock]) -> void:
	_blocks = _prioritized(needs)


func _prioritized(needs: Array[QueueBlock]) -> Array[QueueBlock]:
	var rest: Array[QueueBlock] = _merged_copy(_blocks)
	var front: Array[QueueBlock] = []
	for need: QueueBlock in needs:
		_pull(need, rest, front)
	for block: QueueBlock in rest:
		_append_merged(front, block.dest, block.count)
	return front


func _pull(need: QueueBlock, rest: Array[QueueBlock], front: Array[QueueBlock]) -> void:
	var left: int = need.count
	for block: QueueBlock in rest:
		if left == 0:
			return
		if block.dest == need.dest:
			var moved: int = mini(left, block.count)
			block.count -= moved
			left -= moved
			_append_merged(front, block.dest, moved)


static func _merged_copy(source: Array[QueueBlock]) -> Array[QueueBlock]:
	var merged: Array[QueueBlock] = []
	for block: QueueBlock in source:
		_append_merged(merged, block.dest, block.count)
	return merged


static func _append_merged(target: Array[QueueBlock], dest: String, count: int) -> void:
	if count == 0:
		return
	if not target.is_empty() and target[-1].dest == dest:
		target[-1].count += count
	else:
		target.append(QueueBlock.new(dest, count))


static func _same_blocks(a: Array[QueueBlock], b: Array[QueueBlock]) -> bool:
	if a.size() != b.size():
		return false
	for index: int in a.size():
		if a[index].dest != b[index].dest or a[index].count != b[index].count:
			return false
	return true
