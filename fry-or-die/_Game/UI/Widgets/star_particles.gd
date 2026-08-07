## Партиклы подсчёта: маленькие звёздочки летят от посчитанного ингредиента
## к счётчику звёзд своей стороны и тают у цели.
##
## Оверлей-узел боевой сцены (как [CombatScoreLabels]): лежит ребёнком корня
## с высоким z-индексом, поэтому звёздочки видны и над столом, и над HUD.
## Режим боя вызывает [method burst] на каждый посчитанный ингредиент
## (см. `gm_combat._award`); цель — звезда счётчика, которую сейчас
## заполняет сторона ([method HudStarRow.slot_global_position]).
class_name StarParticles
extends Node2D

## Сколько секунд летит звёздочка (каждой даётся небольшой разброс).
@export_range(0.1, 3.0, 0.05) var flight_time := 0.55
## Разброс времени полёта, сек.
@export var flight_time_spread := 0.15
## Радиус звёздочки, px.
@export var star_radius := 8.0
## Разброс радиуса, px.
@export var star_radius_spread := 3.0
## Насколько дуга полёта выгибается вбок, px.
@export var arc_spread := 70.0
## Разлёт точек старта вокруг ингредиента, px.
@export var start_spread := 14.0
## Цвет звёздочек.
@export var star_color := Color(1.0, 0.85, 0.3)

## Живые партиклы: {"from": Vector2, "ctrl": Vector2, "to": Vector2,
## "life": float, "duration": float, "radius": float}.
var _particles: Array[Dictionary] = []


## Выпустить amount звёздочек от from (мировая точка ингредиента) к to
## (мировая точка звезды счётчика).
func burst(from: Vector2, to: Vector2, amount := 3) -> void:
	for _i in maxi(amount, 1):
		var start := from + Vector2(
				randf_range(-start_spread, start_spread),
				randf_range(-start_spread, start_spread))
		# Квадратичная дуга: контрольная точка сбоку от прямой, чтобы
		# звёздочки не летели одной струной.
		var side := (to - start).orthogonal().normalized()
		var ctrl := start.lerp(to, 0.5) + side * randf_range(-arc_spread, arc_spread)
		_particles.append({
			"from": start,
			"ctrl": ctrl,
			"to": to,
			"life": 0.0,
			"duration": maxf(
					flight_time + randf_range(-flight_time_spread, flight_time_spread),
					0.15),
			"radius": maxf(star_radius + randf_range(-star_radius_spread, star_radius_spread),
					2.0),
		})
	queue_redraw()


func _process(delta: float) -> void:
	if _particles.is_empty():
		return
	for i in range(_particles.size() - 1, -1, -1):
		_particles[i]["life"] += delta
		if _particles[i]["life"] >= _particles[i]["duration"]:
			_particles.remove_at(i)
	queue_redraw()


func _draw() -> void:
	for p in _particles:
		var t: float = clampf(p["life"] / p["duration"], 0.0, 1.0)
		# Плавный разгон и торможение по дуге Безье.
		var u := t * t * (3.0 - 2.0 * t)
		var a: Vector2 = (p["from"] as Vector2).lerp(p["ctrl"], u)
		var b: Vector2 = (p["ctrl"] as Vector2).lerp(p["to"], u)
		# У самой цели звёздочка сжимается и гаснет — «впитывается» в счётчик.
		var fade := clampf((1.0 - t) / 0.25, 0.0, 1.0)
		StarIcon.draw(self, to_local(a.lerp(b, u)),
				p["radius"] * (0.55 + 0.45 * fade), Color(star_color, fade))
