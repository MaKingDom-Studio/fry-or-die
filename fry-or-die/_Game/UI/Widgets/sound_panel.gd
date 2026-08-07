## Звук во время игры: кнопка в правом верхнем углу
## ([SoundButton], `_Game/Art/UI/Button_Sound.png`) и крутилка громкости
## ([VolumeKnob]) — та же сковорода, что в главном меню.
##
## Крутилка живёт за правым краем экрана: по нажатию кнопки она выезжает
## оттуда, по второму нажатию — уезжает обратно. Пока крутилка убрана, её
## узел спрятан, поэтому мышь она не ловит и игре не мешает.
##
## Сам узел прибит к правому верхнему углу окна, а отступы кнопки
## и крутилки от угла лежат в их позициях внутри сцены — так до звука
## дотянешься на любом экране. Убранное положение крутилки — сдвиг
## [member hidden_offset] от её места в сцене.
##
## Панель кладут в игровые локации (`l_combat`, `l_map`, `l_shop`)
## последним узлом и поверх всей сцены по `z_index` — выше окон награды
## и финала: до звука дотягиваешься в любой момент боя, и крутилка не
## ныряет под затемнение чужого окна. Мышь панели тоже достаётся раньше
## остального: клик по кнопке или крутилке не проваливается в игру.
class_name SoundPanel
extends Node2D

## Куда уезжает крутилка от своего места в сцене: за правый край окна.
## Сдвига должно хватать на всю сковороду с ручкой — иначе убранная
## крутилка выглядывала бы из-за края.
@export var hidden_offset := Vector2(270.0, 0.0)
## За сколько секунд крутилка выезжает и уезжает.
@export_range(0.01, 2.0, 0.01, "or_greater") var slide_time := 0.22

var _button: SoundButton
var _slide: Node2D
## Место выехавшей крутилки — как она стоит в сцене.
var _slide_home := Vector2.ZERO
## Крутилку позвали на экран (кнопку нажали нечётный раз).
var _open := false
## Насколько крутилка выехала: 0 — убрана целиком, 1 — на месте.
var _shift := 0.0


func _ready() -> void:
	# Звук должен слушаться и на паузе — как и сам [AudioDirector].
	process_mode = Node.PROCESS_MODE_ALWAYS
	_button = get_node_or_null("Button") as SoundButton
	_slide = get_node_or_null("Slide") as Node2D
	if _slide != null:
		_slide_home = _slide.position
	if _button != null:
		_button.pressed.connect(toggle)
	_place()
	get_viewport().size_changed.connect(_place)
	_apply_shift()


## Крутилка на экране.
func is_open() -> bool:
	return _open


## Позвать крутилку на экран или убрать её обратно.
func toggle() -> void:
	set_open(not _open)


## Показать или убрать крутилку.
func set_open(value: bool) -> void:
	if _open == value:
		return
	_open = value
	Audio.play(AudioDirector.CLICK)


func _process(delta: float) -> void:
	var next := move_toward(_shift, 1.0 if _open else 0.0, delta / slide_time)
	if next == _shift:
		return
	_shift = next
	_apply_shift()


## Прибить панель к правому верхнему углу окна.
func _place() -> void:
	position = Vector2(get_viewport_rect().size.x, 0.0)


## Поставить крутилку по тому, насколько она выехала.
func _apply_shift() -> void:
	if _slide == null:
		return
	# Ход со сглаживанием на концах: крутилка трогается и встаёт мягко.
	var eased := _shift * _shift * (3.0 - 2.0 * _shift)
	_slide.position = _slide_home + hidden_offset * (1.0 - eased)
	# Убранная крутилка спрятана: спрятанная мышь не ловит.
	_slide.visible = _shift > 0.001
