## Ингредиент — аналог карты.
##
## У каждого ингредиента три боевых параметра: вес (то самое значение,
## отвечающее за звёзды), множитель и уникальный эффект срабатывания.
## Очки при подсчёте = вес * множитель; множитель определяет и категорию
## подсчёта: отрицательные (< 0), нейтральные (0..1), положительные (> 1).
## Порядок подсчёта раунда — в gm_combat: нейтральные, положительные,
## уникальные эффекты, отрицательные.
class_name IngredientModel
extends Resource

enum Effect {
	## Без эффекта.
	NONE,
	## На следующий ход в корзине на effect_amount ингредиентов больше.
	EXTRA_INGREDIENTS,
	## Таймер следующего раунда длиннее на effect_amount секунд.
	EXTRA_TIME,
	## Липкий (горох): после клика мышью прилипает к первой же стене стола,
	## а прилипнув — приклеивает к себе всё, что его коснётся. Работает на
	## столе во время раунда, отдельного шага подсчёта не занимает.
	STICKY,
	## Обесцвечивание (водка): осталась на поле игрока к подсчёту — весь
	## следующий раунд игрок проводит в чёрно-белом ([GrayscaleOverlay]).
	## На поле врага и в зоне высыпания не работает.
	GRAYSCALE,
}

## Эффекты, которые работают на столе во время раунда, а не отдельным шагом
## подсчёта (см. [method has_scoring_effect]).
const FIELD_EFFECTS := [Effect.STICKY]

enum ShapeKind { CIRCLE, SQUARE }

enum Category { NEGATIVE, NEUTRAL, POSITIVE }

## Размерная категория ингредиента (маленький / средний / большой).
enum Size { SMALL, MEDIUM, LARGE }

@export var id: StringName
@export var display_name := ""
## Размерная категория. Отдельно от физического [member radius] — это игровой
## класс для будущих механик; на подсчёт очков напрямую не влияет.
@export var size: Size = Size.MEDIUM
## Изображение; если не задано, рисуется фигура [member shape] цвета [member color].
@export var texture: Texture2D

@export_group("Подсчёт")
## Вес: сколько очков ингредиент приносит в звёзды при подсчёте.
@export var weight := 1
## Множитель веса. Меньше 0 — вредный ингредиент, 0..1 — нейтральный,
## больше 1 (от 1.01) — положительный. Схема ингредиентов:
## 2 — положительный, 1 — нейтральный, -1 — отрицательный,
## 0 — ничего не делает (0 очков).
@export var multiplier := 1.0

@export_group("Эффект")
@export var effect: Effect = Effect.NONE
@export var effect_amount := 0

@export_group("Магазин")
## Цена в магазине, в звёздах.
@export var price := 5
## Вес выпадения на витрине магазина: чем больше, тем чаще появляется.
## 0 — в магазине не появляется.
@export var shop_weight := 1.0

@export_group("Поведение")
## Нельзя двигать и выбивать: после приземления застывает на месте.
@export var locked := false
## Вечный: остаётся на поле между раундами, убирается только горелкой.
## Подразумевает locked.
@export var permanent := false
## Устарело: размещение врага теперь задаётся у группы хода
## ([member EnemySpawnGroup.placement]), а не у самого ингредиента.
## Поле оставлено для совместимости со старыми ресурсами и не читается боем.
@export var drops_on_player_side := false

@export_group("Вид")
## Текстура тени; если не задана, тень — силуэт самого объекта
## (затемнённое изображение или фигура той же формы).
@export var shadow_texture: Texture2D
## Строить коллизию по непрозрачным пикселям изображения (по альфе PNG).
## Выключено или изображения нет — коллизия по фигуре [member shape].
@export var texture_collision := true
## Продукты без изображения — квадраты (и форма коллизии).
@export var shape: ShapeKind = ShapeKind.SQUARE
@export var color := Color.WHITE
## Радиус фигуры и половина стороны бокса изображения (коллизия совпадает).
@export var radius := 20.0


## Мягкий ингредиент: множитель больше 0 и меньше 2 — не вредный, не пустой
## и не «сильный положительный». Из таких набирается стартовый инвентарь
## ([method Player.create_for_new_run]): забег начинается с ровных
## ингредиентов, а всё сильное игрок добирает наградами и покупками.
func is_mild() -> bool:
	return multiplier > 0.0 and multiplier < 2.0


## Категория подсчёта по множителю.
func category() -> Category:
	if multiplier < 0.0:
		return Category.NEGATIVE
	if multiplier > 1.0:
		return Category.POSITIVE
	return Category.NEUTRAL


## Базовые очки без учёта специй.
func base_points() -> float:
	return weight * multiplier


func is_movable() -> bool:
	return not locked and not permanent


## Срабатывает ли эффект отдельным шагом подсчёта. Полевые эффекты
## ([constant FIELD_EFFECTS]) отрабатывают на столе сами и шага не занимают.
func has_scoring_effect() -> bool:
	return effect != Effect.NONE and not FIELD_EFFECTS.has(effect)


## Липкий ли ингредиент ([constant Effect.STICKY]).
func is_sticky() -> bool:
	return effect == Effect.STICKY
