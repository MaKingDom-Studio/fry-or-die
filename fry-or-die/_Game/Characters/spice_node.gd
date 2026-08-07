## Физическая специя-бутылочка на полке боя ([SpiceShelf]).
##
## В отличие от ингредиента стола (вид сверху, без гравитации) специя
## живёт с гравитацией: падает с ускорением и стоит на дне полки. Специи
## можно трогать, поднимать и таскать пружиной за точку захвата, но друг
## с другом они не взаимодействуют — каждое тело на слое [constant
## SPICE_LAYER] с маской только по стенкам полки ([constant
## SPICE_WALL_LAYER]), так что специи проходят одна сквозь другую и
## сталкиваются лишь со стенками своей области. Коллизия захвата строится
## по непрозрачным пикселям PNG: схватить можно ровно за силуэт картинки.
##
## Поворотом рулит не физика, а осциллятор покачивания: ориентация тела
## каждый тик выставляется вручную в [method _integrate_forces] (момент
## силы и удары не крутят специю — только линейная физика), вместо
## кувырков — лёгкое качание в пределах ±[member sway_max]. Качнуть специю
## может неровный захват (взяли не по центру) и приземление с высоты — оба
## дают затухающий отклик осциллятора.
##
## Порядок отрисовки — [member z_index] = z_base + [member
## SpiceModel.z_order]: так задаётся, кто из специй рисуется поверх других
## (у специй z_order 16..20), и все они выносятся на передний план сцены.
class_name SpiceNode
extends RigidBody2D

## Слой физических тел специй и слой стенок полки. Тела специй имеют маску
## только по стенкам, поэтому сталкиваются со стенками своей области, но
## не друг с другом — специи между собой не взаимодействуют.
const SPICE_LAYER := 1 << 10
const SPICE_WALL_LAYER := 1 << 11

## Порог скорости падения (px/s), с которого приземление даёт покачивание.
const LAND_SWAY_SPEED := 200.0
## Порог скорости падения (px/s), ниже которого специя просто ложится без
## подскока (мелкие касания — например, при спавне — не подпрыгивают).
const BOUNCE_MIN_SPEED := 150.0

var model: SpiceModel
## Цвет тени под специей — силуэт PNG, залитый этим цветом.
var shadow_color := Color(0.02, 0.02, 0.04, 0.4)
## Рисовать ли тень. Полка ([SpiceShelf]) задаёт это своим переключателем:
## стоящим на ней бутылочкам тень обычно не нужна.
var show_shadow := true

# Пружина перетаскивания — параметры из CombatConfig (как у стола и мешка).
var drag_stiffness := 60.0
var max_stretch := 300.0
var max_speed := 1400.0
var drag_inertia := 0.6

## Максимальный наклон покачивания, рад (полка задаёт в градусах).
var sway_max := deg_to_rad(10.0)
## Жёсткость и затухание осциллятора покачивания (недодемпфирован — качок
## виден, потом гаснет).
var sway_stiffness := 140.0
var sway_damping := 5.5

## Приземление: сколько раз специя подпрыгивает и какая доля скорости
## падения сохраняется в подскоке. Подскок — ручной (упругость физики
## выключена), поэтому число отскоков жёстко ограничено — специя не
## дребезжит у дна. Настраивается полкой ([SpiceShelf]).
var max_bounces := 2
var bounce_strength := 0.28

## Кэш формы силуэта по модели: {model: {"convex": [...], "outlines": [...]}}.
static var _shape_cache := {}

## Бокс отрисовки изображения: центр в нуле, пропорции PNG сохранены
## (длинная сторона = radius * 2).
var _tex_box := Rect2()
## Контуры силуэта для обводки захвата (координаты бокса отрисовки).
var _outline_polys := []

var _dragging := false
var _grab_local := Vector2.ZERO     # точка захвата в локальных координатах
## Нормали контактов со стенками, снятые на прошлом тике: в эти стороны
## специя больше не ускоряется — упёрлась, значит вдавливаться дальше
## некуда (см. [method _clip_into_contacts]).
var _contact_normals: Array[Vector2] = []

# Осциллятор покачивания.
var _sway := 0.0                    # текущий наклон, рад
var _sway_vel := 0.0                # угловая скорость покачивания, рад/с
var _sway_target := 0.0             # к какому наклону тянется (в руке — от захвата)
var _fall_speed := 0.0              # скорость снижения прошлого тика (для приземления)
var _bounce_count := 0              # сколько раз подпрыгнула за текущее падение


