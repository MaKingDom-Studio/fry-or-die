@tool
## Обратный отсчёт на весь экран: «3 2 1» перед началом раунда.
##
## Кнопка «Обратный отсчёт» — сам таймер ([HudTimer]) — запускает раунд не
## сразу: сначала экран затемняется и по центру одна за другой показываются
## цифры (по умолчанию 3 → 1 за 1.5 с, см. [member step_duration]), и только
## после этого кнопка «срабатывает» — режим боя пускает таймер и разрешает
## двигать ингредиенты. Пока идёт отсчёт, режим боя держит фазу COUNTDOWN.
##
## Узел ставится под Hud последним — тогда затемнение и цифры рисуются
## поверх остальных виджетов. Затемнение растягивается на весь вьюпорт,
## где бы ни стоял узел; цифры центрируются по началу узла (обычно центр
## экрана). Отсчёт запускает [method run] — его ждёт [CombatHud].
class_name HudStartCountdown
extends Node2D

## Сколько цифр показать: 3 — «3 2 1».
@export_range(1, 9, 1) var count_from := 3

## Сколько секунд висит каждая цифра. Весь отсчёт длится
## count_from * step_duration (по умолчанию 3 * 0.5 = 1.5 с).
@export_range(0.05, 3.0, 0.05, "or_greater") var step_duration := 0.5

@export_group("Затемнение")
## Заливка поверх всего экрана, пока идёт отсчёт (в редакторе не рисуется,
## чтобы не мешать вёрстке).
@export var dim := Color(0.0, 0.0, 0.0, 0.62)

@export_group("Цифры")
## Шрифт цифр. Пусто — шрифт проекта (Grunge Bold V2, см. [UiFont]).
@export var font: Font

@export_range(20, 600, 1, "or_greater") var font_size := 220

@export var color := Color(0.98, 0.95, 0.88)

## Тёмная обводка — цифра читается на любом фоне стола.
@export var outline_size := 12

@export var outline_color := Color(0.1, 0.07, 0.05, 0.85)

## Цифра появляется крупнее и к концу своего шага сжимается: масштаб
## идёт от [member start_scale] к [member end_scale].
@export var start_scale := 1.35

@export var end_scale := 0.95

## Насколько цифра растворяется к концу шага: 0 — не гаснет вовсе,
## 1 — до полной прозрачности.
@export_range(0.0, 1.0) var fade_out := 0.55

@export_group("Редактор")
## Превью в редакторе: какую цифру рисовать (0 — не рисовать ничего).
@export var editor_preview_digit := 3

## Текущая цифра отсчёта; 0 — отсчёта нет.
var _digit := 0
## Сколько осталось от шага текущей цифры, с.
var _step_left := 0.0


## Проиграть отсчёт до конца. Вызывающий его ждёт: когда [method run]
## вернулся — можно запускать таймер раунда.
func run() -> void:
	for value in range(count_from, 0, -1):
		_digit = value
		_step_left = step_duration
		await get_tree().create_timer(step_duration).timeout
	_digit = 0
	_step_left = 0.0
	queue_redraw()


## Идёт ли отсчёт: на это время HUD не пропускает клики к столу.
func is_running() -> bool:
	return _digit > 0


func _process(delta: float) -> void:
	if _step_left > 0.0:
		_step_left = maxf(_step_left - delta, 0.0)
	queue_redraw()


func _draw() -> void:
	var editor := Engine.is_editor_hint()
	var digit := editor_preview_digit if editor else _digit
	if digit <= 0:
		return
	# Доля прошедшего шага 0..1 — по ней идут масштаб и растворение цифры.
	var t := 0.0
	if not editor and step_duration > 0.0:
		t = clampf(1.0 - _step_left / step_duration, 0.0, 1.0)
	if not editor:
		draw_rect(_viewport_local_rect(), dim)
	var text := str(digit)
	var text_font := UiFont.resolve(font)
	var size := maxi(int(round(font_size * lerpf(start_scale, end_scale, t))), 1)
	var alpha := 1.0 - fade_out * t * t
	# Цифра центрируется по началу узла: по ширине — половиной строки,
	# по высоте — серединой между верхом и низом букв.
	var width := text_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var baseline := (text_font.get_ascent(size) - text_font.get_descent(size)) / 2.0
	var at := Vector2(-width / 2.0, baseline)
	if outline_size > 0:
		draw_string_outline(text_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size,
				outline_size, Color(outline_color, outline_color.a * alpha))
	draw_string(text_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size,
			Color(color, color.a * alpha))


## Прямоугольник вьюпорта в координатах узла — затемнение кроет весь экран
## независимо от того, где стоит узел.
func _viewport_local_rect() -> Rect2:
	var view := get_viewport_rect().size
	var top_left := to_local(Vector2.ZERO)
	return Rect2(top_left, to_local(view) - top_left)
