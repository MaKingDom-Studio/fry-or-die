extends Node2D

## Игровой режим песочницы (аналог GM_* из UE): строит прямоугольную арену,
## спавнит кубы из инвентаря и управляет перетаскиванием.
## Весь баланс — в ресурсе SandboxConfig (_Game/Data/da_sandbox.tres),
## состав кубов — в инвентаре (_Game/Data/da_inventory.tres).

@export var config: SandboxConfig

var dragged: DragSquare = null

var _arena: Node2D
var _inventory: SquareInventory
var _grab_request := Vector2.ZERO
var _has_grab_request := false


func _ready() -> void:
	if config == null:
		config = SandboxConfig.new()
	_arena = $Arena
	_build_walls()
	_center_arena()
	get_viewport().size_changed.connect(_center_arena)
	# Видимый круг захвата под курсором — область, которой хватают кубы.
	GrabCircleOverlay.attach_to(self, config, 100)

	# Спавн идёт из инвентаря; всё, что попадает в него во время игры
	# (add_to_inventory), автоматически появляется на арене.
	_inventory = SquareInventory.new()
	_inventory.setup(config.inventory)
	_inventory.items_added.connect(_drain_inventory)
	_drain_inventory()


## Пополнение инвентаря во время игры: кубы тут же заспавнятся.
func add_to_inventory(def: SquareDef, count := 1) -> void:
	_inventory.add(def, count)


func _drain_inventory() -> void:
	# Кубы не возникают на месте, а высыпаются на доску каскадом: каждый
	# влетает из-за верхнего края экрана и падает к своему месту, следующий
	# стартует чуть позже предыдущего.
	var drop_order := 0
	while true:
		var def := _inventory.take_random()
		if def == null:
			break
		var square := _spawn_square(def)
		# Высота, при которой куб в начале падения ещё за верхним краем
		# экрана: расстояние от места приземления до края плюс сам куб.
		var start_height := _arena.position.y + square.position.y + square.side
		square.drop_in(start_height,
				drop_order * config.drop_stagger + randf_range(0.0, 0.04),
				config.drop_gravity, config.drop_bounce)
		drop_order += 1


func _build_walls() -> void:
	# Четыре статичные стены снаружи по периметру арены.
	# Bounce при контакте суммируется (с обрезкой до 1.0): стена несёт
	# половину config.elasticity, вторую половину — куб. Трение берётся
	# минимальное из двух, поэтому стена с friction=0 не гасит скольжение.
	var wall_material := PhysicsMaterial.new()
	wall_material.bounce = config.elasticity / 2.0
	wall_material.friction = 0.0

	var width := config.arena_width
	var height := config.arena_height
	var thickness := config.wall_thickness
	var half_wall := thickness / 2.0
	var horizontal_size := Vector2(width + thickness * 2.0, thickness)
	var vertical_size := Vector2(thickness, height + thickness * 2.0)
	var walls := [
		[Vector2(width / 2.0, -half_wall), horizontal_size],
		[Vector2(width / 2.0, height + half_wall), horizontal_size],
		[Vector2(-half_wall, height / 2.0), vertical_size],
		[Vector2(width + half_wall, height / 2.0), vertical_size],
	]
	for wall_data in walls:
		var wall := StaticBody2D.new()
		wall.position = wall_data[0]
		wall.physics_material_override = wall_material
		var shape := RectangleShape2D.new()
		shape.size = wall_data[1]
		var collision := CollisionShape2D.new()
		collision.shape = shape
		wall.add_child(collision)
		_arena.add_child(wall)


func _center_arena() -> void:
	var viewport_size := get_viewport_rect().size
	_arena.position = (viewport_size - Vector2(config.arena_width, config.arena_height)) / 2.0
	queue_redraw()


func _spawn_square(def: SquareDef) -> DragSquare:
	var square := DragSquare.create(def, config)
	var side := square.side
	# Отступ по описанной окружности: квадрат спавнится повёрнутым,
	# поэтому от стены нужно side*sqrt(2)/2, а не side/2.
	var margin := side * sqrt(2.0) / 2.0 + 4.0

	# Несколько попыток найти место без наложения на существующие квадраты.
	var position_found := Vector2.ZERO
	for _attempt in 24:
		position_found = Vector2(
			randf_range(margin, config.arena_width - margin),
			randf_range(margin, config.arena_height - margin))
		var free := true
		for child in _arena.get_children():
			var other := child as DragSquare
			if other == null:
				continue
			var min_dist := (side + other.side) * 0.72
			if position_found.distance_to(other.position) < min_dist:
				free = false
				break
		if free:
			break

	square.position = position_found
	square.rotation = randf_range(0.0, TAU)
	_arena.add_child(square)
	return square


func _unhandled_input(event: InputEvent) -> void:
	var mouse_event := event as InputEventMouseButton
	if mouse_event != null and mouse_event.button_index == MOUSE_BUTTON_LEFT:
		if mouse_event.pressed:
			_grab_request = get_global_mouse_position()
			_has_grab_request = true
		else:
			_has_grab_request = false
			_release_drag()


func _release_drag() -> void:
	if dragged != null:
		dragged.end_drag()
		dragged = null


func _notification(what: int) -> void:
	# В браузере mouseup может потеряться, если вкладка теряет фокус
	# с зажатой ЛКМ, — сбрасываем перетаскивание принудительно.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_has_grab_request = false
		_release_drag()


func _physics_process(_delta: float) -> void:
	# Запрос захвата обрабатывается здесь, чтобы не делать point query,
	# пока физическое пространство может быть заблокировано.
	if _has_grab_request:
		_has_grab_request = false
		for body in GrabArea.bodies_at(get_world_2d(), _grab_request,
				config.grab_radius):
			if body is DragSquare:
				_release_drag()
				dragged = body
				dragged.start_drag(_grab_request)
				break


func _draw() -> void:
	var arena_rect := Rect2(_arena.position, Vector2(config.arena_width, config.arena_height))
	draw_rect(arena_rect, Color(0.11, 0.11, 0.13))
	draw_rect(arena_rect, Color(0.85, 0.85, 0.88), false, 4.0)
