## Физический ингредиент на столе боя.
##
## Полностью повторяет поведение DragSquare из песочницы: пружинное
## перетаскивание за точку захвата (сила приложена к точке — ингредиент
## доворачивается), эффект высыпания сверху с тенью, следом-призраками
## и подскоками, ограничитель скорости. Вместо квадрата рисуется
## изображение ингредиента ([member IngredientModel.texture]) с коллизией
## точно по непрозрачным пикселям PNG: за силуэт можно схватить мышью,
## и объекты соприкасаются ровно по видимым пикселям картинки;
## пока изображения нет — фигура model.shape цвета model.color.
##
## Тень полностью повторяет силуэт объекта: текстура тени
## ([member IngredientModel.shadow_texture]), затемнённое изображение
## или фигура той же формы — и вращается вместе с телом.
##
## Поверх — боевые состояния: застывший на месте (locked/вечный)
## и замороженный после нуля таймера (frozen), выжигание ([method burn_away] —
## растворение по шейдеру от точки) и подсчёт ([method play_score_hit] — тряска
## с миганием; подпись с долей звезды рисует оверлей [CombatScoreLabels],
## чтобы цифры всегда были поверх всего).
##
## Отдельное состояние — клей ([member glued]): липкий ингредиент
## ([constant IngredientModel.Effect.STICKY], горох) катается по столу как
## обычный, пока не врежется в любую стену стола, — вот тогда он прилипает и
## коротко моргает белым. Как он туда попал, значения не имеет: докатился сам,
## его запустил игрок, толкнул сосед или сдвинул тесак. Только с этого момента
## он приклеивает к себе всё, что его коснётся; приклеенное тоже становится
## частью комка и клеит дальше.
## Приклеенное стоит на месте до конца раунда: его не сдвинуть тесаком и не
## утащить крюком или щипцами. Рука игрока — исключение: любое приклеенное
## можно взять, и захват его отклеивает ([method start_drag]); дальше оно
## живёт обычной физикой и приклеится снова, если опять попадёт на комок
## (а горох — если врежется в стену).
class_name IngredientNode
extends RigidBody2D

signal landed

## До какого радиуса гнать шейдер выжигания: самая далёкая точка бокса
## отрисовки лежит на sqrt(2) в UV, плюс искажение шумом — 2 хватает,
## чтобы выгорело всё изображение.
const BURN_MAX_RADIUS := 2.0

## Слой стола: на нём лежат стены боя и сами ингредиенты. Липкая область
## слушает только его — фишки корзин, специи и товары магазина на своих слоях,
## и клей их не касается.
const TABLE_LAYER := 1

## Насколько липкая область шире тела: в физике тела соприкасаются вплотную,
## а область должна их доставать с запасом.
const STICKY_AREA_GROW := 1.08

## Сколько секунд отодранное рукой не приклеивается снова, с: рука должна
## успеть увезти его от стены или от комка, иначе оно приклеится обратно тем же
## кадром и отодрать его будет нельзя. Как только игрок отпустил — пауза
## кончается ([method end_drag]).
const GLUE_PEEL_COOLDOWN := 0.5

## Пока true, ингредиенты стола не отдают подсказку при наведении
## ([method tooltip_model]) — на весь стол сразу. Ставит режим боя на время
## раунда, если так настроен враг ([member EnemyModel.hides_field_tooltips]);
## фишек корзин, мешка и специй флаг не касается.
static var tooltips_hidden := false

var model: IngredientModel
## Визуальная тема боя (цвета тени, обводок, заморозки, подписей).
var theme: CombatTheme
## Высыпал ли этот ингредиент игрок (подсчёт всё равно идёт по позиции).
var from_player := false
## Заморожен после нуля таймера: физика и перетаскивание выключены.
var frozen := false
## Держится клеем: сам горох, прилипший к стене, или всё, что приклеилось
## к комку. Стоит на месте до конца раунда и клеит к себе соседей.
var glued := false
## Неуязвимый: трогать нельзя вовсе — ни рукой, ни инструментом, ни соседями
## по столу; сам объект затемнён ([member CombatTheme.untouchable_tint]),
## а над ним висит красная подпись ([member CombatTheme.untouchable_label]).
## Это флаг узла, а не модели: неуязвима первая бутылка водки за бой, а не
## водка как ингредиент (ставит режим боя при высыпании).
var untouchable := false
## Лежит на половине врага, и рука его оттуда не возьмёт: затемнён так же,
## как неуязвимый ([member CombatTheme.untouchable_tint]). Ставит режим боя
## каждый тик по положению; с инструментом, которому половина врага доступна
## (удочка), затемнение гаснет — брать снова можно.
var grab_blocked := false
## Подсветка при подсчёте (0..1, гаснет сама).
var highlight := 0.0

