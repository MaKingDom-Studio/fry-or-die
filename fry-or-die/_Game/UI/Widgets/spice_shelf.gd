@tool
## Полка специй: заранее заданная область, в которой стоят физические
## специи-бутылочки ([SpiceNode]).
##
## Узел сцены: позиция — левый верхний угол области, размер и вид — в
## инспекторе (превью с бутылочками видно в редакторе); масштаб узла
## учитывается. Область настраивается прямо в редакторе — этим и задаётся,
## где специи стоят.
##
## Границы U-образные, как у настоящей полки: невидимые стенки (на слое
## [constant SpiceNode.SPICE_WALL_LAYER]) есть у дна и с боков, а сверху
## открыто — специю можно вынуть с полки и выбросить куда угодно
## ([member allow_taking_out]). Выброшенная специя падает по своей обычной
## физике, и если она покидает экран, полка возвращает её себе
## ([member return_when_offscreen]) — специя не теряется.
##
## У стенок есть толщина ([member wall_thickness]) — на столько они
## выступают наружу от края области, и сквозь эту полосу специя не
## проходит. Высота боковых стенок задаётся каждой отдельно
## ([member left_wall_height], [member right_wall_height]): низкие бортики
## удерживают стоящие бутылочки, но не мешают подносить специю к полке
## сбоку. В редакторе стенки видны как полосы, чтобы сразу было понятно,
## где именно проход закрыт.
##
## При старте боя [method setup] расставляет специи игрока по дну, стараясь
## не перекрывать их друг другом; дальше ими правит гравитация и осциллятор
## покачивания ([SpiceNode]). Специи не сталкиваются между собой, поэтому
## лёгкое перекрытие допустимо, если все не помещаются в ряд.
##
## Перетаскивание — той же пружиной, что на столе и в мешке (параметры из
## [CombatConfig]), с линией тяги. Клик по специи хватает её (коллизия — по
## непрозрачным пикселям PNG); если под курсором несколько — берётся та,
## что рисуется поверх (больший [member CanvasItem.z_index]).
class_name SpiceShelf
extends Node2D

## Размер области; [member Node2D.position] узла — её левый верхний угол.
@export var area_size := Vector2(792, 126):
	set(value):
		area_size = value.max(Vector2.ZERO)
		queue_redraw()

@export var title := "Spices":
	set(value):
		title = value
		queue_redraw()

## Точка появления новой специи (локальные координаты узла, в редакторе
## видна маркером-стрелкой): купленная в магазине специя спавнится здесь
## и падает на дно полки ([method drop_in]). Точка должна быть внутри
## области — снаружи её отгородят стенки.
@export var drop_point := Vector2(90.0, 25.0):
	set(value):
		drop_point = value
		queue_redraw()

@export_group("Слой отрисовки")
## База слоя специй: прибавляется к [member SpiceModel.z_order] каждой
## специи (у специй z_order 16..20) — так полка целиком выносится на свой
## слой сцены. По умолчанию 100: специи поверх всех объектов боя — стола
## и ингредиентов (z 0, на подсчёте 92), затемнения подсчёта (91), корзин
## (90) и HUD (100). В бою ([code]l_combat.tscn[/code]) полка опущена
## до 69 (специи 85..89, линия тяги 90) — чтобы на подсчёте они уходили
## в тень вместе со столом и корзинами, а не светились поверх затемнения.
## Больше — ближе к зрителю.
@export var z_base := 100

@export_group("Физика")
## Ускорение падения специй — масштаб гравитации проекта (1 — стандартная).
@export var gravity_scale := 1.2
## Максимальный наклон покачивания при неровном захвате и приземлении, °.
@export var sway_max_degrees := 10.0
## Сколько раз специя подпрыгивает при приземлении (0 — просто ложится,
## 1–2 обычно достаточно).
@export_range(0, 5) var landing_bounces := 2
## Доля скорости падения, сохраняемая в подскоке (меньше — слабее отскок).
@export_range(0.0, 0.9) var bounce_strength := 0.28

## Рисовать тень под бутылочками, стоящими на полке. По умолчанию
## выключено: специи стоят на полке, а не висят над ней.
@export var show_spice_shadows := false

