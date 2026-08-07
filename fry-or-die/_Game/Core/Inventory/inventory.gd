class_name SquareInventory
extends RefCounted

## Runtime-инвентарь кубов: стеки "тип + количество".
## Заполняется из InventoryConfig при старте; во время игры пополняется
## через add() — подписчики items_added реагируют (например, спавнят кубы).

signal items_added

var _defs: Array[SquareDef] = []
var _counts: Array[int] = []


func setup(config: InventoryConfig) -> void:
	_defs.clear()
	_counts.clear()
	if config == null:
		return
	for entry in config.entries:
		if entry == null or entry.def == null or entry.count <= 0:
			continue
		add(entry.def, entry.count)


## Пополнение инвентаря (в том числе во время игры).
func add(def: SquareDef, count := 1) -> void:
	if def == null or count <= 0:
		return
	var idx := _defs.find(def)
	if idx >= 0:
		_counts[idx] += count
	else:
		_defs.append(def)
		_counts.append(count)
	items_added.emit()


## Достать случайный куб (взвешенно по количеству). null, если инвентарь пуст.
func take_random() -> SquareDef:
	var total := total_count()
	if total <= 0:
		return null
	var pick := randi_range(0, total - 1)
	for i in _defs.size():
		if pick < _counts[i]:
			var def := _defs[i]
			_counts[i] -= 1
			if _counts[i] <= 0:
				_defs.remove_at(i)
				_counts.remove_at(i)
			return def
		pick -= _counts[i]
	return null


func total_count() -> int:
	var total := 0
	for count in _counts:
		total += count
	return total


func is_empty() -> bool:
	return total_count() == 0
