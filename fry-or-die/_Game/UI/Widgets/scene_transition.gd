@tool
## Переход сцены кляксой: экран закрывается и открывается по шейдеру
## `_Game/Art/Shaders/transition_pattern.gdshader`.
##
## Заливка раскрывается из центра, а её кромка рвётся узором — получаются
## кляксы с дырами. Всё это один параметр шейдера `factor`: 0 — экран открыт,
## 1 — закрыт целиком, поэтому оба направления это один и тот же переход:
## [method play_in] гонит 1 → 0 (уровень запускается, картинка проявляется),
## [method play_out] — 0 → 1, тот же переход в обратном порядке, под загрузку
## локации.
##
## Узел — ColorRect на весь вьюпорт (шейдеру нужны UV прямоугольника), кликов
## не перехватывает и лежит выше всего остального (в l_combat.tscn z 140).
## Материал перехода назначается узлу в сцене; в рантайме берётся его копия,
## чтобы параметры анимации не писались в .tres. Вид узора (градиент, узор
## кромки, мягкость) настраивается в материале
## `_Game/Data/Combat/FX/da_transition.tres`; чтобы посмотреть переход в
## редакторе, достаточно подвинуть в нём `factor`.
class_name SceneTransition
extends ColorRect

## Сколько длится переход в одну сторону, с.
@export_range(0.1, 5.0, 0.05, "or_greater") var duration := 0.9
## Экран закрыт на старте сцены: он откроется первым же [method play_in].
## Выключено — сцена начинается с открытого экрана.
@export var start_covered := true

var _factor := 0.0


func _ready() -> void:
	# Переход только рисуется: клики уходят сквозь него к столу.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fit_viewport()
	get_viewport().size_changed.connect(_fit_viewport)
	if Engine.is_editor_hint():
		return
	# Своя копия материала: параметры перехода крутятся в рантайме и не должны
	# уезжать в общий .tres.
	var shared := material as ShaderMaterial
	if shared != null:
		material = shared.duplicate()
	_set_factor(1.0 if start_covered else 0.0)
	visible = start_covered


## Открыть экран: уровень проявляется из-под заливки. Вызывающий ждёт конца.
func play_in(seconds := -1.0) -> void:
	await _play(1.0, 0.0, seconds)


## Закрыть экран — тот же переход в обратном порядке. Вызывающий ждёт конца
## и только потом грузит локацию.
func play_out(seconds := -1.0) -> void:
	await _play(0.0, 1.0, seconds)


## Идёт ли переход прямо сейчас.
func is_playing() -> bool:
	return visible and _factor > 0.0 and _factor < 1.0


func _play(from: float, to: float, seconds: float) -> void:
	var length := seconds if seconds > 0.0 else duration
	if material == null:
		visible = to > 0.5
		return
	visible = true
	_set_factor(from)
	var tween := create_tween()
	tween.tween_method(_set_factor, from, to, maxf(length, 0.01))
	await tween.finished
	# Открытый экран не рисуем вовсе.
	visible = to > 0.5


func _set_factor(value: float) -> void:
	_factor = clampf(value, 0.0, 1.0)
	var mat := material as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter("factor", _factor)


## Растянуть узел на весь вьюпорт и сообщить шейдеру размер — по нему он
## выправляет пропорции кляксы.
func _fit_viewport() -> void:
	var view := get_viewport_rect().size
	global_position = Vector2.ZERO
	size = view
	# В редакторе материал не трогаем: он общий, и правка параметров пометила бы
	# .tres изменённым на ровном месте.
	if Engine.is_editor_hint():
		return
	var mat := material as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter("node_resolution", view)
