## Крутилка громкости — сковорода с ручкой: в главном меню она стоит
## в левом нижнем углу, а во время игры выезжает из-за правого края
## по кнопке звука ([SoundPanel]).
##
## Собрана из двух картинок: `Pan.png` (сама сковорода) и `Pan_Handle.png`
## (ручка). Сковорода стоит неподвижно — это шкала и подложка надписи;
## крутится вокруг её центра только ручка, как у настоящего регулятора.
##
## Угол ручки — это и есть громкость: [member angle_at_zero_deg] — тишина,
## [member angle_at_full_deg] — полный звук, между ними всё линейно. Крутить
## можно протяжкой мыши за сковороду или ручку и колесом над ними.
##
## На сковороде написано, за что крутилка отвечает: пока ручку не взяли —
## слово [member idle_text] («VOLUME»), а как взяли — сколько сейчас
## звука, числом от 0 до 100. После щелчка колеса число висит ещё
## [member label_hold_seconds] секунд и само сменяется обратно на слово.
## Надпись — узел `Label` внутри крутилки (её вид настраивается в сцене);
## без него крутилка работает как обычно, просто молча.
##
## Спрятанную крутилку мышь не трогает: так её можно убирать за край
## экрана ([SoundPanel] во время игры), не мешая игре под ней.
##
## Саму громкость крутилка не хранит: она показывает и меняет громкость
## звукового синглтона ([AudioDirector], автозагрузка `Audio`) — там она и
## применяется к микшеру, и переживает перезапуск игры.
class_name VolumeKnob
extends Node2D

## Громкость поменялась (0 — тишина, 1 — полный звук).
signal volume_changed(volume: float)

@export_group("Ход крутилки")
## Угол ручки при нулевой громкости, град.
@export var angle_at_zero_deg := 50.0
## Угол ручки при полной громкости, град.
@export var angle_at_full_deg := -25.0
## На сколько меняет громкость один щелчок колеса мыши.
@export_range(0.01, 0.5, 0.01) var wheel_step := 0.05

@export_group("Захват мышью")
## Радиус сковороды, за который её можно схватить (в координатах картинки).
@export var pan_radius := 200.0
## Насколько шире картинки хватается ручка, px (может быть < 0).
@export var handle_padding := 6.0

@export_group("Надпись")
## Что написано на сковороде, пока ручку не трогают.
@export var idle_text := "VOLUME"
## Сколько секунд число держится после щелчка колеса: колесо ручку не
## «берёт», но показать результат всё равно надо.
@export var label_hold_seconds := 1.2

var _pan: Sprite2D
var _handle: Sprite2D
var _label: Label
var _volume := 1.0
## Место и поворот ручки, как она стоит в сцене: это её вид при угле 0,
## от него и отсчитывается поворот.
var _handle_rest_offset := Vector2.ZERO
var _handle_rest_angle := 0.0
## Текущий угол ручки, рад.
var _angle := 0.0
## Крутилку тянут мышью.
var _dragging := false
## Разница между углом на мышь и углом ручки в миг захвата: чтобы ручка
## не прыгала под курсор, а доворачивалась от того места,
## за которое её схватили.
var _grab_offset := 0.0
## Сколько ещё секунд показывать число после щелчка колеса.
var _hold_left := 0.0
## Что написано на сковороде сейчас — чтобы не дёргать Label каждый кадр.
var _shown_text := ""


func _ready() -> void:
	_pan = get_node_or_null("Pan") as Sprite2D
	_handle = get_node_or_null("Pan/Handle") as Sprite2D
	_label = get_node_or_null("Label") as Label
	if _handle != null:
		_handle_rest_offset = _handle.position
		_handle_rest_angle = _handle.rotation
	# Крутится только ручка: сама сковорода стоит ровно, даже если поворот
	# остался в сцене с прежней версии крутилки.
	rotation = 0.0
	set_volume(Audio.get_volume(), false)
	_refresh_label()


## Текущая громкость: 0 — тишина, 1 — полный звук.
func get_volume() -> float:
	return _volume


## Поставить громкость: довернуть ручку и отдать её звуку игры.
func set_volume(value: float, notify := true) -> void:
	var next := clampf(value, 0.0, 1.0)
	_volume = next
	_angle = deg_to_rad(lerpf(angle_at_zero_deg, angle_at_full_deg, next))
	_turn_handle()
	# Пишем в настройки только на отпускании: на протяжке громкость меняется
	# каждый кадр, и файл незачем трогать так часто.
	Audio.set_volume(next, false)
	if notify:
		volume_changed.emit(next)


## Попадает ли точка экрана в крутилку: сковорода ловит по кругу,
## ручка — по своей картинке.
func has_point(global_point: Vector2) -> bool:
	if _pan != null and _pan.to_local(global_point).length() <= pan_radius:
		return true
	return _handle != null \
			and _handle.get_rect().grow(handle_padding).has_point(_handle.to_local(global_point))


func _process(delta: float) -> void:
	if _hold_left > 0.0:
		_hold_left = maxf(_hold_left - delta, 0.0)
	_refresh_label()


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		# Крутилку убрали прямо во время протяжки — отпускаем ручку сами,
		# иначе она так и осталась бы «схваченной» до следующего показа.
		_drop_handle()
		return
	var button := event as InputEventMouseButton
	if button != null:
		_handle_button(button)
		return
	var motion := event as InputEventMouseMotion
	if _dragging and motion != null:
		_turn_to(motion.global_position)
		get_viewport().set_input_as_handled()


func _handle_button(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if not has_point(event.global_position):
				return
			_dragging = true
			_grab_offset = wrapf(_angle_to(event.global_position) - _angle, -PI, PI)
			get_viewport().set_input_as_handled()
		elif _dragging:
			_drop_handle()
			get_viewport().set_input_as_handled()
		return
	if not event.pressed or not has_point(event.global_position):
		return
	if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		set_volume(_volume + wheel_step)
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		set_volume(_volume - wheel_step)
	else:
		return
	# Колесо ручку не «берёт», поэтому число само не задержалось бы
	# на сковороде — держим его несколько секунд.
	_hold_left = label_hold_seconds
	Audio.set_volume(_volume)
	get_viewport().set_input_as_handled()


## Отпустить ручку и записать наконец громкость в настройки: на протяжке
## её туда не пишут, чтобы не трогать файл каждый кадр.
func _drop_handle() -> void:
	if not _dragging:
		return
	_dragging = false
	Audio.set_volume(_volume)


## Довернуть ручку вслед за курсором и пересчитать из угла громкость.
func _turn_to(global_point: Vector2) -> void:
	var degrees := rad_to_deg(wrapf(_angle_to(global_point) - _grab_offset, -PI, PI))
	set_volume(inverse_lerp(angle_at_zero_deg, angle_at_full_deg, degrees))


## Поставить ручку на текущий угол: она обходит центр сковороды по кругу
## и поворачивается вместе с ним — сама сковорода при этом не двигается.
func _turn_handle() -> void:
	if _handle == null:
		return
	_handle.position = _handle_rest_offset.rotated(_angle)
	_handle.rotation = _handle_rest_angle + _angle


## Угол от центра сковороды на точку экрана, рад.
func _angle_to(global_point: Vector2) -> float:
	return (global_point - global_position).angle()


## Ручку сейчас держат — на сковороде число, а не слово.
func _shows_number() -> bool:
	return _dragging or _hold_left > 0.0


func _refresh_label() -> void:
	if _label == null:
		return
	var text := str(roundi(_volume * 100.0)) if _shows_number() else idle_text
	if text == _shown_text:
		return
	_shown_text = text
	_label.text = text
