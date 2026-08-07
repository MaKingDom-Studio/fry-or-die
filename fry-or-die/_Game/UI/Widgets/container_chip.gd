## Фишка-ингредиент внутри ёмкости: корзины ([ChipContainer]) и мешка ([BagPanel]).
##
## Физическое тело с ослабленной гравитацией — фишки падают вниз и
## складываются горкой; они свободно крутятся и спавнятся повёрнутыми,
## поэтому кучки получаются неровными. Коллизия — по непрозрачным
## пикселям PNG, как у ингредиента на столе (общий кэш силуэтов
## [IngredientNode]); без изображения — по фигуре модели. Живут на
## отдельном от ингредиентов стола физическом слое: корзины — на слое 2,
## каждая секция мешка — на собственном слое (3+), поэтому фишки разных
## ёмкостей и секций друг с другом не сталкиваются.
class_name ContainerChip
extends RigidBody2D

## Битовая маска физического слоя фишек и стенок корзин (слой 2).
const CHIP_PHYSICS_LAYER := 2

## Гравитация фишек ослаблена на четверть — кучки оседают мягче.
const CHIP_GRAVITY_SCALE := 0.75

## Цвет тени фишек — перенимается из темы боя
## (CombatTheme.ingredient_shadow, задаёт режим боя при старте).
static var shadow_color := Color(0.02, 0.02, 0.04, 0.45)

## Показывать ли подпись-название под фишкой — перенимается из темы боя
## (CombatTheme.show_ingredient_labels, задаёт режим боя при старте).
static var show_labels := true

var model: IngredientModel
var chip_radius := 11.0
var _appear := 1.0                 # 0..1 — рост изображения при появлении
var _appear_flying := false        # летит из точки появления к корзине
var _appear_from := Vector2.ZERO
var _appear_target := Vector2.ZERO
var _appear_grow_end := 1.0        # доля пути, к которой рост завершён
var _appear_delay := 0.0
var _appear_speed := 900.0
var _appear_t := 0.0               # прогресс полёта появления, 0..1
var _appear_arc := 60.0            # высота дуги «вылета из холодильника»
var _appear_spin := 0.0            # кувырок в полёте, рад/с


static func create(ingredient: IngredientModel, scale_factor: float,
		physics_layer := CHIP_PHYSICS_LAYER) -> ContainerChip:
	var chip := ContainerChip.new()
	chip.model = ingredient
	chip.chip_radius = maxf(ingredient.radius * scale_factor, 8.0)
	for collision in _build_collisions(ingredient, chip.chip_radius):
		chip.add_child(collision)
	chip.collision_layer = physics_layer
	chip.collision_mask = physics_layer
	# Масса — как у ингредиента на столе: тяжёлые тянутся медленнее.
	chip.mass = 0.8 + ingredient.weight * 0.25
	chip.gravity_scale = CHIP_GRAVITY_SCALE
	chip.linear_damp = 0.5
	var material := PhysicsMaterial.new()
	material.friction = 0.7
	material.bounce = 0.15
	chip.physics_material_override = material
	return chip


## Коллизия фишки: по непрозрачным пикселям изображения — те же выпуклые
## части силуэта, что у ингредиента на столе, приведённые к радиусу фишки;
## без изображения — фигура shape/radius.
static func _build_collisions(ingredient: IngredientModel, radius: float) -> Array[Node2D]:
	var result: Array[Node2D] = []
	if ingredient.texture != null and ingredient.texture_collision:
		var silhouette_scale := radius / maxf(ingredient.radius, 0.001)
		for points in IngredientNode.silhouette_for(ingredient)["convex"]:
			var scaled := PackedVector2Array()
			for point in points:
				scaled.append(point * silhouette_scale)
			if scaled.size() < 3:
				continue
			var shape := ConvexPolygonShape2D.new()
			shape.points = scaled
			var collision := CollisionShape2D.new()
			collision.shape = shape
			result.append(collision)
	if not result.is_empty():
		return result
	var collision := CollisionShape2D.new()
	if ingredient.shape == IngredientModel.ShapeKind.SQUARE:
		var rect := RectangleShape2D.new()
		rect.size = Vector2.ONE * radius * 2.0
		collision.shape = rect
	else:
		var circle := CircleShape2D.new()
		circle.radius = radius
		collision.shape = circle
	result.append(collision)
	return result


