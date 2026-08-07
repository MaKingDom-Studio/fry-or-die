## Мешочек со всеми ингредиентами игрока в бою.
##
## Заменяет стопки добора и сброса: ничего не тратится и не сбрасывается —
## мешочек всегда содержит все ингредиенты, и каждый ход из него случайной
## выборкой наполняется корзина ([Basket]).
class_name IngredientBag
extends RefCounted

signal changed

var _ingredients: Array[IngredientModel] = []
var _rng: RandomNumberGenerator

func _init(rng: RandomNumberGenerator = null) -> void:
	_rng = rng if rng != null else RandomNumberGenerator.new()

## Наполнить мешочек копией списка (сами ингредиенты не клонируются).
func fill_from(source: Array[IngredientModel]) -> void:
	_ingredients = source.duplicate()
	changed.emit()

func add(ingredient: IngredientModel) -> void:
	_ingredients.append(ingredient)
	changed.emit()

func remove(ingredient: IngredientModel) -> bool:
	if not _ingredients.has(ingredient):
		return false
	_ingredients.erase(ingredient)
	changed.emit()
	return true

func size() -> int:
	return _ingredients.size()

func is_empty() -> bool:
	return _ingredients.is_empty()

## Копия содержимого мешочка (для UI).
func get_all() -> Array[IngredientModel]:
	return _ingredients.duplicate()

## Случайная выборка [param count] ингредиентов без повторов.
## Сам мешочек при этом не пустеет. Если ингредиентов меньше, чем [param count],
## вернутся все, что есть.
func sample(count: int) -> Array[IngredientModel]:
	var pool := _ingredients.duplicate()
	var result: Array[IngredientModel] = []
	var take := mini(count, pool.size())
	for _i in take:
		var index := _rng.randi_range(0, pool.size() - 1)
		result.append(pool[index])
		pool.remove_at(index)
	return result