static func create(spice: SpiceModel, config: CombatConfig, z_base: int,
		body_gravity_scale: float, sway_max_degrees: float) -> SpiceNode:
	var node := SpiceNode.new()
	node.model = spice
	node.drag_stiffness = config.drag_stiffness
	node.max_stretch = config.max_stretch
	node.max_speed = config.max_speed
	node.drag_inertia = config.drag_inertia
	node.sway_max = deg_to_rad(maxf(sway_max_degrees, 0.0))
	node.mass = 1.0
	node._tex_box = texture_box(spice)
	for collision in _build_collisions(spice):
		node.add_child(collision)
	if spice.texture != null:
		node._outline_polys = _shape_data_for(spice)["outlines"]
	# Кто спереди, кто сзади среди специй + вынос на передний план сцены.
	node.z_index = z_base + spice.z_order
	node.collision_layer = SPICE_LAYER
	node.collision_mask = SPICE_WALL_LAYER
	# Ускорение падения — масштаб гравитации проекта.
	node.gravity_scale = maxf(body_gravity_scale, 0.0)
	node.linear_damp = 1.0
	# Тело всегда обновляет покачивание (иначе заснёт на дне полки).
	node.can_sleep = false
	# Отслеживаем контакты: на поверхности гасим горизонтальную скорость,
	# чтобы специя оставалась там, куда упала, и не укатывалась, а упёршись
	# в стенку — перестаём ускоряться в её сторону. Силуэт разбит на много
	# выпуклых частей, поэтому контактов сообщаем с запасом.
	node.contact_monitor = true
	node.max_contacts_reported = 8
	# Непрерывная проверка столкновений лучом: без неё пружина
	# перетаскивания протаскивает бутылочку сквозь тонкий бортик полки —
	# специя «упирается» в стенку и оказывается снаружи. Луч (а не форма!)
	# выбран намеренно: cast-shape в этой же ситуации телепортирует тело
	# за пределы мира.
	node.continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY
	var material := PhysicsMaterial.new()
	material.friction = 0.8
	# Упругость физики выключена — подскок делается вручную с жёстким
	# ограничением числа, чтобы у дна не было бесконечного дребезга.
	material.bounce = 0.0
	node.physics_material_override = material
	return node


## Эффективный радиус специи: [member SpiceModel.radius], помноженный на
## визуальный размер [member SpiceModel.visual_scale]. Им масштабируются и
## картинка, и коллизия захвата, и расстановка — всё вместе.
static func effective_radius(spice: SpiceModel) -> float:
	return spice.radius * maxf(spice.visual_scale, 0.01)


## Бокс отрисовки изображения: вписан в квадрат 2r x 2r с сохранением
## пропорций PNG (длинная сторона = 2r), центр в нуле. Без изображения —
## квадрат фигуры радиуса r. r — эффективный радиус (с учётом visual_scale).
static func texture_box(spice: SpiceModel) -> Rect2:
	var r := effective_radius(spice)
	var box := Rect2(-r, -r, r * 2.0, r * 2.0)
	if spice.texture == null:
		return box
	var tex_size := spice.texture.get_size()
	var longest := maxf(tex_size.x, tex_size.y)
	if longest <= 0.0:
		return box
	var size := tex_size * (r * 2.0 / longest)
	return Rect2(-size * 0.5, size)


## Силуэт изображения для сторонних узлов (товар в магазине): те же
## выпуклые части и контуры, что у специи на полке, из общего кэша.
static func silhouette_for(spice: SpiceModel) -> Dictionary:
	return _shape_data_for(spice)


## Коллизия специи: по непрозрачным пикселям изображения (альфа PNG),
## иначе — круг эффективного радиуса (с учётом visual_scale). Силуэт
## разбивается на выпуклые части (RigidBody2D не работает с вогнутыми).
static func _build_collisions(spice: SpiceModel) -> Array[Node2D]:
	var result: Array[Node2D] = []
	if spice.texture != null:
		for points in _shape_data_for(spice)["convex"]:
			var shape := ConvexPolygonShape2D.new()
			shape.points = points
			var collision := CollisionShape2D.new()
			collision.shape = shape
			result.append(collision)
	if not result.is_empty():
		return result
	var collision := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = effective_radius(spice)
	collision.shape = circle
	result.append(collision)
	return result


