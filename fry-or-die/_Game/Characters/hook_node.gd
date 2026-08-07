## Крюк рыбака на боевом столе: вылетает из-за края стола, цепляет ингредиент
## и тянет его на половину своей стороны. Им пользуется минибосс «Fishman»
## (справа, с середины высоты стола; добыча — самое далёкое от него полезное
## со стола) и игрок с удочкой в инструментах ([ToolRod]) — у него удилище
## стоит слева, а добыча едет к нему. Где стоит удилище и куда тянуть,
## решает не узел: и то и другое ему передают в [method run_pull].
##
## Узел живёт ровно одно применение способности ([HookAbility]): режим боя
## создаёт его перед показом кнопки «Обратный отсчёт», ждёт [method run_pull]
## и убирает. Заброс — квадратичная кривая с боковым отклонением; от точки
## заброса за краем стола к ушку крюка всё время тянется леска.
##
## Рисуется крюк изображением ([member HookAbility.texture], Hook.png): оно
## висит на леске ушком к удилищу ([method _aim]) и доворачивается
## ([member HookAbility.image_rotation]) так, чтобы цевьё легло вдоль лески,
## а добыча оказалась в изгибе. Изображения нет — крюк рисуется сам.
##
## Тянет крюк по-настоящему: добыча остаётся физическим телом и едет по столу
## сама, расталкивая всё на пути ([method IngredientNode.apply_drag_force] той
## же пружиной, что и перетаскивание мышью, только жёсткость своя —
## [member HookAbility.pull_stiffness]). Подтягивание кончается, когда добыча
## доехала до своей точки — середины половины хозяина — или когда вышел таймаут
## ([member HookAbility.pull_timeout]): ингредиент мог упереться в стену или
## застрять в куче. Дошла — узел шлёт [signal ingredient_delivered], и режим
## боя гасит добычу намертво и останавливает стол.
class_name HookNode
extends Node2D

## Крюк зацепился за ингредиент — режим боя показывает сообщение.
signal ingredient_hooked(node: IngredientNode)

## Добыча доехала до своей точки на половине хозяина (или крюк сдался по
## таймауту) и отпущена — режим боя гасит её намертво и останавливает стол.
signal ingredient_delivered(node: IngredientNode)

var ability: HookAbility

var _sprite: Sprite2D
var _rng: RandomNumberGenerator
## Точка заброса за краем стола: из неё тянется леска.
var _rod := Vector2.ZERO
## Ушко крюка относительно точки зацепа — с учётом текущего разворота.
## К нему привязана леска.
var _eye := Vector2.ZERO


static func create(hook: HookAbility, rng: RandomNumberGenerator = null) -> HookNode:
	var node := HookNode.new()
	node.ability = hook
	node._rng = rng if rng != null else RandomNumberGenerator.new()
	node.z_index = hook.draw_z_index
	return node


func _ready() -> void:
	# Изображение вешается за точку зацепа ([member HookAbility.hook_anchor]):
	# origin узла — место, которым крюк держит добычу (у Hook.png — изгиб).
	# Отражение ([member HookAbility.mirror]) и доворот
	# ([member HookAbility.image_rotation]) идут вокруг того же origin,
	# поэтому зацеп по-прежнему приходит ровно на цель.
	_sprite = Sprite2D.new()
	_sprite.centered = false
	_sprite.scale = Vector2(
			-ability.image_scale if ability.mirror else ability.image_scale,
			ability.image_scale)
	_sprite.texture = ability.texture
	if ability.texture != null:
		_sprite.offset = -ability.hook_anchor * ability.texture.get_size()
	add_child(_sprite)
	visible = false


## Полный проход способности: заброс к каждой цели, подтягивание её в свою
## точку на половине хозяина и уход со стола. targets и reel_points идут парами.
## rod — точка заброса за краем стола.
func run_pull(targets: Array[IngredientNode], reel_points: Array[Vector2],
		rod: Vector2) -> void:
	_rod = rod
	position = rod
	_aim()
	visible = true
	for i in targets.size():
		var target := targets[i]
		if not is_instance_valid(target):
			continue
		# Заброс: крюк приходит на ингредиент по дуге.
		await _travel(target.global_position, ability.cast_duration)
		await _wait(ability.hook_pause)
		ingredient_hooked.emit(target)
		await _reel(target, reel_points[i])
	# Уходит со стола по прямой — без дуги.
	await _travel(rod, ability.retreat_duration, true)
	visible = false


