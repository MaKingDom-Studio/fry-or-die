@tool
## Корзина с физическими фишками-ингредиентами (немодальная панель).
## Узел сцены: позиция — левый верхний угол панели, размер и вид —
## в инспекторе (превью видно в редакторе); масштаб узла учитывается.
##
## Фишки ([ContainerChip]) — точно такие же, как в мешке: тот же размер
## (как у ингредиентов на поле), коллизия по PNG, вращение и ослабленная
## гравитация. Наполнение приходит из мешка: фишки складываются кучкой
## у дна и появляются по очереди с ростом изображения от маленького к
## нормальному ([method ContainerChip.appear_pop]). Стенки (лево, право,
## дно; верха нет) и сами фишки живут на отдельном физическом слое 2 и
## не мешают ингредиентам стола; масштаб панели они не наследуют
## (top_level) — физика остаётся честной.
##
## Мешок игрока — отдельный виджет [BagPanel]: модальный, со своим
## физическим слоем, к корзинам отношения не имеет.
class_name ChipContainer
extends Node2D

const WALL_THICKNESS := 60.0

@export var panel_size := Vector2(152, 372):
	set(value):
		panel_size = value.max(Vector2.ZERO)
		queue_redraw()

@export var title := "":
	set(value):
		title = value
		queue_redraw()

## Узел-точка, откуда вылетают фишки при наполнении корзины, —
## отдельный от корзины узел [BasketFillPoint], двигается мышью в
## 2D-виде редактора; у корзин игрока и врага назначается свой.
@export var fill_point: Node2D

@export_group("Вид")
@export var fill_color := Color(0.42, 0.27, 0.14):
	set(value):
		fill_color = value
		queue_redraw()

@export var border_color := Color(0.75, 0.55, 0.2):
	set(value):
		border_color = value
		queue_redraw()

@export var title_color := Color(0.95, 0.9, 0.8):
	set(value):
		title_color = value
		queue_redraw()

@export var title_font_size := 12:
	set(value):
		title_font_size = maxi(value, 1)
		queue_redraw()

## Масштаб фишек относительно радиуса ингредиента (1 — размер как
## на поле и в мешке).
@export var chip_scale := 1.0

## Скорость полёта фишек при наполнении, паузы между вылетами и высота
## сброса над местом в кучке — перенимаются из конфига боя
## ([method set_fill_params]).
var fill_speed := 900.0
var fill_stagger := 0.1
var fill_stagger_random := 0.1
var fill_drop_height := 70.0

var _chips: Array[ContainerChip] = []
## Пружина перетаскивания фишек ([ChipDragger]) — фишки в корзине можно
## трогать и таскать в пределах панели, как в мешке.
var _dragger := ChipDragger.new()
var _line_overlay: Node2D


## Перенять параметры анимации наполнения и пружины перетаскивания
## из конфига боя (CombatConfig.basket_fill_* и drag_*).
func set_fill_params(config: CombatConfig) -> void:
	fill_speed = config.basket_fill_speed
	fill_stagger = config.basket_fill_stagger
	fill_stagger_random = config.basket_fill_stagger_random
	fill_drop_height = config.basket_fill_drop_height
	_dragger.set_params(config)


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_build_walls()
	# Линия тяги — отдельный слой поверх фишек (фишки на z панели + 1).
	_line_overlay = Node2D.new()
	_line_overlay.z_index = 2
	_line_overlay.draw.connect(_draw_drag_line)
	add_child(_line_overlay)


func _process(_delta: float) -> void:
	# И фишка, и курсор постоянно движутся — перерисовываем каждый кадр.
	if not Engine.is_editor_hint() and _line_overlay != null:
		_line_overlay.queue_redraw()


## Панель в локальных координатах узла (для отрисовки).
func panel_rect() -> Rect2:
	return Rect2(Vector2.ZERO, panel_size)


