@tool
## Таймер раунда целиком — и он же кнопка «Обратный отсчёт».
##
## Узел Timer — общий родитель всех частей секундомера: подложки и рамки
## (обычные Sprite2D), круга ([HudTimerRing]), цифр ([HudTimerDigits]) и
## кнопок-лепестков ([HudTimerButton]). Каждая часть по-прежнему
## настраивается сама по себе и двигается мышью внутри таймера, а размер
## и место **всего** таймера — это позиция и масштаб этого узла в
## редакторе: дети едут за ним.
##
## Отдельной кнопки «Обратный отсчёт» больше нет — её роль играет сам
## таймер. Почти всё время это обычный секундомер с цифрами; в фазе READY
## (все ингредиенты на столе) он становится активной кнопкой: весь таймер
## пульсирует ([member pulse_scale], [member pulse_tint]), а цифры
## сменяются надписью «Count / Down» — её рисуют сами цифры, см.
## [member HudTimerDigits.active_text]. По клику режим боя пускает отсчёт
## «3 2 1» и раунд стартует. Клики раздаёт [CombatHud] через
## [method get_global_rect] и [method is_active] — как и у прочих кнопок
## HUD; кликабельная область задаётся [member hit_size] и в 2D-виде видна
## рамкой.
class_name HudTimer
extends Node2D

@export_group("Кликабельная область")
## Размер области, по которой ловится клик, px (до масштаба узла).
@export var hit_size := Vector2(170.0, 190.0):
	set(value):
		hit_size = value.max(Vector2.ONE)
		queue_redraw()

## Сдвиг области от начала узла, px.
@export var hit_offset := Vector2.ZERO:
	set(value):
		hit_offset = value
		queue_redraw()

@export_group("Пульсация активной кнопки")
## Насколько таймер раздувается на пике пульса (0.1 — на 10%).
@export_range(0.0, 1.0) var pulse_scale := 0.07:
	set(value):
		pulse_scale = clampf(value, 0.0, 1.0)

## Как быстро идёт пульсация (радиан в секунду).
@export var pulse_speed := 3.4:
	set(value):
		pulse_speed = maxf(value, 0.0)

## Свечение таймера на пике пульса (белый — не ярче).
@export var pulse_tint := Color(1.3, 1.2, 1.0)

## За сколько секунд пульс разгорается и гаснет: таймер не дёргается
## в тот кадр, когда кнопка загорелась или погасла.
@export var fade_time := 0.18:
	set(value):
		fade_time = maxf(value, 0.01)

@export_group("Редактор")
## Показывать рамку кликабельной области в 2D-виде (в игре не рисуется).
@export var editor_show_hit_area := true:
	set(value):
		editor_show_hit_area = value
		queue_redraw()

@export var editor_hit_color := Color(0.42, 0.85, 1.0, 0.6):
	set(value):
		editor_hit_color = value
		queue_redraw()

## Режим боя (gm_combat). Без типа, чтобы не плодить циклическую зависимость.
var gm = null

## Масштаб и цвет из сцены: пульс идёт от них, а не от единицы, —
## настройки узла в редакторе он не затирает.
var _base_scale := Vector2.ONE
var _base_modulate := Color.WHITE
## Насколько сейчас раздут таймер: 1 — обычный размер.
var _swell := 1.0
## Сила пульса: 0 — кнопка не активна, 1 — пульсирует в полную.
var _amount := 0.0
var _time := 0.0


## Режим боя приходит от [CombatHud] и раздаётся частям таймера: они
## лежат внутри узла, а HUD зовёт attach только у своих прямых детей.
func attach(game_mode) -> void:
	gm = game_mode
	for child in get_children():
		if child.has_method("attach"):
			child.attach(game_mode)


func _ready() -> void:
	_base_scale = scale
	_base_modulate = modulate


## Таймер сейчас — активная кнопка: все ингредиенты на столе, ждём старт
## (фаза READY). Только в это время он пульсирует, пишет «Count Down»
## и ловит клики.
func is_active() -> bool:
	return gm != null and gm.phase == gm.Phase.READY


## Кликабельная область в экранных координатах (центр — на позиции узла).
## Пульсация её не трогает — кнопка не должна «убегать» из-под курсора.
func get_global_rect() -> Rect2:
	var factor := global_scale.abs() / maxf(_swell, 0.01)
	var size := hit_size * factor
	return Rect2(global_position + (hit_offset * factor) - size / 2.0, size)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()
		return
	_time += delta
	_amount = move_toward(_amount, 1.0 if is_active() else 0.0, delta / fade_time)
	# Пульс не включается и не гаснет рывком: сила волны нарастает и
	# спадает за fade_time, поэтому таймер плавно оживает и замирает.
	var wave := (0.5 + 0.5 * sin(_time * pulse_speed)) * _amount
	_swell = 1.0 + pulse_scale * wave
	scale = _base_scale * _swell
	modulate = _base_modulate.lerp(_base_modulate * pulse_tint, wave)


func _draw() -> void:
	# В игре узел ничего не рисует сам: таймер — это его дети. Рамка нужна
	# только в редакторе, чтобы подобрать кликабельную область.
	if not Engine.is_editor_hint() or not editor_show_hit_area:
		return
	draw_rect(Rect2(hit_offset - hit_size / 2.0, hit_size), editor_hit_color, false, 2.0)
