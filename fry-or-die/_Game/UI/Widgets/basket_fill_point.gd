@tool
## Узел-точка появления: отсюда вылетают фишки при наполнении корзины
## ([member ChipContainer.fill_point]). Отдельный узел — двигается мышью
## в 2D-виде редактора; может лежать где угодно в сцене. В игре не
## рисуется.
class_name BasketFillPoint
extends Node2D

@export var label := "Fill":
	set(value):
		label = value
		queue_redraw()

@export var marker_color := Color(0.9, 0.7, 0.35):
	set(value):
		marker_color = value
		queue_redraw()


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	draw_arc(Vector2.ZERO, 6.0, 0.0, TAU, 16, marker_color, 1.5)
	draw_line(Vector2(-10.0, 0.0), Vector2(10.0, 0.0), marker_color, 1.5)
	draw_line(Vector2(0.0, -10.0), Vector2(0.0, 10.0), marker_color, 1.5)
	draw_string(ThemeDB.fallback_font, Vector2(-60.0, 22.0), label,
			HORIZONTAL_ALIGNMENT_CENTER, 120, 9, marker_color)