## Панель в глобальных координатах (учитывает масштаб узла из редактора).
func panel_global_rect() -> Rect2:
	return Rect2(global_position, panel_size * global_scale)


func set_title(text: String) -> void:
	title = text


## Глобальные позиции текущих фишек (в порядке содержимого корзины) —
## места, с которых ингредиенты вылетают на стол.
func chip_positions() -> Array[Vector2]:
	var points: Array[Vector2] = []
	for chip in _chips:
		if is_instance_valid(chip):
			points.append(chip.global_position)
	return points


## Повороты текущих фишек (тот же порядок) — ингредиент подменяет свою
## фишку без скачка: то же место, тот же поворот.
func chip_rotations() -> Array[float]:
	var rotations: Array[float] = []
	for chip in _chips:
		if is_instance_valid(chip):
			rotations.append(chip.rotation)
	return rotations


## Мгновенно рассадить долетающие фишки по местам: перед снятием точек
## вылета позиции должны быть фактическими, а не серединой анимации
## наполнения (иначе высыпание стартует из воздуха у точки появления).
func settle_now() -> void:
	for chip in _chips:
		if is_instance_valid(chip):
			chip.finish_appear_now()


## Идёт ли ещё наполнение корзины: хотя бы одна фишка летит из точки
## появления. Пока true — стартовое высыпание в корзину не завершилось.
func is_filling() -> bool:
	for chip in _chips:
		if is_instance_valid(chip) and chip.is_appearing():
			return true
	return false


# --- Перетаскивание фишек в корзине (как в мешке) ---

func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	var button := event as InputEventMouseButton
	if button == null or button.button_index != MOUSE_BUTTON_LEFT:
		return
	# Под открытым окном HUD фишки не трогаются: корзина стоит в сцене после
	# HUD и получает ввод раньше него, поэтому спрашивает затвор.
	if CombatInputGate.blocked:
		return
	if button.pressed:
		var point := get_global_mouse_position()
		var chip := _chip_at(point)
		if chip != null:
			_dragger.grab(chip, point)
			get_viewport().set_input_as_handled()
	elif _dragger.is_dragging():
		_dragger.release()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_dragger.release()


## Цель пружины: курсор, зажатый границами панели, — фишку не вытянуть
## из корзины.
func _drag_target() -> Vector2:
	var inner := panel_global_rect().grow(-2.0)
	inner.size = inner.size.max(Vector2.ZERO)
	return get_global_mouse_position().clamp(inner.position, inner.end)


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint() or not _dragger.is_dragging():
		return
	_dragger.process(_drag_target())


func _draw_drag_line() -> void:
	if _dragger.is_dragging():
		_dragger.draw_drag_line(_line_overlay, _drag_target())


## Фишка этой корзины в точке или в кругу захвата вокруг неё
## (обе корзины делят слой 2 — чужие мимо).
func _chip_at(global_point: Vector2) -> ContainerChip:
	for body in GrabArea.bodies_at(get_world_2d(), global_point,
			_dragger.grab_radius, ContainerChip.CHIP_PHYSICS_LAYER):
		var chip := body as ContainerChip
		if chip != null and chip.get_parent() == self:
			return chip
	return null