var drag_stiffness := 60.0          # жёсткость "пружины" между точкой захвата и целью
var max_stretch := 300.0            # ограничение растяжения пружины
var max_speed := 1400.0             # предохранитель от туннелирования сквозь стены
var drag_inertia := 0.6             # 0 = жёстко липнет к курсору, 1 = свободно раскачивается
var drop_gravity := 2600.0          # ускорение "высыпания", px/s^2 (фейковая высота)
var drop_bounce := 0.3              # доля скорости, сохраняемая при подскоке

## Кэш формы по альфе изображения: модель ->
## {"convex": выпуклые части силуэта, "outlines": контуры силуэта}.
static var _texture_shape_cache := {}

## Бокс отрисовки изображения: центр в нуле, пропорции PNG сохранены
## (длинная сторона = radius * 2).
var _tex_box := Rect2()
## Контуры силуэта изображения для обводки (координаты бокса отрисовки).
var _outline_polys := []

var _dragging := false
var _grab_local := Vector2.ZERO     # точка захвата в локальных координатах
var _air_height := 0.0              # высота над столом в пикселях (0 = лежит)
var _air_velocity := 0.0            # скорость падения, px/s (положительная = вниз)
var _air_start_height := 1.0
var _air_tilt := 0.0                # наклон в полёте; гаснет к касанию
var _airborne := false              # true до первого касания: физика выключена
var _drop_delay := 0.0              # очередь в каскаде: ингредиент ждёт невидимым
var _flying := false                # перелёт по дуге (fly_in) вместо падения сверху
var _fly_time := 0.0                # отрицательное — очередь в каскаде перелёта
var _fly_duration := 0.0
var _fly_from := Vector2.ZERO
var _fly_target := Vector2.ZERO
var _fly_arc := 0.0
var _fly_spin := 0.0                # кувырок в полёте, рад/с
var _collisions: Array[Node2D] = []
## Область клея: силуэт тела с запасом. Есть у липкого с самого появления
## и у всего, что приклеилось к комку; у остальных null.
var _sticky_area: Area2D = null
## Пауза после отдирания, с: пока тикает, липкий не прилипает к стене снова
## ([constant GLUE_PEEL_COOLDOWN]). Отпустил игрок — пауза кончилась.
var _glue_cooldown := 0.0
## Тело ударилось о стену: приклеить его на ближайшем тике. Во время шага
## физики (там приходит сигнал удара) заморозку менять нельзя.
var _glue_pending := false


static func create(ingredient: IngredientModel, config: CombatConfig,
		visual_theme: CombatTheme = null) -> IngredientNode:
	var node := IngredientNode.new()
	node.model = ingredient
	node.theme = visual_theme if visual_theme != null else CombatTheme.new()
	node.drag_stiffness = config.drag_stiffness
	node.max_stretch = config.max_stretch
	node.max_speed = config.max_speed
	node.drag_inertia = config.drag_inertia
	node.mass = 0.8 + ingredient.weight * 0.25
	node._tex_box = texture_box(ingredient)

	for collision in _build_collisions(ingredient):
		node.add_child(collision)
		node._collisions.append(collision)
	if ingredient.texture != null and ingredient.texture_collision:
		node._outline_polys = _shape_data_for(ingredient)["outlines"]

	node.gravity_scale = 0.0        # вид сверху: ингредиенты скользят, а не падают
	node.linear_damp = config.slide_damp
	# Сопротивление вращения 0..1 -> угловое затухание, как в песочнице.
	node.angular_damp = config.rotation_resistance * float(Engine.physics_ticks_per_second)
	node.continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	# Упругость контакта — сумма bounce обоих тел (с обрезкой до 1.0):
	# ингредиент и стена несут по половине настроенной упругости.
	var material := PhysicsMaterial.new()
	material.friction = config.ingredient_friction
	material.bounce = config.elasticity / 2.0
	node.physics_material_override = material
	# Липкий носит область клея с самого начала и слушает удары тела: прилипнуть
	# он должен от любого касания стены — и когда докатился сам, и когда его
	# запустил игрок. Область ловит контакт, который длится (лежит у стены),
	# сигнал удара — короткий, на отскоке.
	if ingredient.is_sticky():
		node._add_sticky_area()
		node.contact_monitor = true
		node.max_contacts_reported = 4
		node.body_entered.connect(node._on_body_hit)
	return node


