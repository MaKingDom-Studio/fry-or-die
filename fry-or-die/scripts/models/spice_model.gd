## Специя — аналог реликвии: постоянный пассивный бонус,
## который срабатывает всегда, пока специя есть у игрока.
##
## Конкретные специи — наследники этого ресурса (scripts/models/spices/)
## с переопределёнными хуками.
class_name SpiceModel
extends Resource

@export var id: StringName
@export var display_name := ""
@export_multiline var description := ""
@export var texture: Texture2D
## Цвет специи, пока нет изображения (фигура-фолбэк на полке специй).
@export var color := Color.WHITE
## Радиус фигуры и половина длинной стороны бокса изображения на полке
## специй ([SpiceShelf]); коллизия захвата строится по непрозрачным
## пикселям PNG.
@export var radius := 40.0
## Визуальный размер специи на полке: множитель к [member radius]
## (1 — как есть). Масштабирует и картинку, и область захвата вместе, чтобы
## схватывание совпадало с видимым размером и бутылочка ровно стояла на дне.
@export var visual_scale := 1.0
## Порядок отрисовки на полке специй: кто рисуется поверх других. По
## задумке 10 — позади всех специй, 20 — впереди всех. К значению
## прибавляется база слоя полки ([member SpiceShelf.z_base]), чтобы вынести
## специи на передний план сцены.
@export var z_order := 15

@export_group("Магазин")
## Цена в магазине, в звёздах.
@export var price := 10
## Вес выпадения на витрине магазина: чем больше, тем чаще появляется.
## Для специй, которые уже есть у игрока, вес дополнительно понижается
## ([member ShopConfig.owned_spice_weight_multiplier]).
@export var shop_weight := 1.0


## Вызывается один раз при получении специи игроком.
func on_obtained(_player: Player) -> void:
	pass


## Вызывается один раз, если специю у игрока забрали.
func on_removed(_player: Player) -> void:
	pass


## Вызывается в начале каждого раунда, пока специя у игрока.
func on_round_start(_player: Player) -> void:
	pass


## Вызывается в конце каждого раунда, пока специя у игрока.
func on_round_end(_player: Player) -> void:
	pass


## Хуки-модификаторы. Действуют постоянно, пока специя у игрока.

## Размер корзины (сколько ингредиентов выпадет в следующем раунде).
func modify_basket_size(_player: Player, size: int) -> int:
	return size


## Очки одного ингредиента при подсчёте.
## on_player_field — считается ли сейчас поле игрока (иначе — поле врага).
func modify_ingredient_points(_player: Player, _ingredient: IngredientModel,
		points: float, _on_player_field: bool) -> float:
	return points


## Длительность таймера раунда (в секундах).
func modify_timer_duration(_player: Player, seconds: float) -> float:
	return seconds


## Сколько звёзд врагу нужно набрать, чтобы игрок проиграл
## (база — [member CombatConfig.player_star_target]).
func modify_defeat_star_target(_player: Player, target: int) -> int:
	return target


## Сила притяжения полезных ингредиентов (множитель больше 0) к полю
## игрока (px/s^2). 0 — специя не тянет, и остальные настройки притяжения
## режим боя даже не спрашивает.
func get_useful_attraction() -> float:
	return 0.0


## Кого тянет: ингредиенты с множителем больше этого числа
## (0 — всё полезное).
func get_attraction_min_multiplier() -> float:
	return 0.0


## До какой скорости притяжение разгоняет ингредиент, px/s; дальше он катится
## сам. 0 — без предела.
func get_attraction_max_speed() -> float:
	return 0.0


## Отпускать ли ингредиент, когда он уже на поле игрока.
func get_attraction_stops_on_field() -> bool:
	return true


## Тянуть только в раунде (фаза PLAY), а не на высыпании и подсчёте.
func get_attraction_only_in_round() -> bool:
	return true
