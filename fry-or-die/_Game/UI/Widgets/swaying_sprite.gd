@tool
## Спрайт с лёгким покачиванием — например, облака над прилавком магазина.
##
## Обычный [Sprite2D] (текстура, позиция и масштаб настраиваются как всегда),
## который сам себя чуть качает: медленно наклоняется и колышется по
## вертикали. Каждый узел живёт своей жизнью — фаза случайная, поэтому два
## соседних облака никогда не качаются синхронно, даже с одинаковыми
## настройками. Ничего объединять не нужно: скрипт вешается на каждый
## спрайт отдельно.
##
## Качание идёт от исходного положения узла: [member Sprite2D.offset]
## и [member Node2D.rotation] пересчитываются каждый кадр от значений,
## которые стоят в редакторе, — позиция в сцене остаётся точкой покоя.
class_name SwayingSprite
extends Sprite2D

## Максимальный наклон, °. 0 — не наклоняется.
@export var sway_degrees := 3.0:
	set(value):
		sway_degrees = maxf(value, 0.0)

## Период полного качания, с.
@export var sway_period := 3.2:
	set(value):
		sway_period = maxf(value, 0.05)

## Амплитуда вертикального колыхания в экранных пикселях (масштаб узла
## учитывается). 0 — не колышется.
@export var bob_pixels := 3.0:
	set(value):
		bob_pixels = maxf(value, 0.0)

## Период вертикального колыхания, с.
@export var bob_period := 2.1:
	set(value):
		bob_period = maxf(value, 0.05)

## Качаться и в редакторе (иначе там спрайт неподвижен).
@export var animate_in_editor := false

var _time := 0.0
## Своя фаза у каждого спрайта — соседние качаются вразнобой.
var _phase := 0.0
## Точка покоя: поворот и смещение, выставленные в редакторе.
var _base_rotation := 0.0
var _base_offset := Vector2.ZERO


func _ready() -> void:
	_phase = randf_range(0.0, TAU)
	_base_rotation = rotation
	_base_offset = offset


func _process(delta: float) -> void:
	if Engine.is_editor_hint() and not animate_in_editor:
		return
	_time += delta
	rotation = _base_rotation + SwayMotion.tilt(_time, _phase, sway_degrees, sway_period)
	# offset живёт в локальных координатах — делим на масштаб, чтобы
	# амплитуда читалась в экранных пикселях независимо от размера спрайта.
	var bob := SwayMotion.bob(_time, _phase, bob_pixels, bob_period)
	offset = _base_offset + Vector2(0.0, bob / maxf(absf(scale.y), 0.01))
