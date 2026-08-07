## Видимый круг захвата под курсором: рисует ту самую область, которой
## можно хватать предметы ([GrabArea]), — маленький круг едет за мышью.
##
## Узел создают режимы боя, магазина и песочницы ([method attach_to]):
## радиус круга — это радиус захвата ([member CombatConfig.grab_radius] /
## [member SandboxConfig.grab_radius]), вид — поля grab_circle_* тех же
## конфигов. Выключенный в конфиге или с нулевым радиусом круг
## не создаётся вовсе.
class_name GrabCircleOverlay
extends Node2D

## Сегментов в контуре — хватает для гладкого маленького круга.
const ARC_POINTS := 48
## Заливка — тот же цвет, что контур, ослабленный до этой доли.
const FILL_ALPHA := 0.3

var radius := 8.0
var color := Color(0.13, 0.68, 0.96, 0.35)
var width := 2.0


## Создать круг поверх сцены-родителя. Конфиг — [CombatConfig] или
## [SandboxConfig]: поля круга захвата у них одинаковые.
static func attach_to(parent: Node, config: Resource, z: int) -> void:
	if config == null or not config.get("grab_circle_visible") \
			or config.get("grab_radius") <= 0.0:
		return
	var overlay := GrabCircleOverlay.new()
	overlay.name = "GrabCircle"
	overlay.radius = config.get("grab_radius")
	overlay.color = config.get("grab_circle_color")
	overlay.width = config.get("grab_circle_width")
	overlay.z_index = z
	parent.add_child(overlay)


func _process(_delta: float) -> void:
	# Курсор постоянно движется — круг перерисовывается каждый кадр.
	queue_redraw()


func _draw() -> void:
	var center := to_local(get_global_mouse_position())
	# Едва заметная заливка + контур: круг видно и на светлом, и на тёмном.
	var fill := color
	fill.a *= FILL_ALPHA
	draw_circle(center, radius, fill)
	draw_arc(center, radius, 0.0, TAU, ARC_POINTS, color, width, true)
