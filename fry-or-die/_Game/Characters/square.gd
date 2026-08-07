class_name DragSquare
extends RigidBody2D

## Физический квадрат: имеет массу (вес), коллизию, может толкать другие
## квадраты и перетаскивается мышью через пружинную силу.
## Тип куба (размер, плотность, цвет) описывает SquareDef, физика и
## перетаскивание — SandboxConfig (_Game/Data).

var side := 48.0
var fill_color := Color.WHITE
var drag_stiffness := 60.0          # жёсткость "пружины" между точкой захвата и курсором
var max_stretch := 300.0            # ограничение растяжения пружины, чтобы сила не взрывалась
var max_speed := 1400.0             # предохранитель от туннелирования сквозь стены
var drag_inertia := 0.6             # 0 = жёстко липнет к курсору, 1 = свободно раскачивается

var drop_gravity := 2600.0          # ускорение "высыпания", px/s^2 (фейковая высота)
var drop_bounce := 0.3              # доля скорости, сохраняемая при подскоке

var _dragging := false
var _grab_local := Vector2.ZERO     # точка захвата в локальных координатах квадрата
var _air_height := 0.0              # высота куба над доской в пикселях (0 = лежит)
var _air_velocity := 0.0            # скорость падения, px/s (положительная = вниз)
var _air_start_height := 1.0
var _air_tilt := 0.0                # наклон в полёте; гаснет к моменту касания
var _airborne := false              # true до первого касания: физика выключена
var _drop_delay := 0.0              # очередь в каскаде: куб ждёт невидимым
var _collision: CollisionShape2D


static func create(def: SquareDef, config: SandboxConfig) -> DragSquare:
	var sq := DragSquare.new()
	var square_side := randf_range(def.min_side, maxf(def.min_side, def.max_side))
	sq.side = square_side
	sq.drag_stiffness = config.drag_stiffness
	sq.max_stretch = config.max_stretch
	sq.max_speed = config.max_speed
	sq.drag_inertia = config.drag_inertia
	# Вес растёт с площадью и плотностью типа.
	sq.mass = def.density * pow(square_side / 36.0, 2.0)
	# Цвет: фиксированный у типа или автоматический по весу (белый -> оранжевый).
	if def.use_custom_color:
		sq.fill_color = def.custom_color
	else:
		var weight_t := clampf((sq.mass - 1.0) / 3.0, 0.0, 1.0)
		sq.fill_color = Color.WHITE.lerp(Color(0.94, 0.45, 0.25), weight_t)

	var shape := RectangleShape2D.new()
	shape.size = Vector2(square_side, square_side)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	sq.add_child(collision)
	sq._collision = collision

	sq.gravity_scale = 0.0          # вид сверху: квадраты не падают, а скользят
	# Сопротивление поверхности отсутствует: квадраты скользят без замедления.
	sq.linear_damp = 0.0
	# Сопротивление вращения 0..1 -> угловое затухание: при 1.0 вращение
	# гаснет за один физический тик, при 0 куб крутится свободно.
	sq.angular_damp = config.rotation_resistance * float(Engine.physics_ticks_per_second)
	sq.continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE

	# Упругость контакта — сумма bounce обоих тел (с обрезкой до 1.0).
	# Куб и стена несут по половине настроенной упругости, поэтому и
	# куб+куб, и куб+стена дают ровно config.elasticity.
	var material := PhysicsMaterial.new()
	material.friction = config.square_friction
	material.bounce = config.elasticity / 2.0
	sq.physics_material_override = material
	return sq


## Высыпание на доску: куб влетает из-за верхнего края экрана и с ускорением
## падает вертикально к своему месту. Тело стоит в точке приземления
## (физика и коллизия выключены), а рисуется куб выше на _air_height — под ним
## на доске лежит тень. Касание включает физику; остаток — затухающие подскоки.
func drop_in(start_height: float, delay := 0.0, gravity := 2600.0, bounce := 0.3) -> void:
	if start_height <= 0.0 or gravity <= 0.0:
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
	_collision.disabled = true
	z_index = 50                    # летящий куб рисуется поверх лежащих на доске
	visible = delay <= 0.0          # до своей очереди в каскаде куба не видно


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
			# Первое касание доски: куб снова физический и осязаемый.
			_airborne = false
			_collision.disabled = false
			freeze = false
			z_index = 0
		_air_velocity = -_air_velocity * drop_bounce
		if absf(_air_velocity) < 60.0:
			_air_velocity = 0.0