## Форма по альфе изображения: контуры непрозрачных пикселей, приведённые
## к боксу отрисовки, и их разбивка на выпуклые части для физики. Считается
## один раз на модель и кэшируется.
static func _shape_data_for(spice: SpiceModel) -> Dictionary:
	if _shape_cache.has(spice):
		return _shape_cache[spice]
	var data := {"convex": [], "outlines": []}
	if spice.texture == null:
		_shape_cache[spice] = data
		return data
	var image := spice.texture.get_image()
	if image != null and not image.is_empty():
		if image.is_compressed():
			image.decompress()
		var bitmap := BitMap.new()
		bitmap.create_from_image_alpha(image)
		var size := bitmap.get_size()
		var box := texture_box(spice)
		var scale_factor := box.size / Vector2(size)
		# Упрощение контура: ~1.5 пикселя экрана в пикселях исходника
		# (от размера бокса — учитывает визуальный масштаб).
		var epsilon := maxf(2.0,
				float(maxi(size.x, size.y)) * 1.5 / maxf(box.size.x, box.size.y))
		for source in bitmap.opaque_to_polygons(Rect2i(Vector2i.ZERO, size), epsilon):
			if source.size() < 3:
				continue
			var outline := PackedVector2Array()
			for point in source:
				outline.append(point * scale_factor + box.position)
			data["outlines"].append(outline)
			data["convex"].append_array(_convex_parts(outline))
	_shape_cache[spice] = data
	return data


## Разбивка простого многоугольника на выпуклые части для
## ConvexPolygonShape2D; при сбое разбивки — выпуклая оболочка контура.
static func _convex_parts(outline: PackedVector2Array) -> Array:
	var parts := []
	for part in Geometry2D.decompose_polygon_in_convex(outline):
		if part.size() >= 3:
			parts.append(part)
	if parts.is_empty():
		var hull := Geometry2D.convex_hull(outline)
		if hull.size() > 1 and hull[0] == hull[hull.size() - 1]:
			hull.remove_at(hull.size() - 1)
		if hull.size() >= 3:
			parts.append(hull)
	return parts


## Что показать в подсказке при наведении ([HoverTooltip]): саму специю.
func tooltip_model() -> Resource:
	return model


# --- Перетаскивание ---

func is_dragging() -> bool:
	return _dragging


## Схватить за точку global_point. Неровный захват (не по центру
## по горизонтали) качнёт специю в пределах ±[member sway_max].
func start_drag(global_point: Vector2) -> void:
	_dragging = true
	_grab_local = to_local(global_point)
	var half_w := maxf(_tex_box.size.x, 1.0) * 0.5
	var offset_ratio := clampf(_grab_local.x / half_w, -1.0, 1.0)
	# В руке специя висит наклонённой в сторону захвата; толчок скорости
	# делает подъём с покачиванием, а не мгновенным доворотом.
	_sway_target = -offset_ratio * sway_max
	_sway_vel += -offset_ratio * sway_max * 4.0


func end_drag() -> void:
	_dragging = false
	# Отпущенная специя падает ровно; покачивание вернёт приземление.
	_sway_target = 0.0


func grab_point_global() -> Vector2:
	return to_global(_grab_local)


## Пружина с демпфером за точку захвата — та же формула, что у ингредиентов
## стола, плюс компенсация веса (иначе гравитация оттягивает специю вниз от
## места клика). Момент силы гасится в [method _integrate_forces] (поворот
## обнуляется в пользу _sway) — за наклон отвечает осциллятор покачивания.
##
## Упёршись в стенку, специя перестаёт ускоряться в её сторону: из тяги
## убирается составляющая, вдавливающая тело в контакт. Тянуть вдоль стенки
## это не мешает — специя скользит по ней и может выйти поверх бортика.
func apply_drag_force(target: Vector2) -> void:
	var grab_global := grab_point_global()
	var stretch := target - grab_global
	if stretch.length() > max_stretch:
		stretch = stretch.normalized() * max_stretch
	var damping_ratio := lerpf(0.9, 0.08, drag_inertia)
	var damping := 2.0 * damping_ratio * sqrt(drag_stiffness * mass)
	var force := drag_stiffness * stretch - damping * linear_velocity
	var gravity := gravity_scale * float(ProjectSettings.get_setting(
			"physics/2d/default_gravity", 980.0))
	force = _clip_into_contacts(force + Vector2(0.0, -mass * gravity))
	apply_force(force, grab_global - global_position)
	if linear_velocity.length() > max_speed:
		linear_velocity = linear_velocity.normalized() * max_speed


