@tool
## Вывеска-изображение с лёгким покачиванием — например, «Специи игрока»
## над полкой специй в магазине.
##
## Узел сцены: позиция настраивается в редакторе, вид и амплитуда — в
## инспекторе. Если задано [member texture], рисуется изображение; пока
## изображения нет — табличка-плашка с надписью [member caption].
## Покачивание — медленный наклон и лёгкое вертикальное колыхание
## (у каждой вывески своя случайная фаза, чтобы несколько вывесок не
## качались синхронно). Узел при этом не двигается — качается только
## отрисовка, позиция в редакторе остаётся точной.
class_name SwayingSign
extends Node2D

## Изображение вывески; если не задано — рисуется плашка с надписью.
@export var texture: Texture2D:
	set(value):
		texture = value
		queue_redraw()

## Размер изображения на экране; (0, 0) — натуральный размер текстуры.
@export var image_size := Vector2.ZERO:
	set(value):
		image_size = value.max(Vector2.ZERO)
		queue_redraw()

## Надпись на плашке, пока нет изображения.
@export var caption := "Player spices":
	set(value):
		caption = value
		queue_redraw()

@export_group("Покачивание")
## Максимальный наклон, °. 0 — не наклоняется.
@export var sway_degrees := 3.0:
	set(value):
		sway_degrees = maxf(value, 0.0)

## Период полного качания, с.
@export var sway_period := 3.2:
	set(value):
		sway_period = maxf(value, 0.05)

## Амплитуда вертикального колыхания, px. 0 — не колышется.
@export var bob_pixels := 2.0:
	set(value):
		bob_pixels = maxf(value, 0.0)

## Период вертикального колыхания, с.
@export var bob_period := 2.1:
	set(value):
		bob_period = maxf(value, 0.05)

## Качаться и в редакторе (иначе там вывеска неподвижна).
@export var animate_in_editor := false

@export_group("Плашка")
@export var plate_size := Vector2(190.0, 44.0):
	set(value):
		plate_size = value.max(Vector2.ONE)
		queue_redraw()

@export var plate_color := Color(0.42, 0.29, 0.17):
	set(value):
		plate_color = value
		queue_redraw()

@export var border_color := Color(0.72, 0.55, 0.3):
	set(value):
		border_color = value
		queue_redraw()

@export var text_color := Color(0.96, 0.93, 0.88):
	set(value):
		text_color = value
		queue_redraw()

@export var font_size := 17:
	set(value):
		font_size = maxi(value, 6)
		queue_redraw()

var _time := 0.0
## Своя фаза у каждой вывески — соседние качаются вразнобой.
var _phase := 0.0


func _ready() -> void:
	_phase = randf_range(0.0, TAU)


func _process(delta: float) -> void:
	if Engine.is_editor_hint() and not animate_in_editor:
		return
	_time += delta
	queue_redraw()


func _draw() -> void:
	var angle := 0.0
	var bob := 0.0
	if not Engine.is_editor_hint() or animate_in_editor:
		angle = SwayMotion.tilt(_time, _phase, sway_degrees, sway_period)
		bob = SwayMotion.bob(_time, _phase, bob_pixels, bob_period)
	draw_set_transform(Vector2(0.0, bob), angle, Vector2.ONE)
	if texture != null:
		var size := image_size
		if size.x <= 0.0 or size.y <= 0.0:
			size = texture.get_size()
		draw_texture_rect(texture, Rect2(-size * 0.5, size), false)
		return
	# Плашка-фолбэк: дощечка с надписью, пока нет изображения.
	var rect := Rect2(-plate_size * 0.5, plate_size)
	draw_rect(rect, plate_color)
	draw_rect(Rect2(rect.position, Vector2(plate_size.x, 4.0)),
			Color(border_color, 0.5))
	draw_rect(rect, border_color, false, 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(rect.position.x, font_size * 0.36),
			caption, HORIZONTAL_ALIGNMENT_CENTER, plate_size.x, font_size, text_color)