## Коллизия ингредиента: по непрозрачным пикселям изображения (альфа PNG),
## иначе — по фигуре shape/radius. Силуэт разбивается на выпуклые части
## (RigidBody2D не работает с вогнутыми формами), поэтому вогнутости —
## ботва, выемки — остаются свободными и объекты соприкасаются ровно
## по видимым пикселям картинки.
static func _build_collisions(ingredient: IngredientModel) -> Array[Node2D]:
	var result: Array[Node2D] = []
	if ingredient.texture != null and ingredient.texture_collision:
		for points in _shape_data_for(ingredient)["convex"]:
			var shape := ConvexPolygonShape2D.new()
			shape.points = points
			var collision := CollisionShape2D.new()
			collision.shape = shape
			result.append(collision)
	if not result.is_empty():
		return result
	var collision := CollisionShape2D.new()
	if ingredient.shape == IngredientModel.ShapeKind.SQUARE:
		var rect := RectangleShape2D.new()
		rect.size = Vector2.ONE * ingredient.radius * 2.0
		collision.shape = rect
	else:
		var circle := CircleShape2D.new()
		circle.radius = ingredient.radius
		collision.shape = circle
	result.append(collision)
	return result


## Бокс отрисовки изображения: вписан в квадрат 2r x 2r с сохранением
## пропорций PNG (длинная сторона = 2r), центр в нуле. Для моделей без
## изображения — квадрат фигуры. Публичный: этим же размером ингредиент
## рисуют и вне стола ([RewardScreen] — в свою настоящую величину),
## как [method SpiceNode.texture_box] у специй.
static func texture_box(ingredient: IngredientModel) -> Rect2:
	var r := ingredient.radius
	var box := Rect2(-r, -r, r * 2.0, r * 2.0)
	if ingredient.texture == null:
		return box
	var tex_size := ingredient.texture.get_size()
	var longest := maxf(tex_size.x, tex_size.y)
	if longest <= 0.0:
		return box
	var size := tex_size * (r * 2.0 / longest)
	return Rect2(-size * 0.5, size)


## Силуэт изображения для сторонних узлов (фишки ёмкостей): те же
## выпуклые части и контуры, что у ингредиента на столе, из общего кэша.
static func silhouette_for(ingredient: IngredientModel) -> Dictionary:
	return _shape_data_for(ingredient)


## Форма по альфе изображения: контуры непрозрачных пикселей, приведённые
## к боксу отрисовки (см. [method texture_box]), и их разбивка на выпуклые
## части для физики. Считается один раз на модель и кэшируется.
static func _shape_data_for(ingredient: IngredientModel) -> Dictionary:
	if _texture_shape_cache.has(ingredient):
		return _texture_shape_cache[ingredient]
	var data := {"convex": [], "outlines": []}
	var image := ingredient.texture.get_image()
	if image != null and not image.is_empty():
		if image.is_compressed():
			image.decompress()
		var bitmap := BitMap.new()
		bitmap.create_from_image_alpha(image)
		var size := bitmap.get_size()
		var box := texture_box(ingredient)
		var scale_factor := box.size / Vector2(size)
		# Упрощение контура: ~1.5 пикселя экрана в пикселях исходника —
		# форма следует картинке без лишних вершин.
		var epsilon := maxf(2.0,
				float(maxi(size.x, size.y)) * 1.5 / (ingredient.radius * 2.0))
		for source in bitmap.opaque_to_polygons(Rect2i(Vector2i.ZERO, size), epsilon):
			if source.size() < 3:
				continue
			var outline := PackedVector2Array()
			for point in source:
				outline.append(point * scale_factor + box.position)
			data["outlines"].append(outline)
			data["convex"].append_array(_convex_parts(outline))
	_texture_shape_cache[ingredient] = data
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


## Что показать в подсказке при наведении ([HoverTooltip]): сам ингредиент.
## Пока подсказки стола спрятаны ([member tooltips_hidden]) — ничего:
## ингредиент под курсором есть, а что он даёт, не видно.
func tooltip_model() -> Resource:
	return null if tooltips_hidden else model


## Можно ли схватить ингредиент мышью. Правило области врага проверяет
## режим боя — здесь только собственные ограничения.
## Приклеенное клей держит от всего, кроме руки: любое приклеенное можно взять,
## и захват его отклеивает ([method start_drag]).
func can_be_grabbed() -> bool:
	return not frozen and not _airborne and is_movable()


## Можно ли вообще двигать этот ингредиент: модель разрешает (не locked и не
## вечный) и он не неуязвим. Этим правилом мерят и рука, и инструменты,
## и способности врага.
func is_movable() -> bool:
	return model.is_movable() and not untouchable


## Остановить ингредиент на месте: гасит скорость и вращение, оставляя его
## там, где он лежит. Нужно везде, где движение обрывается насильно: после
## удара тесака стол замирает, а схваченное щипцами не должно уехать по старой
## инерции, когда его отпустят (заморозка тела скорость не стирает — она
## оживает в момент разморозки).
func stop() -> void:
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0