## Убрать из вектора составляющие, направленные в стенку, с которой уже
## есть контакт: в эти стороны специя не ускоряется и не давит. Нормали
## контактов смотрят от стенки наружу, поэтому «в стенку» — это
## отрицательная проекция. Движение вдоль стенки сохраняется целиком.
func _clip_into_contacts(vector: Vector2) -> Vector2:
	var result := vector
	for normal in _contact_normals:
		var into := result.dot(normal)
		if into < 0.0:
			result -= normal * into
	return result


# --- Покачивание и поворот ---

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	var step := state.step
	# Нормали контактов пригодятся на следующем тике: в сторону стенки,
	# в которую специя упёрлась, тяга больше не прикладывается.
	_contact_normals.clear()
	for i in state.get_contact_count():
		_contact_normals.append(state.get_contact_local_normal(i))
	# Приземление с высоты: пока не тащим, ловим резкое торможение по
	# вертикали (удар о дно) — от него идёт покачивание и ручной подскок.
	if not _dragging:
		var vy := state.linear_velocity.y
		if _fall_speed > BOUNCE_MIN_SPEED and vy < _fall_speed * 0.5:
			# Покачивание — тем сильнее, чем быстрее падали (от порога повыше).
			if _fall_speed > LAND_SWAY_SPEED:
				var dir := signf(state.linear_velocity.x)
				if absf(dir) < 0.01:
					dir = 1.0 if randf() < 0.5 else -1.0
				_sway_vel += dir * minf(_fall_speed / 800.0, 1.0) * sway_max * 6.0
			# Подскок с жёстким ограничением числа: 1–2 раза от заметного
			# падения, каждый слабее (bounce_strength < 1), дальше специя
			# ложится — без бесконечного дребезга у дна.
			if _bounce_count < max_bounces:
				state.linear_velocity.y = -_fall_speed * bounce_strength
				_bounce_count += 1
			else:
				state.linear_velocity.y = 0.0
			_fall_speed = 0.0
		else:
			_fall_speed = maxf(vy, 0.0)
		# На поверхности специя не скользит: гасим горизонтальную скорость,
		# чтобы она осталась там, куда упала. Покачивание — это наклон
		# (угловой осциллятор), его это не трогает.
		if state.get_contact_count() > 0:
			state.linear_velocity.x = 0.0
	else:
		_fall_speed = 0.0
		_bounce_count = 0
	# Демпфированный осциллятор к целевому наклону, зажатый в ±sway_max.
	var accel := (_sway_target - _sway) * sway_stiffness - _sway_vel * sway_damping
	_sway_vel += accel * step
	_sway += _sway_vel * step
	if _sway > sway_max:
		_sway = sway_max
		_sway_vel = minf(_sway_vel, 0.0)
	elif _sway < -sway_max:
		_sway = -sway_max
		_sway_vel = maxf(_sway_vel, 0.0)
	# Ставим ориентацию телу вручную, сохраняя позицию, посчитанную физикой.
	state.transform = Transform2D(_sway, state.transform.origin)
	state.angular_velocity = 0.0
	queue_redraw()


# --- Отрисовка ---

func _draw() -> void:
	var r := effective_radius(model)
	if show_shadow:
		# Тень-силуэт под специей: смещение вниз в экранных координатах,
		# поворот тела компенсируется.
		draw_set_transform(Vector2(0.0, 5.0).rotated(-rotation), 0.0, Vector2.ONE)
		_draw_shadow(r)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_body(r)
	if _dragging:
		_draw_grab_outline(Color(0.98, 0.95, 0.7, 0.9), 3.0)


func _draw_shadow(r: float) -> void:
	if model.texture != null:
		draw_texture_rect(model.texture, _tex_box, false, shadow_color)
	else:
		draw_circle(Vector2.ZERO, r, shadow_color)


func _draw_body(r: float) -> void:
	if model.texture != null:
		draw_texture_rect(model.texture, _tex_box, false)
	else:
		draw_circle(Vector2.ZERO, r, model.color)
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 32, Color(0.1, 0.1, 0.12), 2.0)


## Обводка захвата — по контуру силуэта PNG (там же, где коллизия и область
## захвата мышью); без изображения — окружность радиуса.
func _draw_grab_outline(outline_color: Color, width: float) -> void:
	if _outline_polys.is_empty():
		draw_arc(Vector2.ZERO, effective_radius(model) + 2.0, 0.0, TAU, 32, outline_color, width)
		return
	for outline in _outline_polys:
		var points := outline as PackedVector2Array
		if points.size() < 3:
			continue
		var closed := points.duplicate()
		closed.append(closed[0])
		draw_polyline(closed, outline_color, width)
