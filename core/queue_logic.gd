class_name QueueLogic
extends RefCounted
## File de passagers en blocs {destination, nombre}. Seule la tête embarque.

var _blocks: Array[QueueBlock] = []
var _head_index: int = 0
var _head_remaining: int = 0


func _init(blocks: Array[QueueBlock]) -> void:
	_blocks = blocks
	if not _blocks.is_empty():
		_head_remaining = _blocks[0].count


func is_empty() -> bool:
	return _head_index >= _blocks.size()


func head_dest() -> String:
	return "" if is_empty() else _blocks[_head_index].dest


func head_remaining() -> int:
	return _head_remaining


## Retire jusqu'à `amount` passagers du bloc de tête et renvoie le nombre retiré.
func take(amount: int) -> int:
	var taken: int = mini(amount, _head_remaining)
	_head_remaining -= taken
	if _head_remaining == 0 and not is_empty():
		_head_index += 1
		_head_remaining = 0 if is_empty() else _blocks[_head_index].count
	return taken


func total_remaining() -> int:
	var total: int = _head_remaining
	for index: int in range(_head_index + 1, _blocks.size()):
		total += _blocks[index].count
	return total
