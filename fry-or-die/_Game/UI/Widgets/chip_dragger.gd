## Пружинное перетаскивание фишек ([ContainerChip]) мышью — общая
## механика мешка ([BagPanel]) и корзин ([ChipContainer]): пружина за
## точку захвата с параметрами ингредиентов стола, компенсация веса
## (хват держится ровно под курсором, фишка маятником висит вниз),
## гашение раскрутки в руке и линия тяги.
class_name ChipDragger
extends RefCounted

## Угловое затухание фишки в руке: гасит раскрутку от силы пружины,
## чтобы фишка маятником успокаивалась под точкой захвата.
const DRAG_ANGULAR_DAMP := 5.0

var drag_stiffness := 60.0
var max_stretch := 300.0
var max_speed := 1400.0
var drag_inertia := 0.6
var drag_line_color := Color(0.13, 0.68, 0.96)
var drag_line_width := 6.0
## Круг захвата под курсором ([GrabArea]), px — как у ингредиентов стола.
var grab_radius := 8.0

var _dragged: ContainerChip = null
var _grab_local := Vector2.ZERO
var _restore_angular_damp := 1.0


## Перенять параметры пружины и линии тяги из конфига боя —
## перетаскивание ощущается и выглядит так же, как на столе.
func set_params(config: CombatConfig) -> void:
	drag_stiffness = config.drag_stiffness
	max_stretch = config.max_stretch
	max_speed = config.max_speed
	drag_inertia = config.drag_inertia
	drag_line_color = config.drag_line_color
	drag_line_width = config.drag_line_width
	grab_radius = config.grab_radius


func is_dragging() -> bool:
	return _dragged != null and is_instance_valid(_dragged)


func dragged() -> ContainerChip:
	return _dragged if is_dragging() else null


func grab(chip: ContainerChip, point: Vector2) -> void:
	_dragged = chip
	_grab_local = chip.to_local(point)
	# В руке гравитация продолжает действовать: центр тяжести маятником
	# стремится вниз под точку захвата, а повышенное угловое трение
	# гасит раскрутку от силы пружины.
	_restore_angular_damp = chip.angular_damp
	chip.angular_damp = DRAG_ANGULAR_DAMP


## Отпускание без отталкивания: скорость гасится, фишка просто падает.
func release() -> void:
	if is_dragging():
		_dragged.angular_damp = _restore_angular_damp
		_dragged.linear_velocity = Vector2.ZERO
	_dragged = null


func grab_point_global() -> Vector2:
	return _dragged.to_global(_grab_local)


## Пружина с демпфером за точку захвата — та же формула, что у
## ингредиентов стола ([method IngredientNode.apply_drag_force]).
## Вызывается из _physics_process владельца с целью пружины.
func process(target: Vector2) -> void:
	if not is_dragging():
		_dragged = null
		return
	var grab_global := grab_point_global()
	var stretch := target - grab_global
	if stretch.length() > max_stretch:
		stretch = stretch.normalized() * max_stretch
	var damping_ratio := lerpf(0.9, 0.08, drag_inertia)
	var damping := 2.0 * damping_ratio * sqrt(drag_stiffness * _dragged.mass)
	var force := drag_stiffness * stretch - damping * _dragged.linear_velocity
	# Компенсация веса в точке захвата: без неё гравитация оттягивает
	# фишку вниз от места клика и позиция мышки не совпадает с выбранной
	# фишкой. Момент силы сохраняется — фишка по-прежнему висит вниз.
	var weight := _dragged.mass * _dragged.gravity_scale \
			* float(ProjectSettings.get_setting("physics/2d/default_gravity", 980.0))
	_dragged.apply_force(force + Vector2(0.0, -weight),
			grab_global - _dragged.global_position)
	if _dragged.linear_velocity.length() > max_speed:
		_dragged.linear_velocity = _dragged.linear_velocity.normalized() * max_speed


## Линия «тяги» от точки захвата фишки до цели пружины — как на столе
## ([CombatDragOverlay]): цвет и толщина из конфига боя. Рисуется на
## переданном слое-узле (поверх фишек).
func draw_drag_line(overlay: Node2D, target: Vector2) -> void:
	if not is_dragging():
		return
	var from := overlay.to_local(grab_point_global())
	var to_point := overlay.to_local(target)
	if from.distance_to(to_point) > 1.0:
		overlay.draw_line(from, to_point, drag_line_color, drag_line_width)
	# Скруглённые концы линии.
	overlay.draw_circle(from, drag_line_width / 2.0, drag_line_color)
	overlay.draw_circle(to_point, drag_line_width / 2.0, drag_line_color)