## Позиция index-й фишки в кучке-пирамидке от дна rect: нижний ряд самый
## широкий, каждый следующий уже и по центру; при переполнении верхний
## ряд повторяется. Общая укладка для мешка и корзин.
static func pile_position(index: int, rect: Rect2, max_radius: float, step: float) -> Vector2:
	var columns := maxi(floori((rect.size.x - 4.0) / step), 1)
	var max_rows := maxi(floori((rect.size.y - 4.0) / step), 1)
	var row := 0
	var n := index
	while n >= maxi(columns - row, 1) and row < max_rows - 1:
		n -= maxi(columns - row, 1)
		row += 1
	var row_size := maxi(columns - row, 1)
	n = n % row_size
	return Vector2(
			rect.get_center().x + (n - (row_size - 1) / 2.0) * step,
			rect.end.y - 2.0 - max_radius - row * step)


## Появление при наполнении корзины — «вылет из холодильника»: фишка
## ещё до старта знает своё место в кучке (target_global) и летит из
## from_global именно туда по дуге, кувыркаясь. Растёт по пути от
## маленькой к нормальной; рост (анимация появления) завершается на
## входе в область корзины area_global. По прилёте на своё место
## включаются обычная физика и коллизия.
func fly_appear(from_global: Vector2, target_global: Vector2, area_global: Rect2,
		delay := 0.0, speed := 900.0) -> void:
	_appear_from = from_global
	_appear_target = target_global
	_appear_grow_end = _entry_fraction(from_global, target_global, area_global)
	_appear_delay = delay
	_appear_speed = maxf(speed, 1.0)
	_appear_t = 0.0
	_appear_arc = randf_range(40.0, 80.0)
	_appear_spin = randf_range(-6.0, 6.0)
	_appear_flying = true
	freeze = true
	_set_collisions_disabled(true)
	global_position = from_global
	visible = delay <= 0.0
	_set_appear(0.05)


func _physics_process(delta: float) -> void:
	# Тень зависит от поворота тела (смещение вниз компенсирует rotation) —
	# перерисовываем каждый тик, пока фишка крутится в кучке мешка/корзины,
	# а не только во время анимации появления.
	queue_redraw()
	if not _appear_flying:
		return
	if _appear_delay > 0.0:
		_appear_delay -= delta
		if _appear_delay > 0.0:
			return
	visible = true
	var total := maxf(_appear_from.distance_to(_appear_target), 1.0)
	_appear_t = minf(_appear_t + _appear_speed * delta / total, 1.0)
	# Дуга с пиком в середине пути и кувырок — как выброшенная из дверцы.
	global_position = _appear_from.lerp(_appear_target, _appear_t) \
			+ Vector2.UP * 4.0 * _appear_arc * _appear_t * (1.0 - _appear_t)
	rotation += _appear_spin * delta
	# Рост завершается на входе в область корзины, дальше — полный размер.
	var grown := 1.0 if _appear_grow_end <= 0.0 \
			else clampf(_appear_t / _appear_grow_end, 0.0, 1.0)
	_set_appear(maxf(grown, 0.05))
	if _appear_t >= 1.0:
		_finish_appear()


## Фишка прилетела на своё место: полный размер, обычная физика.
func _finish_appear() -> void:
	_appear_flying = false
	freeze = false
	_set_collisions_disabled(false)
	_set_appear(1.0)


## Мгновенно завершить полёт появления: фишка встаёт в точку сброса и
## дальше живёт обычной физикой (упадёт на своё место в кучке).
func finish_appear_now() -> void:
	if not _appear_flying:
		return
	global_position = _appear_target
	_finish_appear()


## Летит ли фишка ещё из точки появления к своему месту в корзине —
## анимация наполнения не завершена.
func is_appearing() -> bool:
	return _appear_flying