## Замереть намертво там, где стоишь: [method stop] гасит только скорость,
## а уже поданные за этот кадр силы (пружина крюка, толчок соседа) всё равно
## успевают протащить тело ещё немного. Выключенное тело их просто теряет,
## поэтому ингредиент встаёт ровно в той точке, где его отпустили.
## Обратно в физику — [method wake].
func hold_still() -> void:
	stop()
	freeze = true


## Снова жить обычной физикой после [method hold_still] — с нулевой скоростью,
## то есть с места. Замороженное на подсчёт, приклеенное, летящее
## и неподвижное (locked/вечное) остаётся выключенным.
func wake() -> void:
	stop()
	if frozen or glued or _airborne or not is_movable():
		return
	freeze = false
	# Заморозка скорость не стирает — она оживает вместе с телом, поэтому
	# гасим ещё раз уже после разморозки.
	stop()


func set_frozen(value: bool) -> void:
	frozen = value
	if frozen:
		_dragging = false
		freeze = true
	elif is_movable() and not _airborne and not glued:
		freeze = false


# --- Клей липкого ингредиента (горох) ---

## Клей комка поймал ингредиент: он застывает там, где его прижало, и сам
## становится частью комка — дальше клеит уже всё, что коснётся его.
## Летящий, неподвижный (locked/вечный) и уже приклеенный не клеятся; только
## что отодранный рукой — тоже, пока рука не увезёт его от комка
## ([constant GLUE_PEEL_COOLDOWN]).
func glue() -> void:
	if glued or _airborne or not is_movable() or _glue_cooldown > 0.0:
		return
	_glue_in_place()


func _glue_in_place() -> void:
	glued = true
	_dragging = false
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	freeze = true
	_add_sticky_area()
	# Короткое моргание белым — видно, что клей сработал именно сейчас.
	play_score_hit(theme.score_hit_material, theme.glue_flash_duration,
			theme.glue_flash_color)
	queue_redraw()


## Отодрать приклеенный: тело снова живёт обычной физикой и приклеится опять,
## только если снова попадёт на клей. Зовётся, когда игрок берёт приклеенное
## мышью ([method start_drag]).
func _unglue() -> void:
	if not glued:
		return
	glued = false
	freeze = frozen or not is_movable()
	# Рука ещё держит его у той самой стены (или у комка) — дать ей время
	# увезти добычу, иначе она приклеится обратно тем же кадром.
	_glue_cooldown = GLUE_PEEL_COOLDOWN
	queue_redraw()


## Область клея: копия силуэта тела, чуть шире его самого. Слушает только
## слой стола ([constant TABLE_LAYER]) и сама никем не ловится.
func _add_sticky_area() -> void:
	if _sticky_area != null:
		return
	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask = TABLE_LAYER
	area.monitorable = false
	area.scale = Vector2.ONE * STICKY_AREA_GROW
	for collision in _build_collisions(model):
		area.add_child(collision)
	add_child(area)
	_sticky_area = area


## Шаг клея: приклеенный комок клеит всё, что его касается, а сам липкий ловит
## стену стола. Перекрытия проверяются каждый тик, а не по сигналу входа: сосед
## мог прижаться к комку раньше, чем тот прилип, и события входа для этой пары
## уже не будет.
func _process_sticky(delta: float) -> void:
	if _glue_cooldown > 0.0:
		_glue_cooldown = maxf(_glue_cooldown - delta, 0.0)
	if glued:
		_glue_pending = false
		for body in _sticky_area.get_overlapping_bodies():
			var other := body as IngredientNode
			if other != null and other != self:
				other.glue()
		return
	# До стены липкий ничего не клеит — он обычный ингредиент. Летящий не
	# липнет тем более: его тело ещё не на столе.
	if not model.is_sticky() or _airborne or _flying or _glue_cooldown > 0.0:
		_glue_pending = false
		return
	# Удар о стену на прошлом тике: быстрый бросок отскакивает от стены раньше,
	# чем область успеет заметить перекрытие, — его ловит сигнал удара.
	if _glue_pending:
		_glue_pending = false
		_glue_in_place()
		return
	for body in _sticky_area.get_overlapping_bodies():
		# Липнет только к стене стола: об соседей горох не застревает.
		if body is IngredientNode:
			continue
		_glue_in_place()
		return


## Тело обо что-то ударилось. Липкий прилипает к любой стене стола — не важно,
## докатился он сам, запустил его игрок или сдвинул тесак; ингредиенты стеной
## не считаются. Клеим не здесь: сигнал приходит посреди шага физики, а менять
## там заморозку тела нельзя — удар запоминается и срабатывает ближайшим тиком
## ([method _process_sticky]).
func _on_body_hit(body: Node) -> void:
	if glued or _airborne or _flying or _glue_cooldown > 0.0:
		return
	if body is IngredientNode:
		return
	_glue_pending = true


