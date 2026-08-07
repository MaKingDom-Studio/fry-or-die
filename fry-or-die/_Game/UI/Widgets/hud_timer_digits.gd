@tool
## Цифры таймера раунда — отдельный узел, независимый от круга
## ([HudTimerRing]).
##
## Показывают, сколько секунд осталось до конца раунда, шрифтом проекта
## (Grunge Bold V2, см. [UiFont]); размер цифр задаётся
## [member font_size] и ни от чего больше не зависит. Другой шрифт можно
## подставить полем [member font].
##
## Цифры центрируются по началу узла, поэтому узел ставится туда, где
## должен быть центр числа: круг таймера двигается сам по себе.
##
## Пока таймер — активная кнопка «Обратный отсчёт» (фаза READY, см.
## [HudTimer]), цифр на нём нет: вместо них написано [member active_text]
## («Count / Down» в две строки), и весь таймер пульсирует. Как только
## отсчёт пошёл, надпись сменяется цифрами обратно.
class_name HudTimerDigits
extends Node2D

## Шрифт цифр. Пусто — шрифт проекта (Grunge Bold V2), а если его файла
## нет — системная заглушка.
@export var font: Font:
	set(value):
		font = value
		queue_redraw()

## Размер цифр, px.
@export_range(6, 200, 1, "or_greater") var font_size := 44:
	set(value):
		font_size = maxi(value, 6)
		queue_redraw()

@export var color := Color(0.95, 0.95, 0.97):
	set(value):
		color = value
		queue_redraw()

## Тёмная обводка цифр — число читается на любой картинке таймера.
@export var outline_size := 0:
	set(value):
		outline_size = maxi(value, 0)
		queue_redraw()

@export var outline_color := Color(0.12, 0.09, 0.06, 0.85):
	set(value):
		outline_color = value
		queue_redraw()

## Сдвиг числа от центра узла, px.
@export var text_offset := Vector2.ZERO:
	set(value):
		text_offset = value
		queue_redraw()

@export_group("Последние секунды")
## С какого остатка цифры красятся в [member low_time_color]. 0 — никогда.
@export var low_time_seconds := 0.0:
	set(value):
		low_time_seconds = maxf(value, 0.0)
		queue_redraw()

@export var low_time_color := Color(0.9, 0.27, 0.22):
	set(value):
		low_time_color = value
		queue_redraw()

@export_group("Надпись активной кнопки")
## Что написано на таймере, пока он — активная кнопка «Обратный отсчёт».
## Перевод строки в поле — новая строка надписи («Count», «Down»).
@export_multiline var active_text := "Count\nDown":
	set(value):
		active_text = value
		queue_redraw()

## Размер надписи, px — свой, цифрам он не мешает.
@export_range(6, 200, 1, "or_greater") var active_font_size := 34:
	set(value):
		active_font_size = maxi(value, 6)
		queue_redraw()

@export var active_color := Color(0.98, 0.93, 0.76):
	set(value):
		active_color = value
		queue_redraw()

## Расстояние между строками: доля высоты строки (1 — вплотную).
@export_range(0.3, 2.5, 0.01, "or_greater") var active_line_spacing := 0.82:
	set(value):
		active_line_spacing = maxf(value, 0.1)
		queue_redraw()

## Сдвиг надписи от центра узла, px — цифры сдвигаются своим полем.
@export var active_text_offset := Vector2.ZERO:
	set(value):
		active_text_offset = value
		queue_redraw()

@export_group("Редактор")
## Что показывать в превью редактора (в игре не используется).
@export var editor_preview_seconds := 20:
	set(value):
		editor_preview_seconds = maxi(value, 0)
		queue_redraw()

## Превью редактора: показать надпись активной кнопки вместо цифр —
## так подбирается её размер (в игре не используется).
@export var editor_preview_active := false:
	set(value):
		editor_preview_active = value
		queue_redraw()

var gm = null


func attach(game_mode) -> void:
	gm = game_mode


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	# Слово вместо цифр — только пока таймер активная кнопка; всё
	# остальное время на нём секунды.
	if _button_active():
		_draw_active_text()
		return
	var seconds := _seconds_left()
	var text := str(int(ceilf(seconds)))
	var text_font := UiFont.resolve(font)
	var tint := color
	if low_time_seconds > 0.0 and seconds <= low_time_seconds:
		tint = low_time_color
	# Число центрируется по началу узла: по ширине — половиной строки,
	# по высоте — серединой между верхом и низом букв.
	var width := text_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var baseline := (text_font.get_ascent(font_size) - text_font.get_descent(font_size)) / 2.0
	var at := Vector2(-width / 2.0, baseline) + text_offset
	if outline_size > 0:
		draw_string_outline(text_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
				outline_size, outline_color)
	draw_string(text_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, tint)


## Надпись активной кнопки: строки идут одна под другой и центрируются
## по началу узла — как и цифры, только всем блоком сразу.
func _draw_active_text() -> void:
	var lines := active_text.split("\n", false)
	if lines.is_empty():
		return
	var text_font := UiFont.resolve(font)
	var step := text_font.get_height(active_font_size) * active_line_spacing
	var baseline := (text_font.get_ascent(active_font_size)
			- text_font.get_descent(active_font_size)) / 2.0
	var y := baseline - step * (lines.size() - 1) / 2.0
	for line in lines:
		var width := text_font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1,
				active_font_size).x
		var at := Vector2(-width / 2.0, y) + active_text_offset
		if outline_size > 0:
			draw_string_outline(text_font, at, line, HORIZONTAL_ALIGNMENT_LEFT, -1,
					active_font_size, outline_size, outline_color)
		draw_string(text_font, at, line, HORIZONTAL_ALIGNMENT_LEFT, -1,
				active_font_size, active_color)
		y += step


## Таймер сейчас — активная кнопка «Обратный отсчёт» (фаза READY, см.
## [method HudTimer.is_active]). В редакторе — по галочке превью.
func _button_active() -> bool:
	if gm == null:
		return Engine.is_editor_hint() and editor_preview_active
	return gm.phase == gm.Phase.READY


## Сколько секунд показывать: в бою — остаток, до старта раунда — вся
## его длительность (таймер выставлен, но ещё стоит).
func _seconds_left() -> float:
	if gm == null:
		return float(editor_preview_seconds)
	return gm.time_left if gm.phase == gm.Phase.PLAY else gm.time_total