@export_group("Стенки")
## Толщина стенок, px: на столько стенка выступает наружу от края области,
## и сквозь эту полосу специя не проходит. Тоньше — можно поднести специю
## ближе к самому краю полки. Совсем тонкую стенку быстро падающая
## бутылочка может проскочить, но полка вернёт её себе (см. «Выброс
## с полки»).
@export var wall_thickness := 24.0:
	set(value):
		wall_thickness = maxf(value, 0.0)
		_rebuild_walls()
		queue_redraw()

## Высота левого бортика, считая от дна области, px. 0 — бортика нет.
@export var left_wall_height := 90.0:
	set(value):
		left_wall_height = maxf(value, 0.0)
		_rebuild_walls()
		queue_redraw()

## Высота правого бортика, считая от дна области, px. 0 — бортика нет.
@export var right_wall_height := 90.0:
	set(value):
		right_wall_height = maxf(value, 0.0)
		_rebuild_walls()
		queue_redraw()

## Толщина дна, px. 0 — как [member wall_thickness].
@export var floor_thickness := 0.0:
	set(value):
		floor_thickness = maxf(value, 0.0)
		_rebuild_walls()
		queue_redraw()

## Показывать стенки в игре (в редакторе они видны всегда).
@export var show_walls_in_game := false:
	set(value):
		show_walls_in_game = value
		queue_redraw()

@export_group("Выброс с полки")
## Разрешить вынимать специи с полки: сверху она открыта, курсор границами
## не зажат. Выключено — специя не покидает область, как раньше.
@export var allow_taking_out := true

## Возвращать выброшенную специю на полку, когда она покидает экран.
## Специя появляется в точке падения ([member drop_point]) и снова
## оказывается на полке.
@export var return_when_offscreen := true

## Насколько далеко за край экрана должна уйти специя, чтобы вернуться, px.
@export var offscreen_margin := 60.0

@export_group("Вид")
## Показывать рамку области в игре (в редакторе превью видно всегда).
@export var show_area_in_game := false:
	set(value):
		show_area_in_game = value
		queue_redraw()

@export var fill_color := Color(0.16, 0.13, 0.2, 0.45):
	set(value):
		fill_color = value
		queue_redraw()

@export var border_color := Color(0.7, 0.55, 0.85, 0.5):
	set(value):
		border_color = value
		queue_redraw()

@export var title_color := Color(0.82, 0.72, 0.9):
	set(value):
		title_color = value
		queue_redraw()

@export var title_font_size := 12:
	set(value):
		title_font_size = maxi(value, 1)
		queue_redraw()

## Сколько бутылочек рисовать в превью редактора.
@export var editor_preview_count := 5

## Параметры пружины/линии тяги — из конфига боя (задаёт [method setup]).
var config: CombatConfig

var _spices: Array[SpiceNode] = []
var _walls: Array[StaticBody2D] = []
var _dragged: SpiceNode = null
var _line_overlay: Node2D


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_build_walls()
	# Линия тяги — отдельный слой сразу поверх самой верхней специи
	# (у специй z_order не больше 20).
	_line_overlay = Node2D.new()
	_line_overlay.top_level = true
	_line_overlay.z_index = z_base + 21
	_line_overlay.draw.connect(_draw_drag_line)
	add_child(_line_overlay)


func _process(_delta: float) -> void:
	# И специя, и курсор постоянно движутся — перерисовываем линию каждый кадр.
	if not Engine.is_editor_hint() and _line_overlay != null:
		_line_overlay.queue_redraw()


## Область в локальных координатах узла (для отрисовки).
func area_rect() -> Rect2:
	return Rect2(Vector2.ZERO, area_size)


## Область в глобальных координатах (учитывает масштаб узла из редактора).
func area_global_rect() -> Rect2:
	return Rect2(global_position, area_size * global_scale)


## Расставить специи игрока по полке. Вызывается режимом боя со списком
## специй и конфигом (пружина, линия тяги).
func setup(spice_models: Array[SpiceModel], combat_config: CombatConfig) -> void:
	config = combat_config
	_release()
	for spice in _spices:
		if is_instance_valid(spice):
			spice.queue_free()
	_spices.clear()
	_spawn_spices(spice_models)


