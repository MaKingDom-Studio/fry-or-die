@tool
## Зона боевого стола. Четыре вида:
## PLAYER — получение очков игроком, ENEMY — получение очков противником,
## POUR — область выпадения из корзины, BOUNDS — границы, за которые
## объекты не могут покинуть стол (по ней строятся стены).
##
## Настраивается прямо в редакторе: положение — перетаскиванием узла,
## размер, цвета и подпись — в инспекторе; зона рисует себя и в редакторе
## (@tool), и в игре. Режим боя (gm_combat) находит зоны по [member kind]
## среди детей узла Zones и берёт прямоугольники через [method get_rect].
class_name CombatZone
extends Node2D

enum Kind { PLAYER, POUR, ENEMY, BOUNDS }

## Роль зоны в бою.
@export var kind: Kind = Kind.PLAYER:
	set(value):
		kind = value
		queue_redraw()

## Размер зоны; [member Node2D.position] узла — её левый верхний угол.
@export var size := Vector2(300, 450):
	set(value):
		size = value.max(Vector2.ZERO)
		queue_redraw()

@export var caption := "":
	set(value):
		caption = value
		queue_redraw()

@export_group("Вид")
@export var fill_color := Color(0.3, 0.3, 0.35, 0.14):
	set(value):
		fill_color = value
		queue_redraw()

@export var border_color := Color(0.6, 0.6, 0.7, 0.55):
	set(value):
		border_color = value
		queue_redraw()

@export var border_width := 2.0:
	set(value):
		border_width = maxf(value, 0.0)
		queue_redraw()

@export var caption_color := Color(0.7, 0.7, 0.75):
	set(value):
		caption_color = value
		queue_redraw()

@export var caption_font_size := 11:
	set(value):
		caption_font_size = maxi(value, 1)
		queue_redraw()


## Прямоугольник зоны в глобальных координатах (учитывает масштаб узла,
## выставленный в редакторе).
func get_rect() -> Rect2:
	return Rect2(global_position, size * global_scale)


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, fill_color)
	if border_width > 0.0:
		draw_rect(rect, border_color, false, border_width)
	if caption != "":
		draw_string(ThemeDB.fallback_font, Vector2(0.0, size.y + 15.0), caption,
				HORIZONTAL_ALIGNMENT_CENTER, size.x, caption_font_size, caption_color)