## Что показать в подсказке при наведении ([HoverTooltip]): ингредиент фишки.
func tooltip_model() -> Resource:
	return model


## Доля пути (0..1), на которой отрезок from→to входит в прямоугольник:
## 0 — старт уже внутри, 1 — вход только у самой цели (или мимо).
static func _entry_fraction(from: Vector2, to: Vector2, rect: Rect2) -> float:
	if rect.has_point(from):
		return 0.0
	var direction := to - from
	var t_enter := 0.0
	var t_exit := 1.0
	for axis in 2:
		var d := direction[axis]
		var lo := rect.position[axis]
		var hi := rect.end[axis]
		if absf(d) < 0.0001:
			if from[axis] < lo or from[axis] > hi:
				return 1.0
			continue
		var t1 := (lo - from[axis]) / d
		var t2 := (hi - from[axis]) / d
		t_enter = maxf(t_enter, minf(t1, t2))
		t_exit = minf(t_exit, maxf(t1, t2))
	if t_enter > t_exit:
		return 1.0
	return clampf(t_enter, 0.0, 1.0)


func _set_appear(value: float) -> void:
	_appear = value
	queue_redraw()


func _set_collisions_disabled(value: bool) -> void:
	for child in get_children():
		var collision := child as CollisionShape2D
		if collision != null:
			collision.disabled = value


func _draw() -> void:
	# Рост при появлении масштабирует только изображение, не физику.
	var appear := maxf(_appear, 0.02)
	var appear_scale := Vector2.ONE * appear
	var r := chip_radius
	# Тень-силуэт под фишкой — как у ингредиента на столе: смещение вниз
	# в экранных координатах, поворот фишки компенсируется.
	draw_set_transform(Vector2(0.0, 4.0).rotated(-rotation) * appear, 0.0, appear_scale)
	_draw_shadow(r)
	draw_set_transform(Vector2.ZERO, 0.0, appear_scale)
	if model.texture != null:
		draw_texture_rect(model.texture, _tex_rect(r), false)
	elif model.shape == IngredientModel.ShapeKind.SQUARE:
		draw_rect(Rect2(-r, -r, r * 2.0, r * 2.0), model.color)
		draw_rect(Rect2(-r, -r, r * 2.0, r * 2.0), Color(0.1, 0.1, 0.12), false, 1.5)
	else:
		draw_circle(Vector2.ZERO, r, model.color)
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 24, Color(0.1, 0.1, 0.12), 1.5)
	if show_labels:
		draw_string(ThemeDB.fallback_font, Vector2(-40.0, r + 10.0), model.display_name,
				HORIZONTAL_ALIGNMENT_CENTER, 80, 8, Color(0.85, 0.85, 0.88))


## Тень полностью повторяет силуэт фишки: текстура тени, затемнённое
## изображение или фигура той же формы — и вращается вместе с телом.
func _draw_shadow(r: float) -> void:
	if model.shadow_texture != null:
		draw_texture_rect(model.shadow_texture, _tex_rect(r), false)
	elif model.texture != null:
		# Силуэт изображения, залитый цветом тени.
		draw_texture_rect(model.texture, _tex_rect(r), false, shadow_color)
	elif model.shape == IngredientModel.ShapeKind.SQUARE:
		draw_rect(Rect2(-r, -r, r * 2.0, r * 2.0), shadow_color)
	else:
		draw_circle(Vector2.ZERO, r, shadow_color)


## Бокс отрисовки изображения: пропорции PNG сохраняются, длинная
## сторона = 2r, как у IngredientNode.
func _tex_rect(r: float) -> Rect2:
	if model.texture == null:
		return Rect2(-r, -r, r * 2.0, r * 2.0)
	var tex_size := model.texture.get_size()
	var longest := maxf(tex_size.x, tex_size.y)
	var size := tex_size * (r * 2.0 / longest) if longest > 0.0 \
			else Vector2.ONE * r * 2.0
	return Rect2(-size * 0.5, size)