## Щипцы врага сомкнулись на ингредиенте ([TongsNode]): он застывает,
## становится неосязаемым и дальше едет за губками ([method hold_move]),
## рисуясь над столом, но под самими щипцами.
func hold_begin(carry_z := 94) -> void:
	# Схваченный замирает совсем: без этого скорость переживает заморозку и
	# оживает при приземлении — ингредиент уезжает обратно, откуда его взяли.
	stop()
	set_frozen(true)
	_set_collisions_disabled(true)
	z_index = carry_z


## Ингредиент едет за губками щипцов.
func hold_move(to_global: Vector2) -> void:
	global_position = to_global


## Щипцы разжались: ингредиент падает с высоты height на своё место —
## дальше как обычное высыпание, с подскоками ([method drop_in]).
func hold_release(height: float, gravity := 2600.0, bounce := 0.3) -> void:
	set_frozen(false)
	drop_in(height, 0.0, gravity, bounce)


## Выжечь ингредиент: он растворяется шейдером «сгорая от точки» и убирается
## со стола. origin_uv — точка начала выжигания в UV бокса отрисовки (0..1):
## у горелки игрока это точка клика, у врага — край, обращённый к его половине.
## Пока идёт растворение, ингредиент заморожен, чтобы его не сдвинули.
## Без материала (или с нулевой длительностью) ингредиент просто исчезает.
func burn_away(burn_material: ShaderMaterial, duration := 1.5,
		origin_uv := Vector2(0.5, 0.5)) -> void:
	set_frozen(true)
	if burn_material == null or duration <= 0.0:
		queue_free()
		return
	# Материал у каждого горящего свой: точка и радиус выжигания — его личные.
	var burn := burn_material.duplicate() as ShaderMaterial
	burn.set_shader_parameter("position", origin_uv)
	burn.set_shader_parameter("radius", 0.0)
	material = burn
	var tween := create_tween()
	tween.tween_method(_set_burn_radius.bind(burn), 0.0, BURN_MAX_RADIUS, duration)
	await tween.finished
	queue_free()


func _set_burn_radius(value: float, burn: ShaderMaterial) -> void:
	burn.set_shader_parameter("radius", value)


## Эффект подсчёта: ингредиент дрожит и мигает цветом flash_color (шейдер
## «trigger hit effect»). Эффект живёт сам — ждать его не нужно, подсчёт идёт
## своим шагом. Подпись с долей звезды показывает оверлей [CombatScoreLabels].
func play_score_hit(hit_material: ShaderMaterial, duration: float,
		flash_color: Color) -> void:
	if hit_material == null or duration <= 0.0:
		return
	# Материал у каждого свой: цвет вспышки и сила эффекта — его личные.
	var hit := hit_material.duplicate() as ShaderMaterial
	hit.set_shader_parameter("get_hit", true)
	hit.set_shader_parameter("flash_color", flash_color)
	hit.set_shader_parameter("hit_effect", 1.0)
	material = hit
	var tween := create_tween()
	tween.tween_method(_set_hit_effect.bind(hit), 1.0, 0.0, duration)
	tween.finished.connect(_clear_hit_material.bind(hit))


func _set_hit_effect(value: float, hit: ShaderMaterial) -> void:
	hit.set_shader_parameter("hit_effect", value)


## Снять материал попадания — но только если поверх не встал другой
## (например выжигание сразу после подсчёта).
func _clear_hit_material(hit: ShaderMaterial) -> void:
	if material == hit:
		material = null


## UV точки стола в боксе отрисовки этого ингредиента (0..1, с обрезкой по
## краям) — начало выжигания для [method burn_away]. Точка снаружи прижимается
## к ближней кромке изображения, так что огонь идёт с той стороны.
func uv_at_global(point: Vector2) -> Vector2:
	if _tex_box.size.x <= 0.0 or _tex_box.size.y <= 0.0:
		return Vector2(0.5, 0.5)
	var local := to_local(point) - _tex_box.position
	return Vector2(
			clampf(local.x / _tex_box.size.x, 0.0, 1.0),
			clampf(local.y / _tex_box.size.y, 0.0, 1.0))


func is_airborne() -> bool:
	return _airborne


func is_dragging() -> bool:
	return _dragging


## Схватить за точку global_point — пружина будет тянуть за неё,
## доворачивая тело, как у DragSquare. Приклеенное рука отдирает: в руке оно
## снова обычное тело и приклеится опять, только если снова попадёт на клей.
func start_drag(global_point: Vector2) -> void:
	if glued:
		_unglue()
	_dragging = true
	_grab_local = to_local(global_point)