## Расстановка по дну области слева направо: каждая специя занимает свою
## ширину, промежутки распределяются равномерно. Если в ряд не помещаются —
## промежуток минимальный (специи друг с другом не сталкиваются, лёгкое
## перекрытие допустимо). Стоят уже на дне — при старте не падают.
func _spawn_spices(models: Array[SpiceModel]) -> void:
	if models.is_empty():
		return
	var rect := area_global_rect()
	var widths: Array[float] = []
	var total := 0.0
	for model in models:
		var w := SpiceNode.texture_box(model).size.x
		widths.append(w)
		total += w
	var margin := 10.0
	var gap := (rect.size.x - margin * 2.0 - total) / float(models.size() + 1)
	gap = maxf(gap, 6.0)
	var x := rect.position.x + margin + gap
	for i in models.size():
		var spice := SpiceNode.create(models[i], config, z_base, gravity_scale,
				sway_max_degrees)
		spice.max_bounces = landing_bounces
		spice.bounce_strength = bounce_strength
		spice.show_shadow = show_spice_shadows
		# Специи не наследуют масштаб узла — физика без искажений.
		spice.top_level = true
		add_child(spice)
		var box := SpiceNode.texture_box(models[i])
		# Низ бутылочки у дна области — специя уже стоит, а не падает.
		spice.global_position = Vector2(
				x + widths[i] * 0.5,
				rect.end.y - 6.0 - box.size.y * 0.5)
		_spices.append(spice)
		x += widths[i] + gap


## Уронить на полку новую специю (покупка в магазине или награда за бой):
## бутылочка появляется в точке [member drop_point] и падает на дно под
## гравитацией, с обычным покачиванием и подскоками при приземлении. Точка
## появления поджимается внутрь области с учётом размера бутылочки — иначе
## тело, пересёкшееся со стенкой, физика вытолкнет наружу полки.
##
## Новая специя добавляется последней, поэтому среди одинаковых (у них
## общий [member SpiceModel.z_order], а значит и общий слой) она рисуется
## поверх остальных: первой на экране всегда та, что появилась позже. За
## неё же полка отдаёт и клик ([method _spice_at]).
func drop_in(model: SpiceModel) -> void:
	if model == null:
		return
	var spice := SpiceNode.create(model, config, z_base, gravity_scale,
			sway_max_degrees)
	spice.max_bounces = landing_bounces
	spice.bounce_strength = bounce_strength
	spice.show_shadow = show_spice_shadows
	# Специи не наследуют масштаб узла — физика без искажений.
	spice.top_level = true
	add_child(spice)
	spice.global_position = _drop_position(model)
	_spices.append(spice)
	# Купленная специя встала на полку — склянка звякнула.
	if not Engine.is_editor_hint():
		Audio.play(AudioDirector.SPICE)


## Точка появления специи на полке: [member drop_point], поджатая внутрь
## области с учётом размера бутылочки, — иначе тело, пересёкшееся со
## стенкой, физика вытолкнет наружу. Общая для покупки и для возврата
## выброшенной специи.
func _drop_position(model: SpiceModel) -> Vector2:
	var half := SpiceNode.texture_box(model).size * 0.5
	var rect := area_global_rect()
	var lo := rect.position + half
	var hi := rect.end - half
	return to_global(drop_point).clamp(lo.min(hi), lo.max(hi))


## Прямоугольники стенок в глобальных координатах: дно, левый и правый
## бортики. Сверху открыто — специю можно вынуть и выбросить. Толщина и
## высота бортиков — из инспектора; бортик нулевой высоты не строится.
## По этим же прямоугольникам рисуется превью в редакторе, так что видно
## ровно то, что физически закрыто.
func wall_rects() -> Array[Rect2]:
	var rect := area_global_rect()
	var scale_y := maxf(global_scale.y, 0.001)
	var thickness := wall_thickness * maxf(global_scale.x, 0.001)
	var floor_t := (floor_thickness * scale_y) if floor_thickness > 0.0 else thickness
	var rects: Array[Rect2] = []
	if floor_t > 0.0:
		rects.append(Rect2(rect.position.x - thickness, rect.end.y,
				rect.size.x + thickness * 2.0, floor_t))
	var left_h := minf(left_wall_height * scale_y, rect.size.y)
	if left_h > 0.0 and thickness > 0.0:
		rects.append(Rect2(rect.position.x - thickness, rect.end.y - left_h,
				thickness, left_h))
	var right_h := minf(right_wall_height * scale_y, rect.size.y)
	if right_h > 0.0 and thickness > 0.0:
		rects.append(Rect2(rect.end.x, rect.end.y - right_h, thickness, right_h))
	return rects


