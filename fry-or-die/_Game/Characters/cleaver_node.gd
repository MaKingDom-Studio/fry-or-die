## Тесак на боевом столе: падает на центр стола, рубит и уходит обратно вверх.
## Им пользуется минибосс «Barbara» (задетое едет к ней) и игрок с тесаком
## в инструментах ([ToolCleaver]) — тогда задетое едет к игроку. Куда именно,
## решает не узел: сторону сдвига ему передают в [method run_strike].
##
## Стол виден сверху, поэтому тесак виден только сверху
## ([member CleaverAbility.texture], Cleaver_TOP). Высоту заменяет масштаб:
## лезвие появляется прямо над центром стола крупным и полупрозрачным (оно
## занесено высоко), уменьшается и уплотняется, пока падает, и приходит на
## стол в свой настоящий размер — это и есть касание. Уходит так же: растёт
## и тает.
##
## Узел живёт ровно одно применение способности ([CleaverAbility]): режим боя
## создаёт его перед показом кнопки «Обратный отсчёт», ждёт [method run_strike]
## и убирает. Разгон ингредиентов — не дело узла: он шлёт [signal blade_landed]
## с полосой удара и [signal blade_pushed] на старте сдвига, а подскоки и
## движение раздаёт режим боя.
class_name CleaverNode
extends Node2D

## Лезвие легло на стол: band — полоса удара в глобальных координатах
## (прямоугольник лежащего лезвия). Режим боя подбрасывает всё, что вне неё,
## и запоминает задетое.
signal blade_landed(band: Rect2)

## Лезвие поехало в свою сторону: velocity — скорость сдвига, duration —
## сколько он длится. Режим боя везёт задетое с той же скоростью.
signal blade_pushed(velocity: Vector2, duration: float)

var ability: CleaverAbility

var _sprite: Sprite2D


static func create(cleaver: CleaverAbility) -> CleaverNode:
	var node := CleaverNode.new()
	node.ability = cleaver
	node.z_index = cleaver.draw_z_index
	return node


func _ready() -> void:
	# Лезвие стоит ровно на точке удара: origin узла — линия удара, а масштаб
	# узла играет высоту, поэтому лезвие растёт и уменьшается «в центр».
	_sprite = Sprite2D.new()
	_sprite.texture = ability.texture
	_sprite.position = ability.blade_offset
	_sprite.scale = Vector2.ONE * _blade_scale()
	add_child(_sprite)
	visible = false


## Полный проход способности: появление над точкой point, падение, удар,
## пауза с лезвием на столе, медленный сдвиг на push_dir и уход вверх.
## push_dir — куда лезвие увозит задетое (единичный вектор в сторону хозяина
## удара: у врага — к нему, у игрока — к игроку).
func run_strike(point: Vector2, push_dir := Vector2.RIGHT) -> void:
	position = point
	visible = true
	# Появление: тесак занесён высоко над центром — крупный и полупрозрачный.
	_set_pose(ability.entry_scale, ability.raise_tilt, ability.entry_alpha)
	# Замах: лезвие проявляется и опускается — то есть уменьшается.
	await _drop_to(ability.raise_scale, ability.raise_tilt, 1.0,
			ability.raise_duration, -1.6)
	# Удар: остаток высоты уходит рывком, лезвие садится в свой размер.
	await _drop_to(1.0, 0.0, 1.0, ability.chop_duration, 2.4)
	blade_landed.emit(hit_band())
	await _wait(ability.hold_pause)
	# Сдвиг: лезвие медленно едет с центра в свою сторону и увозит задетое.
	var push_time := ability.push_duration()
	if push_time > 0.0:
		blade_pushed.emit(push_dir * ability.push_speed, push_time)
		await _move_to(position + push_dir * ability.push_distance, push_time)
	# Уход: лезвие поднимается — снова растёт и тает.
	await _drop_to(ability.entry_scale, ability.raise_tilt, 0.0,
			ability.retreat_duration, -1.6)
	visible = false


## Полоса удара в глобальных координатах: прямоугольник лежащего лезвия
## с запасом [member CleaverAbility.hit_grow]. Всё, что её не касается,
## удар только подбрасывает.
func hit_band() -> Rect2:
	if ability.texture == null:
		return Rect2(global_position, Vector2.ZERO)
	var blade := ability.texture.get_size() * _sprite.global_scale
	var band := Rect2(_sprite.global_position - blade / 2.0, blade)
	return band.grow(ability.hit_grow)


## Масштаб изображения: длина лезвия задана в пикселях стола, пропорции
## изображения сохраняются.
func _blade_scale() -> float:
	if ability.texture == null:
		return 1.0
	var height := ability.texture.get_size().y
	if height <= 0.0:
		return 1.0
	return ability.blade_length / height


## Поза лезвия: масштаб играет высоту над столом, прозрачность — дальность.
func _set_pose(blade_scale: float, tilt: float, alpha: float) -> void:
	scale = Vector2.ONE * blade_scale
	rotation = tilt
	modulate.a = alpha


## Смена высоты: за duration секунд лезвие переходит в масштаб to_scale
## с доворотом до to_rotation и прозрачностью to_alpha. curve — та же кривая,
## что у [method @GlobalScope.ease]: -1.6 — плавный разгон и торможение,
## 2.4 — разгон к концу (сам удар).
func _drop_to(to_scale: float, to_rotation: float, to_alpha: float,
		duration: float, curve: float) -> void:
	if duration <= 0.0:
		_set_pose(to_scale, to_rotation, to_alpha)
		return
	var from_scale := scale.x
	var from_rotation := rotation
	var from_alpha := modulate.a
	var elapsed := 0.0
	while elapsed < duration:
		await get_tree().process_frame
		elapsed = minf(elapsed + get_process_delta_time(), duration)
		var t := ease(elapsed / duration, curve)
		_set_pose(lerpf(from_scale, to_scale, t), lerpf(from_rotation, to_rotation, t),
				lerpf(from_alpha, to_alpha, t))
	_set_pose(to_scale, to_rotation, to_alpha)


## Переезд лежащего лезвия по столу в точку to за duration секунд — ровно,
## без разгона: с этой же скоростью едет задетое.
func _move_to(to: Vector2, duration: float) -> void:
	if duration <= 0.0:
		position = to
		return
	var from := position
	var elapsed := 0.0
	while elapsed < duration:
		await get_tree().process_frame
		elapsed = minf(elapsed + get_process_delta_time(), duration)
		position = from.lerp(to, elapsed / duration)
	position = to


func _wait(seconds: float) -> void:
	if seconds <= 0.0:
		return
	await get_tree().create_timer(seconds).timeout