## Пересыпать содержимое: каждая фишка ещё до старта знает своё место
## и по очереди вылетает из точки [member fill_point] маленькой,
## вырастая к входу в область корзины. Пополнение раскладывается по
## всей ширине корзины (сколько помещается в ряд), ряды растут от дна;
## полёт заканчивается над местом (fill_drop_height), последний отрезок
## фишка падает под гравитацией ([method ContainerChip.fly_appear]).
func set_contents(models: Array[IngredientModel]) -> void:
	_dragger.release()
	for chip in _chips:
		chip.queue_free()
	_chips.clear()
	var rect := panel_global_rect()
	var from_global := fill_point.global_position if fill_point != null \
			else rect.get_center()
	# Шаг укладки — от самой крупной фишки, чтобы ряд точно влезал.
	var max_chip_radius := 8.0
	for model in models:
		max_chip_radius = maxf(max_chip_radius, maxf(model.radius * chip_scale, 8.0))
	var step := max_chip_radius * 2.0 + 4.0
	var columns := maxi(floori((rect.size.x - 4.0) / step), 1)
	var max_rows := maxi(floori((rect.size.y - 4.0) / step), 1)
	var left := rect.position.x + 2.0 + max_chip_radius
	var right := rect.end.x - 2.0 - max_chip_radius
	var i := 0
	var delay := 0.0
	for model in models:
		var chip := ContainerChip.create(model, chip_scale)
		# Фишки не наследуют масштаб панели — физика без искажений.
		chip.top_level = true
		# Фишки — top_level и рисуются от корня холста: подняться над
		# заливкой панели им помогает собственный z поверх панельного.
		chip.z_index = z_index + 1
		add_child(chip)
		# Случайный поворот при спавне — горка оседает неровной.
		chip.rotation = randf_range(0.0, TAU)
		# Место в ряду: ряд занимает всю ширину корзины, фишки ряда
		# распределяются равномерно от края до края.
		var row := mini(floori(float(i) / columns), max_rows - 1)
		var in_row := i % columns
		var row_count := mini(models.size() - row * columns, columns)
		var tx := 0.5 if row_count <= 1 else float(in_row) / (row_count - 1)
		var target := Vector2(
				lerpf(left, right, tx) + randf_range(-3.0, 3.0),
				rect.end.y - 2.0 - max_chip_radius - row * step + randf_range(-3.0, 3.0))
		# Вылет из точки в корзину: полёт заканчивается над местом фишки,
		# последний отрезок она падает — эффект пополнения.
		var drop_from := Vector2(target.x,
				maxf(target.y - fill_drop_height, rect.position.y + max_chip_radius))
		chip.fly_appear(from_global, drop_from, rect, delay, fill_speed)
		# Выдача с рандомизацией: интервалы между вылетами неравномерные.
		delay += fill_stagger + randf_range(0.0, fill_stagger_random)
		_chips.append(chip)
		i += 1


func _build_walls() -> void:
	var rect := panel_global_rect()
	var half := WALL_THICKNESS / 2.0
	# Стенки выше панели, чтобы фишки не вылетали вбок при падении сверху.
	var extra_top := 320.0
	var side_size := Vector2(WALL_THICKNESS, rect.size.y + extra_top)
	var side_center_y := rect.position.y + rect.size.y / 2.0 - extra_top / 2.0
	var walls := [
		[Vector2(rect.get_center().x, rect.end.y + half),
				Vector2(rect.size.x + WALL_THICKNESS * 2.0, WALL_THICKNESS)],
		[Vector2(rect.position.x - half, side_center_y), side_size],
		[Vector2(rect.end.x + half, side_center_y), side_size],
	]
	for wall_data in walls:
		var wall := StaticBody2D.new()
		wall.top_level = true
		wall.collision_layer = ContainerChip.CHIP_PHYSICS_LAYER
		wall.collision_mask = ContainerChip.CHIP_PHYSICS_LAYER
		var shape := RectangleShape2D.new()
		shape.size = wall_data[1]
		var collision := CollisionShape2D.new()
		collision.shape = shape
		wall.add_child(collision)
		add_child(wall)
		wall.global_position = wall_data[0]


func _draw() -> void:
	var font := ThemeDB.fallback_font
	# Ёмкость пока — простая геометрическая фигура (прямоугольник).
	draw_rect(panel_rect(), fill_color)
	draw_rect(panel_rect(), border_color, false, 2.0)
	draw_string(font, Vector2(0.0, 18.0), title,
			HORIZONTAL_ALIGNMENT_CENTER, panel_size.x, title_font_size, title_color)