func _build_walls() -> void:
	for wall_rect in wall_rects():
		var wall := StaticBody2D.new()
		wall.top_level = true
		wall.collision_layer = SpiceNode.SPICE_WALL_LAYER
		wall.collision_mask = SpiceNode.SPICE_LAYER
		var shape := RectangleShape2D.new()
		shape.size = wall_rect.size
		var collision := CollisionShape2D.new()
		collision.shape = shape
		wall.add_child(collision)
		add_child(wall)
		wall.global_position = wall_rect.get_center()
		_walls.append(wall)


## Пересобрать стенки после правки размеров — чтобы менять их можно было
## и на ходу, а не только до запуска.
func _rebuild_walls() -> void:
	if Engine.is_editor_hint() or not is_inside_tree() or _walls.is_empty():
		return
	for wall in _walls:
		if is_instance_valid(wall):
			wall.queue_free()
	_walls.clear()
	_build_walls()


# --- Перетаскивание специй ---

func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	var button := event as InputEventMouseButton
	if button == null or button.button_index != MOUSE_BUTTON_LEFT:
		return
	# Под открытым окном HUD специи не трогаются: полка стоит в сцене после
	# HUD и получает ввод раньше него, поэтому спрашивает затвор.
	if CombatInputGate.blocked:
		return
	if button.pressed:
		var spice := _spice_at(get_global_mouse_position())
		if spice != null:
			_grab(spice, get_global_mouse_position())
			get_viewport().set_input_as_handled()
	elif _dragged != null:
		_release()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_release()


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _dragged != null:
		if is_instance_valid(_dragged):
			_dragged.apply_drag_force(_drag_target())
		else:
			_dragged = null
	if return_when_offscreen:
		_return_lost_spices()


## Специя, выброшенная за край экрана, возвращается на полку: встаёт в
## точку падения и оседает на дно своей обычной физикой. Специя в руке не
## возвращается — её держит игрок.
##
## Потерянной считается ушедшая вниз или в стороны: улетевшую вверх вернёт
## сама гравитация, а полка может стоять выше края экрана (так она стоит в
## бою) — иначе спавн за кадром возвращал бы специю снова и снова.
func _return_lost_spices() -> void:
	var screen := get_viewport().get_visible_rect()
	for spice in _spices:
		if not is_instance_valid(spice) or spice == _dragged:
			continue
		# Позиция на экране — с учётом камеры, если она в сцене есть.
		var point := spice.get_global_transform_with_canvas().origin
		if point.y < screen.end.y + offscreen_margin \
				and point.x > screen.position.x - offscreen_margin \
				and point.x < screen.end.x + offscreen_margin:
			continue
		spice.linear_velocity = Vector2.ZERO
		spice.angular_velocity = 0.0
		spice.global_position = _drop_position(spice.model)


func _grab(spice: SpiceNode, point: Vector2) -> void:
	_release()
	# Специю взяли — склянка звякнула ([AudioDirector]).
	Audio.play(AudioDirector.SPICE)
	_dragged = spice
	spice.start_drag(point)


func _release() -> void:
	if _dragged != null and is_instance_valid(_dragged):
		_dragged.end_drag()
	_dragged = null


## Цель пружины — курсор. Если вынимать специи нельзя, курсор зажимается
## границами полки и специю за её пределы не вытянуть.
func _drag_target() -> Vector2:
	var point := get_global_mouse_position()
	if allow_taking_out:
		return point
	var inner := area_global_rect().grow(-4.0)
	inner.size = inner.size.max(Vector2.ZERO)
	return point.clamp(inner.position, inner.end)


## Специя этой полки в точке (по непрозрачным пикселям PNG). Если под
## курсором несколько — берётся та, что рисуется поверх: сперва по слою
## (больший z_index), а на одном слое — та, что появилась позже (она и
## нарисована поверх своих двойников). Если под самим курсором пусто —
## ближайшая специя в кругу захвата ([member CombatConfig.grab_radius]).
func _spice_at(global_point: Vector2) -> SpiceNode:
	var best: SpiceNode = null
	var best_order := -1
	for body in GrabArea.bodies_at_point(get_world_2d(), global_point,
			SpiceNode.SPICE_LAYER):
		var spice := body as SpiceNode
		if spice == null or spice.get_parent() != self:
			continue
		var order := _spices.find(spice)
		if best == null or spice.z_index > best.z_index \
				or (spice.z_index == best.z_index and order > best_order):
			best = spice
			best_order = order
	if best != null:
		return best
	var radius := config.grab_radius if config != null else 8.0
	for body in GrabArea.bodies_in_circle(get_world_2d(), global_point,
			radius, SpiceNode.SPICE_LAYER):
		var spice := body as SpiceNode
		if spice != null and spice.get_parent() == self:
			return spice
	return null


