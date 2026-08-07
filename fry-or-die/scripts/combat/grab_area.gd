## Круг захвата под курсором: небольшая область, которой можно хватать
## предметы, не целясь в них пиксель в пиксель.
##
## Точное попадание главнее: тело, накрытое самим курсором, берётся как
## раньше, — и только если под курсором пусто, вокруг точки ищется круг
## и берётся ближайшее к курсору тело. Радиус круга — в конфиге:
## [member CombatConfig.grab_radius] (da_combat.tres) для боя и магазина,
## [member SandboxConfig.grab_radius] (da_sandbox.tres) для песочницы;
## 0 выключает круг и оставляет только точечный захват.
class_name GrabArea
extends RefCounted


## Тела под самой точкой + тела в круге радиусом radius вокруг неё:
## сперва точные попадания (в порядке точечного запроса), затем остальные
## из круга — ближайшие к точке первыми. Каждое тело в списке один раз.
static func bodies_at(world: World2D, point: Vector2, radius: float,
		mask: int = 0xFFFFFFFF, max_results: int = 16) -> Array:
	var bodies := bodies_at_point(world, point, mask, max_results)
	for body in bodies_in_circle(world, point, radius, mask, max_results):
		if not bodies.has(body):
			bodies.append(body)
	return bodies


## Тела, чья коллизия накрыта самой точкой.
static func bodies_at_point(world: World2D, point: Vector2,
		mask: int = 0xFFFFFFFF, max_results: int = 16) -> Array:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = point
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.collision_mask = mask
	var bodies := []
	for hit in world.direct_space_state.intersect_point(query, max_results):
		bodies.append(hit.collider)
	return bodies


## Тела, чья коллизия задета кругом радиусом radius вокруг точки, —
## ближайшие к точке первыми. Близость считается по центрам тел:
## для маленького круга захвата этого достаточно.
static func bodies_in_circle(world: World2D, point: Vector2, radius: float,
		mask: int = 0xFFFFFFFF, max_results: int = 16) -> Array:
	if radius <= 0.0:
		return []
	var shape := CircleShape2D.new()
	shape.radius = radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, point)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.collision_mask = mask
	var bodies := []
	for hit in world.direct_space_state.intersect_shape(query, max_results):
		var body := hit.collider as Node2D
		if body != null:
			bodies.append(body)
	bodies.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return a.global_position.distance_squared_to(point) \
				< b.global_position.distance_squared_to(point))
	return bodies