func is_dragging() -> bool:
	return _dragging


func grab_point_global() -> Vector2:
	return to_global(_grab_local)


func start_drag(global_point: Vector2) -> void:
	_dragging = true
	_grab_local = to_local(global_point)


func end_drag() -> void:
	_dragging = false


func _physics_process(delta: float) -> void:
	# Тень смещена "вниз экрана" в локальных координатах куба, поэтому её
	# положение зависит от текущего поворота. Куб вращается физикой в любой
	# момент — перерисовываем каждый тик, а не только по событиям мыши.
	queue_redraw()

	if _airborne or _air_height > 0.0 or _air_velocity != 0.0:
		_step_drop(delta)

	if _dragging:
		var grab_global := grab_point_global()
		var stretch := get_global_mouse_position() - grab_global
		if stretch.length() > max_stretch:
			stretch = stretch.normalized() * max_stretch
		# Пружина с демпфером: инерция снижает коэффициент демпфирования
		# от почти критического (0.9) до слабого (0.08) — куб отстаёт от
		# курсора, раскачивается и продолжает движение по инерции.
		# Тяжёлые квадраты разгоняются медленнее при любой инерции,
		# потому что жёсткость не зависит от массы.
		var damping_ratio := lerpf(0.9, 0.08, drag_inertia)
		var damping := 2.0 * damping_ratio * sqrt(drag_stiffness * mass)
		var force := drag_stiffness * stretch - damping * linear_velocity
		apply_force(force, grab_global - global_position)

	if linear_velocity.length() > max_speed:
		linear_velocity = linear_velocity.normalized() * max_speed


func _draw() -> void:
	var half := side / 2.0
	var rect := Rect2(-half, -half, side, side)

	# Тень-силуэт на доске: у лежащего куба — узкая полоска под нижней
	# гранью, у летящего — пятно в точке приземления (свет сверху-справа,
	# поэтому с высотой тень уезжает чуть влево от куба).
	var shadow_offset := Vector2(-_air_height * 0.1, 4.0).rotated(-rotation)
	draw_set_transform(shadow_offset, 0.0, Vector2.ONE)
	draw_rect(rect, Color(0.02, 0.02, 0.04, 0.55))

	# Куб "в воздухе" рисуется выше точки приземления по вертикали экрана;
	# на скорости за ним тянется призрачный след из прежних положений.
	var up_local := Vector2.UP.rotated(-rotation)
	_draw_trail_ghost(rect, 0.09, 0.1, up_local)
	_draw_trail_ghost(rect, 0.045, 0.22, up_local)
	draw_set_transform(up_local * _air_height, _tilt_at(_air_height), Vector2.ONE)
	_draw_body(rect)


## Наклон куба в полёте: максимален наверху, к касанию доски сходит на нет.
func _tilt_at(height: float) -> float:
	return _air_tilt * clampf(height / _air_start_height, 0.0, 1.0)


func _draw_trail_ghost(rect: Rect2, lag: float, alpha: float, up_local: Vector2) -> void:
	if absf(_air_velocity) < 500.0:
		return
	# Где куб был lag секунд назад (при подскоке след оказывается снизу).
	var ghost_height := _air_height + _air_velocity * lag
	if ghost_height <= 0.0:
		return
	draw_set_transform(up_local * ghost_height, _tilt_at(ghost_height), Vector2.ONE)
	draw_rect(rect, Color(fill_color, alpha))
	draw_rect(rect, Color(0.1, 0.1, 0.12, alpha), false, 3.0)


func _draw_body(rect: Rect2) -> void:
	draw_rect(rect, fill_color)
	var border := Color(0.13, 0.68, 0.96) if _dragging else Color(0.1, 0.1, 0.12)
	draw_rect(rect, border, false, 3.0)

	var font := ThemeDB.fallback_font
	var font_size := maxi(10, int(side * 0.28))
	var label := "%.1f" % mass
	# На тёмной заливке вес пишем светлым, на светлой — тёмным.
	var text_color := Color(0.12, 0.12, 0.14) if fill_color.get_luminance() > 0.5 \
			else Color(0.95, 0.95, 0.97)
	draw_string(font, Vector2(rect.position.x, font_size * 0.35), label,
			HORIZONTAL_ALIGNMENT_CENTER, side, font_size, text_color)
