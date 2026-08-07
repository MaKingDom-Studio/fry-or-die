## Кнопка секундомера: картинка, которая уезжает со своего места, пока
## идёт обратный отсчёт, и возвращается назад, когда таймер вышел.
##
## Скрипт вешается на спрайт кнопки (TimerButton01, TimerButton02 и любые
## другие). Куда именно уезжает кнопка, задаётся в инспекторе
## [member pressed_offset]: (0, -30) — вверх, (-30, 30) — по диагонали в
## левый нижний угол. Исходным положением считается позиция узла в сцене,
## поэтому кнопку можно свободно двигать в редакторе — сдвиг всегда
## отсчитывается от того места, где она стоит.
##
## Момент старта — фаза боя PLAY (нажат таймер, он же кнопка «Обратный
## отсчёт», см. [HudTimer]), момент возврата — её конец (время вышло).
## Режим боя приходит через [method attach] от таймера-родителя, а если
## узел лежит где-то ещё — находится сам по дереву сцены.
class_name HudTimerButton
extends Sprite2D

## Куда уезжает кнопка на время отсчёта, px от исходного положения.
@export var pressed_offset := Vector2(0.0, -30.0)

## За сколько секунд кнопка уезжает после нажатия «Обратного отсчёта».
@export var press_time := 0.18

## За сколько секунд кнопка возвращается, когда таймер вышел.
@export var release_time := 0.3

## Плавный разгон и торможение; выкл — равномерное движение.
@export var smooth := true

## Поворот кнопки в сдвинутом положении, градусы (0 — не поворачивать).
@export_range(-180.0, 180.0) var pressed_rotation := 0.0

## Режим боя (gm_combat). Без типа, чтобы не плодить циклическую зависимость.
var gm = null

## Исходные положение и поворот — из сцены, запоминаются при запуске.
var _base_position := Vector2.ZERO
var _base_rotation := 0.0
## Насколько кнопка сейчас сдвинута: 0 — стоит на месте, 1 — уехала.
var _shift := 0.0


func attach(game_mode) -> void:
	gm = game_mode


func _ready() -> void:
	_base_position = position
	_base_rotation = rotation_degrees
	if gm == null:
		gm = _find_game_mode()


func _process(delta: float) -> void:
	var target := 1.0 if _countdown_running() else 0.0
	# Уезжает и возвращается кнопка с разной скоростью: нажатие резче,
	# возврат мягче.
	var time := press_time if target > _shift else release_time
	_shift = move_toward(_shift, target, delta / maxf(time, 0.01))
	var eased := smoothstep(0.0, 1.0, _shift) if smooth else _shift
	position = _base_position + pressed_offset * eased
	rotation_degrees = _base_rotation + pressed_rotation * eased


## Идёт ли обратный отсчёт: время пошло и ещё не вышло.
func _countdown_running() -> bool:
	return gm != null and gm.phase == gm.Phase.PLAY


## Режим боя выше по дереву — узел кнопки может лежать где угодно
## (например, внутри спрайта секундомера, а не прямым ребёнком HUD).
func _find_game_mode():
	var node := get_parent()
	while node != null:
		if "phase" in node and "time_left" in node:
			return node
		node = node.get_parent()
	return null
