@tool
## Затемнение сцены на время подсчёта: свет уходит, на столе остаются только
## ингредиенты.
##
## Заливка кроет весь вьюпорт, где бы ни стоял узел. Порядок слоёв держится
## z-индексами: у этого узла он выше корзин и полки специй, но ниже арены
## (её режим боя поднимает на время подсчёта, см. `gm_combat`) и HUD —
## поэтому в тень уходят стол, фон, корзины и специи, а ингредиенты и HUD
## (звёзды, таймер) остаются на свету.
##
## Наплывом и уходом управляет режим боя: [method fade_in] перед сжиганием
## врага и подсчётом, [method fade_out] — когда раунд посчитан.
class_name ScoringDim
extends Node2D

## Цвет и максимальная плотность затемнения.
@export var dim := Color(0.0, 0.0, 0.0, 0.66)
## Сколько секунд экран уходит в тень.
@export_range(0.0, 3.0, 0.05, "or_greater") var fade_in_duration := 0.35
## Сколько секунд свет возвращается.
@export_range(0.0, 3.0, 0.05, "or_greater") var fade_out_duration := 0.3

@export_group("Редактор")
## Превью в редакторе: нарисовать затемнение (в игре не влияет).
@export var editor_preview := false

## Текущая плотность 0..1.
var _strength := 0.0
var _target := 0.0
## Скорость изменения плотности, единиц в секунду.
var _speed := 0.0


## Затемнить экран. Вызывающий ждёт конца наплыва.
func fade_in() -> void:
	await _fade_to(1.0, fade_in_duration)


## Вернуть свет. Вызывающий ждёт конца ухода.
func fade_out() -> void:
	await _fade_to(0.0, fade_out_duration)


func is_dimmed() -> bool:
	return _strength > 0.0


func _fade_to(target: float, duration: float) -> void:
	_target = clampf(target, 0.0, 1.0)
	var distance := absf(_target - _strength)
	if duration <= 0.0 or distance <= 0.0:
		_strength = _target
		_speed = 0.0
		queue_redraw()
		return
	# Скорость — на полный переход 0..1, поэтому ждать надо ровно ту часть,
	# которую осталось пройти.
	_speed = 1.0 / duration
	await get_tree().create_timer(distance * duration).timeout


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()
		return
	if is_equal_approx(_strength, _target):
		return
	_strength = move_toward(_strength, _target, _speed * delta)
	queue_redraw()


func _draw() -> void:
	var strength := 1.0 if Engine.is_editor_hint() and editor_preview else _strength
	if strength <= 0.0:
		return
	draw_rect(_viewport_local_rect(), Color(dim, dim.a * strength))


## Прямоугольник вьюпорта в координатах узла — затемнение кроет весь экран
## независимо от того, где стоит узел.
func _viewport_local_rect() -> Rect2:
	var view := get_viewport_rect().size
	var top_left := to_local(Vector2.ZERO)
	return Rect2(top_left, to_local(view) - top_left)
