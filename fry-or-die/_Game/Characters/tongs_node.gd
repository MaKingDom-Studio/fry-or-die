## Щипцы на боевом столе: прилетают из-за края стола, хватают ингредиент и
## уносят его на половину своей стороны. Ими пользуются обе стороны —
## минибосс «Tongie» (справа снизу, добыча с нейтральной зоны) и игрок с
## инструментом «Щипцы» ([ToolTongs]) (слева снизу, добыча с половины врага).
##
## Узел живёт ровно одно применение способности ([TongsAbility]): режим боя
## создаёт его перед показом кнопки «Обратный отсчёт», ждёт [method run_steal]
## и убирает. Полёт — квадратичная кривая с боковым отклонением и мелким
## покачиванием, которое гаснет к цели, поэтому движение неровное, но губки
## приходят точно на ингредиент. Схваченный ингредиент висит на точке
## захвата ([member TongsAbility.grab_anchor]) и едет вместе с щипцами.
class_name TongsNode
extends Node2D

## Щипцы сомкнулись на ингредиенте — режим боя показывает сообщение.
signal ingredient_grabbed(node: IngredientNode)

var ability: TongsAbility
## Физика падения ингредиента из разжатых губок (из [CombatConfig]).
var drop_gravity := 2600.0
var drop_bounce := 0.3

var _sprite: Sprite2D
var _held: IngredientNode
var _rng: RandomNumberGenerator


static func create(tongs: TongsAbility, config: CombatConfig,
		rng: RandomNumberGenerator = null) -> TongsNode:
	var node := TongsNode.new()
	node.ability = tongs
	node.drop_gravity = config.drop_gravity
	node.drop_bounce = config.drop_bounce
	node._rng = rng if rng != null else RandomNumberGenerator.new()
	node.z_index = tongs.draw_z_index
	return node


func _ready() -> void:
	_sprite = Sprite2D.new()
	# Изображение вешается за точку захвата: origin узла — между губками.
	# Отражение ([member TongsAbility.mirror]) идёт вокруг того же origin,
	# поэтому губки по-прежнему смыкаются ровно на цели.
	_sprite.centered = false
	_sprite.scale = Vector2(
			-ability.image_scale if ability.mirror else ability.image_scale,
			ability.image_scale)
	add_child(_sprite)
	_set_jaws(false)
	visible = false


## Полный проход способности: прилёт, захват каждой цели с переносом в свою
## точку на половине врага и уход со стола. targets и drop_points идут парами.
func run_steal(targets: Array[IngredientNode], drop_points: Array[Vector2],
		home: Vector2) -> void:
	position = home
	_set_jaws(false)
	visible = true
	for i in targets.size():
		var target := targets[i]
		if not is_instance_valid(target):
			continue
		# Наводка: губки приходят на ингредиент разжатыми.
		await _travel(target.global_position, ability.approach_duration)
		_set_jaws(true)
		await _wait(ability.grab_pause)
		target.hold_begin(ability.carried_z_index)
		_held = target
		ingredient_grabbed.emit(target)
		# Перенос на половину врага и сброс.
		await _travel(drop_points[i], ability.carry_duration)
		_set_jaws(false)
		if is_instance_valid(_held):
			_held.hold_release(ability.drop_height, drop_gravity, drop_bounce)
		_held = null
		await _wait(ability.release_pause)
	# Уходят со стола по прямой — без дуги и покачивания.
	await _travel(home, ability.retreat_duration, true)
	visible = false


## Перелёт в точку to за duration секунд. Обычно путь — дуга с разбросом и
## мелким покачиванием; straight — строго по прямой, без отклонений (так
## щипцы уходят со стола). Схваченный ингредиент едет за губками.
func _travel(to: Vector2, duration: float, straight := false) -> void:
	if duration <= 0.0:
		position = to
		_pull_held()
		return
	var from := position
	var direction := to - from
	var sideways := direction.orthogonal().normalized() if direction.length() > 0.01 \
			else Vector2.UP
	# Середина пути уводится вбок — путь получается дугой, а не прямой.
	var arc := 0.0 if straight else ability.path_arc \
			+ _rng.randf_range(-ability.path_arc_random, ability.path_arc_random)
	var control := from.lerp(to, 0.5) + sideways * arc
	var wobble := 0.0 if straight else ability.wobble_amplitude
	var tilt := 0.0 if straight else ability.tilt
	var phase := _rng.randf() * TAU
	var elapsed := 0.0
	while elapsed < duration:
		await get_tree().process_frame
		elapsed = minf(elapsed + get_process_delta_time(), duration)
		# Плавный разгон и торможение по дуге Безье.
		var t := ease(elapsed / duration, -1.6)
		var point := from.lerp(control, t).lerp(control.lerp(to, t), t)
		# Мелкое покачивание; к концу гаснет, чтобы губки легли точно на цель.
		var fade := 1.0 - t
		point += Vector2(
				sin(phase + t * TAU * ability.wobble_speed),
				cos(phase * 1.7 + t * TAU * ability.wobble_speed * 0.8)
		) * wobble * fade
		position = point
		rotation = sin(phase + t * TAU * ability.wobble_speed * 0.5) * tilt * fade
		_pull_held()
	position = to
	rotation = 0.0
	_pull_held()


func _pull_held() -> void:
	if is_instance_valid(_held):
		_held.hold_move(global_position)


func _wait(seconds: float) -> void:
	if seconds <= 0.0:
		return
	await get_tree().create_timer(seconds).timeout


## Сомкнуть или разжать губки: меняется изображение, точка захвата остаётся
## в origin узла.
func _set_jaws(closed: bool) -> void:
	var texture := ability.close_texture if closed else ability.open_texture
	_sprite.texture = texture
	if texture != null:
		_sprite.offset = -ability.grab_anchor * texture.get_size()