## Рука отпустила. Пауза после отдирания на этом кончается: брошенный горох
## прилипает к первой же стене, в которую влетит, — как и любой другой.
func end_drag() -> void:
	_dragging = false
	_glue_cooldown = 0.0


func grab_point_global() -> Vector2:
	return to_global(_grab_local)


## Пружина с демпфером к точке target (курсор + смещение при групповом
## захвате). Жёсткость не зависит от массы: тяжёлые ингредиенты
## разгоняются медленнее. Сила приложена к точке захвата.
func apply_drag_force(target: Vector2) -> void:
	var grab_global := grab_point_global()
	var stretch := target - grab_global
	if stretch.length() > max_stretch:
		stretch = stretch.normalized() * max_stretch
	var damping_ratio := lerpf(0.9, 0.08, drag_inertia)
	var damping := 2.0 * damping_ratio * sqrt(drag_stiffness * mass)
	var force := drag_stiffness * stretch - damping * linear_velocity
	apply_force(force, grab_global - global_position)


## Высыпание: тело стоит в точке приземления с выключенной физикой,
## а рисуется выше на _air_height; под ним лежит тень. Касание включает
## физику, остаток — затухающие подскоки.
func drop_in(start_height: float, delay := 0.0, gravity := 2600.0, bounce := 0.3) -> void:
	if start_height <= 0.0 or gravity <= 0.0:
		_after_landing()
		return
	drop_gravity = gravity
	drop_bounce = clampf(bounce, 0.0, 0.9)
	_air_start_height = start_height
	_air_height = start_height
	_air_velocity = 0.0
	_air_tilt = randf_range(-0.35, 0.35)
	_drop_delay = delay
	_airborne = true
	freeze = true
	_set_collisions_disabled(true)
	z_index = 50                    # летящий рисуется поверх лежащих
	visible = delay <= 0.0


## Подскок на месте: тело остаётся на столе, в физике и на своём месте —
## подлетает только изображение с тенью, тем же поддельным «воздухом», что и
## при высыпании, и падает обратно с затухающими подскоками. Так удар тесака
## минибосса ([CleaverNode]) встряхивает стол: подпрыгивает всё, чего не
## задело лезвие. Летящему и высыпающемуся подскок не мешает — он молчит.
func hop(height: float, gravity := 2600.0, bounce := 0.3) -> void:
	if height <= 0.0 or gravity <= 0.0 or _airborne or _flying or untouchable:
		return
	drop_gravity = gravity
	drop_bounce = clampf(bounce, 0.0, 0.9)
	_drop_delay = 0.0
	_air_start_height = height
	_air_height = 0.0
	# Толчок снизу вверх: такой скорости хватает ровно на height.
	_air_velocity = -sqrt(2.0 * gravity * height)
	_air_tilt = randf_range(-0.25, 0.25)


func _physics_process(delta: float) -> void:
	# Тень зависит от поворота тела — перерисовываем каждый тик.
	queue_redraw()
	if _flying:
		_step_fly(delta)
	elif _airborne or _air_height > 0.0 or _air_velocity != 0.0:
		_step_drop(delta)
	if _sticky_area != null:
		_process_sticky(delta)
	if highlight > 0.0:
		highlight = maxf(highlight - delta * 1.4, 0.0)
	if linear_velocity.length() > max_speed:
		linear_velocity = linear_velocity.normalized() * max_speed


## Перелёт из точки from_global в текущую позицию (точку приземления):
## тело летит по прямой, рисуется поднятым по параболе — дуга полёта,
## с кувырком. Пока объект ждёт очереди (delay), он не заморожен, но
## неосязаем — с места его никто не сдвинет; замораживается объект
## только на время самого полёта и стартует ровно с той позиции, где
## стоял. В момент касания включаются физика и коллизия стола, остаток
## вертикальной скорости уходит в затухающие подскоки, как у
## [method drop_in].
func fly_in(from_global: Vector2, duration: float, arc_height: float,
		delay := 0.0, gravity := 2600.0, bounce := 0.3) -> void:
	if duration <= 0.0:
		_after_landing()
		return
	drop_gravity = gravity
	drop_bounce = clampf(bounce, 0.0, 0.9)
	_fly_from = from_global
	_fly_target = global_position
	_fly_duration = duration
	_fly_time = -delay
	_fly_arc = maxf(arc_height, 0.0)
	_fly_spin = randf_range(-6.0, 6.0)
	_air_start_height = maxf(arc_height, 1.0)
	_air_height = 0.0
	_air_velocity = 0.0
	_air_tilt = randf_range(-0.35, 0.35)
	_flying = true
	_airborne = true
	# Ожидающий очереди не заморожен, но неосязаем: коллизия выключена,
	# чтобы соседи не сдвигали его с места, — положение не меняется до
	# самого старта полёта.
	freeze = false
	_set_collisions_disabled(true)
	# Вылетающий из корзины рисуется поверх лежащих ингредиентов и самих
	# корзин (панель — z 90, фишки — 91), но под HUD (z 100).
	z_index = 95
	global_position = from_global
	visible = true


