## Зона сброса ингредиентов.
##
## Прямоугольник задаваемого размера ([member zone_size]), который может
## двигаться строго внутри задаваемых границ ([member bounds]).
## [member Node2D.position] узла — левый верхний угол зоны в координатах родителя.
## Любое перемещение зажимается так, чтобы зона целиком оставалась в границах.
class_name DropZone
extends Node2D

signal zone_moved(old_position: Vector2, new_position: Vector2)

## Размер зоны сброса.
@export var zone_size: Vector2 = Vector2(200, 100):
	set(value):
		zone_size = value.max(Vector2.ZERO)
		_clamp_into_bounds()

## Границы, внутри которых зона может двигаться (в координатах родителя).
@export var bounds: Rect2 = Rect2(0, 0, 1152, 648):
	set(value):
		bounds = value.abs()
		_clamp_into_bounds()

func _ready() -> void:
	_clamp_into_bounds()

## Переместить зону в точку [param target] (левый верхний угол);
## позиция будет зажата в границы.
func move_to(target: Vector2) -> void:
	var old := position
	position = _clamped(target)
	if position != old:
		zone_moved.emit(old, position)

## Сдвинуть зону на [param delta] с зажимом в границы.
func move_by(delta: Vector2) -> void:
	move_to(position + delta)

## Прямоугольник зоны в координатах родителя.
func get_zone_rect() -> Rect2:
	return Rect2(position, zone_size)

## Случайная точка внутри зоны — сюда можно уронить ингредиент.
func get_random_drop_point(rng: RandomNumberGenerator = null) -> Vector2:
	var x := rng.randf() if rng != null else randf()
	var y := rng.randf() if rng != null else randf()
	return position + Vector2(x * zone_size.x, y * zone_size.y)

func contains_point(point: Vector2) -> bool:
	return get_zone_rect().has_point(point)

func _clamped(target: Vector2) -> Vector2:
	var min_pos := bounds.position
	var max_pos := bounds.end - zone_size
	# Если зона больше границ, прижимаем её к началу границ.
	max_pos = max_pos.max(min_pos)
	return target.clamp(min_pos, max_pos)

func _clamp_into_bounds() -> void:
	position = _clamped(position)
