extends Node2D

## Рисует толстую голубую линию от точки захвата квадрата до курсора —
## визуализация "тяги", как на референсе.

const LINE_COLOR := Color(0.13, 0.68, 0.96)
const LINE_WIDTH := 14.0

@onready var _main: Node2D = get_parent()


func _process(_delta: float) -> void:
	# Перерисовываем каждый кадр: и квадрат, и курсор постоянно движутся.
	queue_redraw()


func _draw() -> void:
	var dragged: DragSquare = _main.dragged
	if dragged == null:
		return
	var from := to_local(dragged.grab_point_global())
	var to := to_local(get_global_mouse_position())
	if from.distance_to(to) > 1.0:
		draw_line(from, to, LINE_COLOR, LINE_WIDTH)
	# Скруглённые концы линии.
	draw_circle(from, LINE_WIDTH / 2.0, LINE_COLOR)
	draw_circle(to, LINE_WIDTH / 2.0, LINE_COLOR)
