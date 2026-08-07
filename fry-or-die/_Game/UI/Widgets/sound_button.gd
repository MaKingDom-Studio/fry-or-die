## Кнопка звука — картинка `_Game/Art/UI/Button_Sound.png` в правом верхнем
## углу игровых локаций.
##
## Кликается вся картинка целиком ([method has_point]); нажатие считается
## по отпусканию внутри кнопки — увёл курсор до отпускания, значит
## передумал. О нажатии кнопка сообщает сигналом [signal pressed], а что
## оно открывает, решает [SoundPanel].
##
## Под курсором картинка подрастает и светлеет, под нажатием проседает —
## так же, как кнопка «PLAY» главного меню ([MenuPlayButton]).
class_name SoundButton
extends Sprite2D

## Кнопку нажали.
signal pressed

@export_group("Под курсором")
## Насколько кнопка подрастает под курсором: 0.08 — на 8%.
@export var hover_grow := 0.08
## Цвет картинки под курсором (белый — как есть).
@export var hover_tint := Color(1.18, 1.12, 1.02)
## За сколько секунд подсветка разгорается и гаснет.
@export_range(0.01, 1.0, 0.01, "or_greater") var hover_time := 0.12

@export_group("Нажатие")
## Насколько кнопка проседает под нажатием: 0.06 — на 6%.
@export var press_sink := 0.06
## За сколько секунд кнопка проседает и возвращается.
@export_range(0.01, 1.0, 0.01, "or_greater") var press_time := 0.06

var _base_scale := Vector2.ONE
## Насколько разгорелась подсветка и насколько просела кнопка: 0..1.
var _hover := 0.0
var _press := 0.0
## Кнопку нажали именно на ней — ждём отпускания.
var _held := false


func _ready() -> void:
	_base_scale = scale


## Попадает ли точка экрана в кнопку.
func has_point(global_point: Vector2) -> bool:
	return get_rect().has_point(to_local(global_point))


func _process(delta: float) -> void:
	var hovered := has_point(get_global_mouse_position())
	_hover = move_toward(_hover, 1.0 if hovered else 0.0, delta / hover_time)
	_press = move_toward(_press, 1.0 if _held and hovered else 0.0, delta / press_time)
	scale = _base_scale * (1.0 + hover_grow * _hover - press_sink * _press)
	modulate = Color.WHITE.lerp(hover_tint, _hover)


func _unhandled_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button == null or button.button_index != MOUSE_BUTTON_LEFT:
		return
	if button.pressed:
		if not has_point(button.global_position):
			return
		_held = true
		get_viewport().set_input_as_handled()
		return
	if not _held:
		return
	_held = false
	if has_point(button.global_position):
		get_viewport().set_input_as_handled()
		pressed.emit()