func _step_fly(delta: float) -> void:
	_fly_time += delta
	if _fly_time <= 0.0:
		return
	if not freeze:
		# Очередь дошла: тело замораживается на время полёта и стартует
		# ровно с той позиции, где стояло.
		freeze = true
		_fly_from = global_position
	var t := clampf(_fly_time / _fly_duration, 0.0, 1.0)
	global_position = _fly_from.lerp(_fly_target, t)
	# Дуга: высота по параболе с пиком в середине перелёта, с кувырком.
	_air_height = 4.0 * _fly_arc * t * (1.0 - t)
	rotation += _fly_spin * delta
	if t < 1.0:
		return
	_flying = false
	_airborne = false
	_air_height = 0.0
	# Скорость снижения в конце дуги уходит в затухающие подскоки.
	_air_velocity = -(4.0 * _fly_arc / _fly_duration) * drop_bounce
	if absf(_air_velocity) < 60.0:
		_air_velocity = 0.0
	_after_landing()


func _step_drop(delta: float) -> void:
	if _drop_delay > 0.0:
		_drop_delay -= delta
		if _drop_delay > 0.0:
			return
		visible = true
	_air_velocity += drop_gravity * delta
	_air_height -= _air_velocity * delta
	if _air_height <= 0.0:
		_air_height = 0.0
		if _airborne:
			_airborne = false
			_after_landing()
		_air_velocity = -_air_velocity * drop_bounce
		if absf(_air_velocity) < 60.0:
			_air_velocity = 0.0


## Первое касание стола: ингредиент снова осязаем; неподвижные (locked/вечные)
## сразу застывают на месте — их нельзя ни двигать, ни выбивать.
func _after_landing() -> void:
	_set_collisions_disabled(false)
	z_index = 0
	visible = true
	# Приземлившийся лежит: скорость, накопленная до полёта, не должна
	# оживать вместе с физикой и увозить его с места падения.
	stop()
	freeze = not is_movable() or frozen
	landed.emit()


# --- Отрисовка ---

func _draw() -> void:
	var r := model.radius
	# Тень-силуэт: полностью повторяет объект и вращается вместе с ним;
	# у летящего — пятно в точке приземления, уезжающее чуть в сторону.
	var shadow_offset := Vector2(-_air_height * 0.1, 4.0).rotated(-rotation)
	draw_set_transform(shadow_offset, 0.0, Vector2.ONE)
	_draw_shadow(r)
	# Тело "в воздухе" рисуется выше точки приземления; на скорости за ним
	# тянется призрачный след из прежних положений.
	var up_local := Vector2.UP.rotated(-rotation)
	_draw_trail_ghost(r, 0.09, 0.1, up_local)
	_draw_trail_ghost(r, 0.045, 0.22, up_local)
	draw_set_transform(up_local * _air_height, _tilt_at(_air_height), Vector2.ONE)
	_draw_body(r)
	if untouchable:
		_draw_untouchable_label(r, up_local)


func _set_collisions_disabled(value: bool) -> void:
	for collision in _collisions:
		collision.set("disabled", value)


## Наклон в полёте: максимален наверху, к касанию стола сходит на нет.
func _tilt_at(height: float) -> float:
	if _air_start_height <= 0.0:
		return 0.0
	return _air_tilt * clampf(height / _air_start_height, 0.0, 1.0)


func _draw_trail_ghost(r: float, lag: float, alpha: float, up_local: Vector2) -> void:
	if absf(_air_velocity) < 500.0:
		return
	# Где ингредиент был lag секунд назад (при подскоке след снизу).
	var ghost_height := _air_height + _air_velocity * lag
	if ghost_height <= 0.0:
		return
	draw_set_transform(up_local * ghost_height, _tilt_at(ghost_height), Vector2.ONE)
	if model.texture != null:
		draw_texture_rect(model.texture, _tex_box, false, Color(1.0, 1.0, 1.0, alpha))
	else:
		_draw_shape(r, Color(model.color, alpha))
		_draw_outline(r, Color(0.1, 0.1, 0.12, alpha), 3.0)