## Подтягивание: крюк сидит в ингредиенте и едет вместе с ним, а сам ингредиент
## тянется пружиной к точке reel_point — середине половины хозяина. Тянет до
## самого конца: кончается, только когда добыча доехала до точки (ближе
## [member HookAbility.arrive_distance]) или когда вышел таймаут — добыча
## упёрлась в стену или застряла в куче.
func _reel(target: IngredientNode, reel_point: Vector2) -> void:
	# Жёсткость лески на время подтягивания подменяет собственную жёсткость
	# перетаскивания ингредиента; после — возвращается как была.
	var own_stiffness := target.drag_stiffness
	target.drag_stiffness = ability.pull_stiffness
	target.start_drag(target.global_position)
	var elapsed := 0.0
	while elapsed < ability.pull_timeout:
		await get_tree().physics_frame
		if not is_instance_valid(target):
			return
		elapsed += get_physics_process_delta_time()
		target.apply_drag_force(reel_point)
		global_position = target.grab_point_global()
		_aim()
		if target.grab_point_global().distance_to(reel_point) <= ability.arrive_distance:
			break
	target.end_drag()
	target.drag_stiffness = own_stiffness
	# Добыча на месте — режим боя гасит её намертво (иначе поданная за этот
	# кадр сила пружины протащит её мимо точки) и останавливает стол, чтобы
	# расталканные соседи не разъезжались дальше.
	ingredient_delivered.emit(target)
	await _wait(ability.settle_pause)


## Перелёт в точку to за duration секунд. Обычно путь — дуга с разбросом;
## straight — строго по прямой (так крюк уходит со стола).
func _travel(to: Vector2, duration: float, straight := false) -> void:
	if duration <= 0.0:
		position = to
		_aim()
		return
	var from := position
	var direction := to - from
	var sideways := direction.orthogonal().normalized() if direction.length() > 0.01 \
			else Vector2.UP
	# Середина пути уводится вбок — путь получается дугой, а не прямой.
	var arc := 0.0 if straight else ability.path_arc \
			+ _rng.randf_range(-ability.path_arc_random, ability.path_arc_random)
	var control := from.lerp(to, 0.5) + sideways * arc
	var elapsed := 0.0
	while elapsed < duration:
		await get_tree().process_frame
		elapsed = minf(elapsed + get_process_delta_time(), duration)
		# Плавный разгон и торможение по дуге Безье.
		var t := ease(elapsed / duration, -1.6)
		position = from.lerp(control, t).lerp(control.lerp(to, t), t)
		_aim()
	position = to
	_aim()


func _wait(seconds: float) -> void:
	if seconds <= 0.0:
		return
	await get_tree().create_timer(seconds).timeout


## Разворот крюка и перерисовка лески. Крюк висит на леске, поэтому смотрит
## ушком на удилище, а изгибом с добычей — от него; сверху идёт доворот
## [member HookAbility.image_rotation], которым цевьё кладут вдоль лески.
## Разворот идёт вокруг точки зацепа (origin узла), так что наводка
## на ингредиент не сбивается.
func _aim() -> void:
	var rest := _eye_rest()
	var turn := deg_to_rad(ability.image_rotation)
	if not ability.aim_at_rod or rest.length() < 0.01:
		_sprite.rotation = turn
		_eye = rest.rotated(turn)
		queue_redraw()
		return
	var to_rod := _rod - position
	if to_rod.length() > 0.01:
		_sprite.rotation = to_rod.angle() - rest.angle() + turn
	_eye = rest.rotated(_sprite.rotation)
	queue_redraw()


## Где сидит ушко относительно точки зацепа на неразвёрнутом изображении, px.
## Изображения нет — ушка тоже нет: леска идёт прямо в зацеп.
func _eye_rest() -> Vector2:
	if ability.texture == null:
		return Vector2.ZERO
	var offset := (ability.eye_anchor - ability.hook_anchor) \
			* ability.texture.get_size() * ability.image_scale
	if ability.mirror:
		offset.x = -offset.x
	return offset


func _draw() -> void:
	# Леска: от удилища за краем стола до ушка крюка (у рисованного крюка
	# ушка нет — леска приходит прямо в зацеп, в origin узла).
	draw_line(to_local(_rod), _eye, ability.line_color, ability.line_width)
	if ability.texture != null:
		return
	# Изображения нет — крюк рисуется сам: цевьё сверху, загиб под ним
	# и короткое жало. Точка зацепа — origin, начало загиба.
	var r := ability.hook_size
	var width := ability.line_width * 1.6
	draw_line(Vector2(0.0, -r * 2.4), Vector2.ZERO, ability.hook_color, width)
	draw_arc(Vector2(-r, 0.0), r, 0.0, PI, 12, ability.hook_color, width)
	draw_line(Vector2(-r * 2.0, 0.0), Vector2(-r * 1.5, -r * 0.9),
			ability.hook_color, width)
