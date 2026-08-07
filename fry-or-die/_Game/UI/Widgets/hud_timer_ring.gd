@tool
## Круг-секундомер таймера раунда — отдельный узел, независимый от цифр
## ([HudTimerDigits]).
##
## Круг отсчитывает не весь раунд, а секунды: полный оборот он совершает
## ровно за [member seconds_per_turn] (по умолчанию — за одну секунду) и
## начинает заново, пока идёт раунд. Заполняется он [member fill_color],
## поверх «дорожки» [member track_color].
##
## Позиция и размер настраиваются в редакторе: узел двигается мышью,
## радиус/толщина/цвета — в инспекторе. Цифры таймера живут в своём
## узле, поэтому круг можно двигать и масштабировать отдельно от них.
class_name HudTimerRing
extends Node2D

## Чем рисуется заполнение: кольцом заданной толщины или сплошным сектором.
enum FillStyle {
	ARC,  ## Кольцо толщиной [member arc_width].
	PIE,  ## Сплошной сектор от центра до края.
}

@export var radius := 47.0:
	set(value):
		radius = maxf(value, 1.0)
		queue_redraw()

## Как рисуется заполнение: кольцом или сплошным сектором.
@export var fill_style: FillStyle = FillStyle.ARC:
	set(value):
		fill_style = value
		queue_redraw()

## Толщина кольца для [constant FillStyle.ARC], px.
@export var arc_width := 10.0:
	set(value):
		arc_width = maxf(value, 0.5)
		queue_redraw()

## За сколько секунд круг делает полный оборот. 1 — оборот в секунду.
@export var seconds_per_turn := 1.0:
	set(value):
		seconds_per_turn = maxf(value, 0.05)
		queue_redraw()

## Круг не заполняется, а опустошается за оборот.
@export var reverse := false:
	set(value):
		reverse = value
		queue_redraw()

## Направление оборота: по часовой стрелке или против.
@export var clockwise := true:
	set(value):
		clockwise = value
		queue_redraw()

## С какого угла начинается оборот, градусы (-90 — сверху).
@export_range(-180.0, 180.0) var start_angle := -90.0:
	set(value):
		start_angle = value
		queue_redraw()

@export_group("Цвета")
## Чем заполняется круг.
@export var fill_color := Color(1.0, 0.78, 0.2):
	set(value):
		fill_color = value
		queue_redraw()

## Дорожка под заполнением (незаполненная часть круга).
@export var track_color := Color(0.12, 0.12, 0.14, 0.55):
	set(value):
		track_color = value
		queue_redraw()

## Обводка круга по внешнему краю; прозрачная — обводки нет.
@export var border_color := Color(0.93, 0.93, 0.95, 0.0):
	set(value):
		border_color = value
		queue_redraw()

@export var border_width := 2.0:
	set(value):
		border_width = maxf(value, 0.0)
		queue_redraw()

@export_group("Поведение")
## Каким показывать круг, пока раунд не начался (кнопка «Обратный
## отсчёт» ещё не нажата) и после его конца.
@export_range(0.0, 1.0) var idle_progress := 1.0:
	set(value):
		idle_progress = clampf(value, 0.0, 1.0)
		queue_redraw()

## Заполнение в превью редактора (в игре не используется).
@export_range(0.0, 1.0) var editor_preview_progress := 0.65:
	set(value):
		editor_preview_progress = clampf(value, 0.0, 1.0)
		queue_redraw()

## Сколько отрезков в дуге: больше — глаже край.
const SEGMENTS := 64

var gm = null


func attach(game_mode) -> void:
	gm = game_mode


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var progress := _progress()
	if track_color.a > 0.0:
		_draw_ring_part(1.0, track_color)
	if progress > 0.0 and fill_color.a > 0.0:
		_draw_ring_part(progress, fill_color)
	if border_color.a > 0.0 and border_width > 0.0:
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, SEGMENTS, border_color, border_width)


## Насколько круг заполнен сейчас, 0..1. В бою — доля текущей секунды:
## за [member seconds_per_turn] проходит весь круг и начинает заново.
func _progress() -> float:
	if gm == null:
		return editor_preview_progress
	if gm.phase != gm.Phase.PLAY:
		return idle_progress
	# time_left убывает, поэтому остаток от деления идёт 1 → 0: без
	# reverse круг за секунду заполняется, с ним — опустошается.
	var turn_part := fposmod(gm.time_left, seconds_per_turn) / seconds_per_turn
	return turn_part if reverse else 1.0 - turn_part


## Кольцо или сектор на долю [param fraction] круга.
func _draw_ring_part(fraction: float, color: Color) -> void:
	var from := deg_to_rad(start_angle)
	var span := TAU * clampf(fraction, 0.0, 1.0) * (1.0 if clockwise else -1.0)
	if fill_style == FillStyle.PIE:
		draw_colored_polygon(_sector_points(from, span), color)
		return
	# Дуга рисуется по средней линии кольца — так внешний край кольца
	# совпадает с радиусом узла, каким бы толстым оно ни было.
	var width := minf(arc_width, radius * 2.0)
	var line := maxf(radius - width / 2.0, 0.01)
	draw_arc(Vector2.ZERO, line, from, from + span, SEGMENTS, color, width)


## Точки сплошного сектора: центр + край дуги.
func _sector_points(from: float, span: float) -> PackedVector2Array:
	var points := PackedVector2Array([Vector2.ZERO])
	for i in SEGMENTS + 1:
		var angle := from + span * i / float(SEGMENTS)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points
