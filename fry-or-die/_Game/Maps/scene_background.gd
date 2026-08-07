@tool
## Задний фон сцены: цвет и/или растянутая текстура.
## Настраивается прямо на сцене (узел Background в l_combat.tscn).
class_name SceneBackground
extends Node2D

@export var color := Color(0.05, 0.05, 0.06):
	set(value):
		color = value
		queue_redraw()

## Фоновое изображение (опционально; растягивается на size).
@export var texture: Texture2D:
	set(value):
		texture = value
		queue_redraw()

@export var size := Vector2(1152, 648):
	set(value):
		size = value.max(Vector2.ZERO)
		queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), color)
	if texture != null:
		draw_texture_rect(texture, Rect2(Vector2.ZERO, size), false)
