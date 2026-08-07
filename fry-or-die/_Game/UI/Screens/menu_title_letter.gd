## Буква названия игры в главном меню: картинка, которая всё время мелко
## дребезжит на месте.
##
## Каждая буква названия — свой узел со своей картинкой
## (`_Game/Art/Main_Menu/Name_*.png`), поэтому дребезжат они врозь: сдвиг,
## наклон и размер считаются от суммы двух синусоид разной частоты — выходит
## не ровное качание, а мелкая тряска. Разводит буквы [member phase]: пока
## она нулевая, фаза берётся из имени узла, так что одинаково дрожать
## соседние буквы не будут и без настройки.
##
## Исходное положение узла запоминается на старте — в редакторе букву
## по-прежнему двигают мышью, дребезг живёт только в игре.
class_name MenuTitleLetter
extends Sprite2D

@export_group("Дребезг")
## На сколько градусов буква отклоняется в обе стороны.
@export var jitter_angle_deg := 1.4
## На сколько пикселей буква ходит по осям, в координатах макета.
@export var jitter_offset := Vector2(4.0, 4.0)
## Насколько буква раздувается и сжимается: 0.01 — на 1%.
@export var jitter_scale := 0.008
## Скорость дребезга: во сколько раз быстрее одного колебания в секунду.
@export_range(0.1, 30.0, 0.1, "or_greater") var jitter_speed := 7.0
## Сдвиг фазы, рад: у каждой буквы свой. 0 — взять из имени узла.
@export var phase := 0.0

var _base_position := Vector2.ZERO
var _base_rotation := 0.0
var _base_scale := Vector2.ONE
var _phase := 0.0
var _time := 0.0


func _ready() -> void:
	_base_position = position
	_base_rotation = rotation
	_base_scale = scale
	# Фаза из имени узла: буквы разводятся сами, без настройки в сцене.
	_phase = phase if not is_zero_approx(phase) \
			else float(absi(name.hash()) % 1000) / 1000.0 * TAU


func _process(delta: float) -> void:
	_time += delta * jitter_speed
	position = _base_position + Vector2(
			jitter_offset.x * _wave(_time, _phase),
			jitter_offset.y * _wave(_time * 1.31, _phase + 2.1))
	rotation = _base_rotation \
			+ deg_to_rad(jitter_angle_deg) * _wave(_time * 0.87, _phase + 4.7)
	scale = _base_scale * (1.0 + jitter_scale * _wave(_time * 1.13, _phase + 1.3))


## Дрожь: две синусоиды разной частоты вместо одной ровной волны.
func _wave(t: float, shift: float) -> float:
	return sin(t + shift) * 0.65 + sin(t * 2.37 + shift * 1.7) * 0.35