func _draw_drag_line() -> void:
	if _dragged == null or not is_instance_valid(_dragged) or not _dragged.is_dragging():
		return
	var from := _line_overlay.to_local(_dragged.grab_point_global())
	var to_point := _line_overlay.to_local(_drag_target())
	var line_color := config.drag_line_color if config != null else Color(0.13, 0.68, 0.96)
	var line_width := config.drag_line_width if config != null else 6.0
	if from.distance_to(to_point) > 1.0:
		_line_overlay.draw_line(from, to_point, line_color, line_width)
	_line_overlay.draw_circle(from, line_width / 2.0, line_color)
	_line_overlay.draw_circle(to_point, line_width / 2.0, line_color)


# --- Отрисовка области и превью ---

func _draw() -> void:
	if Engine.is_editor_hint() or show_area_in_game:
		draw_rect(area_rect(), fill_color)
		# Границы U-образные, как у настоящей полки: дно и бока, сверху
		# открыто — там специю вынимают.
		var area := area_rect()
		draw_polyline(PackedVector2Array([
				area.position, Vector2(area.position.x, area.end.y),
				area.end, Vector2(area.end.x, area.position.y)]),
				border_color, 2.0)
	if Engine.is_editor_hint() or show_walls_in_game:
		_draw_walls_preview()
		if title != "":
			draw_string(ThemeDB.fallback_font, Vector2(4.0, -6.0), title,
					HORIZONTAL_ALIGNMENT_LEFT, area_size.x, title_font_size, title_color)
	if Engine.is_editor_hint():
		_draw_editor_preview()
		_draw_drop_point_marker()


## Стенки полки: полосы там, где специя физически не пройдёт. Видно, как
## толщину, так и высоту каждого бортика.
func _draw_walls_preview() -> void:
	var fill := Color(0.95, 0.45, 0.3, 0.3)
	var edge := Color(0.95, 0.45, 0.3, 0.75)
	for wall_rect in wall_rects():
		# Прямоугольники стенок считаются в глобальных координатах —
		# приводим их к локальным координатам узла для отрисовки.
		var local := Rect2(to_local(wall_rect.position),
				wall_rect.size / global_scale.max(Vector2(0.001, 0.001)))
		draw_rect(local, fill)
		draw_rect(local, edge, false, 1.0)


## Маркер точки падения новой специи в редакторе: кружок и стрелка вниз.
func _draw_drop_point_marker() -> void:
	var tint := Color(0.95, 0.8, 0.3, 0.85)
	draw_circle(drop_point, 4.0, tint)
	draw_line(drop_point + Vector2(0.0, 6.0), drop_point + Vector2(0.0, 22.0),
			tint, 1.5)
	var tip := drop_point + Vector2(0.0, 28.0)
	draw_colored_polygon(PackedVector2Array([
			tip, tip + Vector2(-5.0, -7.0), tip + Vector2(5.0, -7.0)]), tint)
	draw_string(ThemeDB.fallback_font, drop_point + Vector2(8.0, 4.0),
			"drop", HORIZONTAL_ALIGNMENT_LEFT, 100, 10, tint)


## Превью в редакторе: бутылочки-заглушки по дну области, чтобы видеть
## расстановку при настройке размера полки.
func _draw_editor_preview() -> void:
	var count := maxi(editor_preview_count, 1)
	var slot := area_size.x / float(count)
	for i in count:
		var w := slot * 0.4
		var h := minf(area_size.y * 0.72, w * 3.0)
		var cx := slot * (float(i) + 0.5)
		var rect := Rect2(cx - w * 0.5, area_size.y - 6.0 - h, w, h)
		draw_rect(rect, Color(border_color, 0.35))
		draw_rect(rect, border_color, false, 1.5)
