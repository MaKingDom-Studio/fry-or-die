## Корзина: ингредиенты, которые выпадут на следующий ход.
##
## Наполняется случайной выборкой из мешочка ([IngredientBag]) — игрок всегда
## видит, что упадёт в зону высыпания в следующем раунде. В начале раунда
## содержимое забирается через [method take_all] и корзина наполняется заново.
## Эффекты «+N ингредиентов на следующий ход» досыпают через [method add_from] —
## прибавка сразу видна в корзине.
class_name Basket
extends RefCounted

signal changed

var _contents: Array[IngredientModel] = []


## Заново наполнить корзину выборкой из мешочка.
func refill(bag: IngredientBag, count: int) -> void:
	_contents = bag.sample(count)
	changed.emit()


## Досыпать в корзину ещё count ингредиентов из мешочка (эффекты ингредиентов).
func add_from(bag: IngredientBag, count: int) -> void:
	if count <= 0:
		return
	_contents.append_array(bag.sample(count))
	changed.emit()


## Забрать всё содержимое (корзина опустеет).
func take_all() -> Array[IngredientModel]:
	var taken: Array[IngredientModel] = _contents.duplicate()
	_contents.clear()
	changed.emit()
	return taken


## Посмотреть содержимое, не забирая его (для UI-предпросмотра).
func peek() -> Array[IngredientModel]:
	return _contents.duplicate()


func size() -> int:
	return _contents.size()


func is_empty() -> bool:
	return _contents.is_empty()


func clear() -> void:
	if _contents.is_empty():
		return
	_contents.clear()
	changed.emit()
