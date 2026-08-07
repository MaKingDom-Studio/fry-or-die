## Шкала звёзд одной из сторон боя.
##
## Очки накапливаются при подсчёте ингредиентов; каждые
## [member points_per_star] очков заполняют одну звезду. Сторона побеждает,
## когда заполнены все [member target_stars]. Ниже нуля очки не опускаются.
##
## Сверху предела нет: очки могут уйти за [method max_points] — например когда
## поле принесло больше, чем нужно на последнюю звезду. Это важно для порядка
## подсчёта: отрицательные ингредиенты считаются последними, и обрезка по
## пределу съедала бы перебор, из-за которого сторона удержалась бы над целью.
## Поэтому итог смотрят по [method is_complete] уже после всего поля
## (см. `gm_combat._play_round`): перебор минусы отнимают от настоящей суммы,
## и цель считается взятой, если после них очков всё ещё не меньше предела.
## Подпись в HUD считает звёзды дробью — перебор в ней виден («9.75 / 9»),
## а звёзды просто полные.
class_name StarProgress
extends RefCounted

signal points_changed(old_points: float, new_points: float)
signal completed

var points_per_star := 10.0
var target_stars := 5

var _points := 0.0

var points: float:
	get:
		return _points


func _init(per_star: float, target: int) -> void:
	points_per_star = maxf(per_star, 0.001)
	target_stars = maxi(target, 1)


func max_points() -> float:
	return points_per_star * target_stars


## Добавить (или отнять — amount < 0) очки. Верхнего предела нет, ниже нуля
## очки не опускаются.
func add_points(amount: float) -> void:
	var old := _points
	_points = maxf(_points + amount, 0.0)
	if is_equal_approx(old, _points):
		return
	points_changed.emit(old, _points)
	if is_complete():
		completed.emit()


func filled_stars() -> int:
	return int(_points / points_per_star)


## Доля заполнения звезды с индексом star_index (0..1).
func star_fraction(star_index: int) -> float:
	return clampf(_points / points_per_star - star_index, 0.0, 1.0)


func is_complete() -> bool:
	return _points >= max_points() - 0.001