func _draw_shadow(r: float) -> void:
	if model.shadow_texture != null:
		draw_texture_rect(model.shadow_texture, _tex_box, false)
	elif model.texture != null:
		# Силуэт изображения, залитый цветом тени.
		draw_texture_rect(model.texture, _tex_box, false, theme.ingredient_shadow)
	else:
		_draw_shape(r, theme.ingredient_shadow)


func _draw_body(r: float) -> void:
	if model.texture != null:
		draw_texture_rect(model.texture, _tex_box, false)
	else:
		_draw_shape(r, model.color)
		var outline := theme.ingredient_outline
		if model.permanent:
			outline = theme.permanent_outline
		elif model.locked:
			outline = theme.locked_outline
		_draw_outline(r, outline, 3.0)
	if untouchable or grab_blocked:
		_draw_darken(theme.untouchable_tint, r)
	if glued:
		_draw_grab_outline(theme.glue_outline, 3.0, r + 2.0)
	if _dragging:
		_draw_grab_outline(theme.drag_outline, 3.0, r + 2.0)
	if highlight > 0.0:
		_draw_grab_outline(Color(theme.score_highlight, highlight), 4.0, r + 5.0)
	if frozen:
		if model.texture != null:
			# Иней по силуэту: изображение, тонированное цветом заморозки.
			draw_texture_rect(model.texture, _tex_box, false, theme.frozen_tint)
		else:
			_draw_shape(r, theme.frozen_tint)
	# Подпись и метка вечного.
	var font := ThemeDB.fallback_font
	if theme.show_ingredient_labels:
		var text_color := theme.label_text_dark if model.color.get_luminance() > 0.5 \
				else theme.label_text_light
		draw_string(font, Vector2(-r * 2.0, 4.0), model.display_name,
				HORIZONTAL_ALIGNMENT_CENTER, r * 4.0,
				theme.ingredient_label_font_size, text_color)
	if model.permanent:
		draw_string(font, Vector2(-r, -r - 4.0), "∞",
				HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, 13, theme.permanent_mark_color)


## Подпись над неуязвимым: небольшая красная надпись из темы, с тёмной
## подложкой на пиксель — иначе на светлом столе она теряется. Держится
## горизонтально, как бы объект ни лежал: поворот тела для неё отменяется,
## а место считается в экранных осях (up_local — «вверх» экрана в локальных
## координатах, оно же поднимает подпись вместе с подскоком).
func _draw_untouchable_label(r: float, up_local: Vector2) -> void:
	if theme.untouchable_label == "":
		return
	var label_font := UiFont.resolve()
	var size := theme.untouchable_label_font_size
	var box := maxf(r * 4.0, 90.0)
	draw_set_transform(up_local * (_air_height + r + 8.0), -rotation, Vector2.ONE)
	var at := Vector2(-box * 0.5, 0.0)
	draw_string(label_font, at + Vector2.ONE, theme.untouchable_label,
			HORIZONTAL_ALIGNMENT_CENTER, box, size, theme.untouchable_label_shadow)
	draw_string(label_font, at, theme.untouchable_label,
			HORIZONTAL_ALIGNMENT_CENTER, box, size, theme.untouchable_label_color)


func _draw_shape(r: float, shape_color: Color) -> void:
	if model.shape == IngredientModel.ShapeKind.SQUARE:
		draw_rect(Rect2(-r, -r, r * 2.0, r * 2.0), shape_color)
	else:
		draw_circle(Vector2.ZERO, r, shape_color)


func _draw_outline(r: float, outline_color: Color, width: float) -> void:
	if model.shape == IngredientModel.ShapeKind.SQUARE:
		draw_rect(Rect2(-r, -r, r * 2.0, r * 2.0), outline_color, false, width)
	else:
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 32, outline_color, width)


## Затемнение недоступного: то же изображение поверх, умноженное на тёмный
## цвет, — гаснет ровно по пикселям PNG, поэтому без ореолов по упрощённому
## контуру коллизии. Без изображения — фигура, залитая тем же цветом.
func _draw_darken(tint: Color, fallback_r: float) -> void:
	if model.texture != null:
		draw_texture_rect(model.texture, _tex_box, false, tint)
	else:
		_draw_shape(fallback_r, tint)


## Обводка захвата/подсветки: по контуру силуэта изображения — там же,
## где коллизия и область захвата мышью; без изображения — прежняя рамка
## радиуса fallback_r вокруг фигуры.
func _draw_grab_outline(outline_color: Color, width: float, fallback_r: float) -> void:
	if _outline_polys.is_empty():
		_draw_outline(fallback_r, outline_color, width)
		return
	for outline in _outline_polys:
		var points := outline as PackedVector2Array
		if points.size() < 3:
			continue
		var closed := points.duplicate()
		closed.append(closed[0])
		draw_polyline(closed, outline_color, width)
