## Точка карты забега: бой, минибосс, магазин, босс или вход в кухню.
##
## Точки связаны рёбрами снизу вверх ([member children] / [member parents]):
## игрок стартует внизу, поднимается по выбранной линии и заканчивает забег
## боссом наверху. Карту строит [ActMap], рисует и даёт кликать `gm_map.gd`.
##
## На карте точка — кружок с буквой ([method letter]): S — магазин,
## M — минибосс, B — босс; обычный враг рисуется пустым кружком.
class_name MapNode
extends RefCounted

enum Kind {
	## Вход в кухню — нижняя точка карты, с неё расходятся линии.
	START,
	## Обычный бой.
	ENEMY,
	## Минибосс: на каждой линии их всегда два.
	MINIBOSS,
	## Магазин.
	SHOP,
	## Босс в самом конце забега.
	BOSS,
}

## Буква в кружке. Обычный враг и старт рисуются без буквы.
const LETTERS := {
	Kind.START: "",
	Kind.ENEMY: "",
	Kind.MINIBOSS: "M",
	Kind.SHOP: "S",
	Kind.BOSS: "B",
}

var kind: Kind = Kind.ENEMY

## Кого драться в этой точке; null у магазина и старта.
var enemy: EnemyModel = null

## Номер линии (0 — левая, 1 — правая); -1 у общих точек:
## старта, магазина перед боссом и самого босса.
var branch := -1

## Порядковый номер точки на своей линии, снизу вверх (с 0).
var index := 0

## Высота точки на карте: 0 — низ (старт), 1 — верх (босс).
## В пиксели переводит `gm_map.gd` по размеру экрана.
var row_frac := 0.0

## Смещение точки от центра карты в колонках: -1 — левая линия,
## +1 — правая, 0 — общие точки.
var column := 0.0

## Ручной «дрожащий» сдвиг кружка, -1..1 по каждой оси: карта нарисована
## от руки, поэтому точки не выстроены по линейке. Множитель — в [MapStyle].
var wobble := Vector2.ZERO

## Рёбра графа. Дети всегда выше родителей.
var children: Array[MapNode] = []
var parents: Array[MapNode] = []

## Точка пройдена: бой выигран или магазин остался позади. Магазин
## помечается пройденным не когда игрок из него вышел, а когда шагнул
## дальше: пока он стоит на магазине, туда можно вернуться.
var cleared := false

## Витрина этого магазина: собирается при первом заходе и дальше живёт
## здесь до конца забега — вернувшись, игрок застаёт тот же товар, а
## купленное уже продано. null у боёв и у магазина, куда ещё не заходили.
var shop: ShopInventory = null


## Буква в кружке; пустая строка — кружок без буквы.
func letter() -> String:
	var text: String = LETTERS[kind]
	return text


## Ведёт ли точка в бой (а не в магазин).
func is_combat() -> bool:
	return kind == Kind.ENEMY or kind == Kind.MINIBOSS or kind == Kind.BOSS


## Можно ли зайти сюда ещё раз, стоя на этой же точке: в магазин — да,
## пока игрок не ушёл с него дальше (витрина та же, товар тот же).
func is_revisitable() -> bool:
	return kind == Kind.SHOP and not cleared


## Подпись точки для подсказки на карте.
func title() -> String:
	if enemy != null and enemy.display_name != "":
		return enemy.display_name
	match kind:
		Kind.SHOP:
			return "Shop"
		Kind.START:
			return "Kitchen door"
		Kind.BOSS:
			return "Boss"
	return "Cook"


## Связать точку с точкой рядом выше (ребро графа).
func link(child: MapNode) -> void:
	if child == null or child == self or children.has(child):
		return
	children.append(child)
	child.parents.append(self)
