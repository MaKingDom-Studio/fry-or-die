## Рисует линию «тяги» от точки захвата ингредиента до цели пружины
## (курсор; при групповом захвате ситом — курсор со смещением каждого
## ингредиента), как в песочнице.
##
## Цвет и толщина настраиваются в конфиге боя
## ([member CombatConfig.drag_line_color] / [member CombatConfig.drag_line_width],
## файл da_combat.tres). Узел кладётся ребёнком корня боевой сцены
## (режима боя gm_combat) и берёт список линий из него.
class_name CombatDragOverlay
extends Node2D

## Запасные значения, если конфиг боя недоступен.
const FALLBACK_COLOR := Color(0.13, 0.68, 0.96)
const FALLBACK_WIDTH := 6.0

@onready var _gm = get_parent()


func _process(_delta: float) -> void:
	# И ингредиент, и курсор постоянно движутся — перерисовываем каждый кадр.
	queue_redraw()


func _draw() -> void:
	if _gm == null or not _gm.has_method("get_drag_lines"):
		return
	var line_color := FALLBACK_COLOR
	var line_width := FALLBACK_WIDTH
	var config = _gm.get("config")
	if config != null:
		line_color = config.drag_line_color
		line_width = config.drag_line_width
	for line in _gm.get_drag_lines():
		var from: Vector2 = to_local(line[0])
		var to_point: Vector2 = to_local(line[1])
		if from.distance_to(to_point) > 1.0:
			draw_line(from, to_point, line_color, line_width)
		# Скруглённые концы линии.
		draw_circle(from, line_width / 2.0, line_color)
		draw_circle(to_point, line_width / 2.0, line_color)
