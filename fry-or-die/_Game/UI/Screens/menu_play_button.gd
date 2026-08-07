## Кнопка «PLAY» главного меню: картинка плиты
## (`_Game/Art/Main_Menu/Main_Menu_Button_Play.png`), которая подрастает
## и светлеет под курсором и проседает под нажатием.
##
## Кликается вся картинка целиком ([method has_point]); нажатие считается
## по отпусканию внутри кнопки — увёл курсор до отпускания, значит
## передумал. О нажатии кнопка сообщает сигналом [signal pressed], а куда
## он ведёт, решает [MainMenuScreen].
class_name MenuPlayButton
extends Sprite2D

## Кнопку нажали.
signal pressed

@export_group("Под курсором")
## Насколько кнопка подрастает под курсором: 0.05 — на 5%.
@export var hover_grow := 0.05
## Цвет картинки под курсором (белый — как есть).
@export var hover_tint := Color(1.18, 1.12, 1.02)
## За сколько секунд подсветка разгорается и гаснет.
@export_range(0.01, 1.0, 0.01, "or_greater") var hover_time := 0.12

@export_group("Нажатие")
## Насколько кнопка проседает под нажатием: 0.04 — на 4%.
@export var press_sink := 0.04
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
