@tool
## Оверлей фазы горелки: свет уходит со всей сцены, кроме стола.
##
## Пока горелка ждёт клика, тень накрывает весь экран, кроме окна над полем
## ([member hole_margin] вокруг границ стола): фон, корзины, полка и HUD
## гаснут, а стол с ингредиентами остаётся на свету — видно, из чего выбирать
## жертву. Поверх тени — дрожащая надпись шрифтом имён (Grunge Bold V2, см.
## [UiFont] и [HudNameLabel]) и кнопка «SKIP» из готовой картинки
## (Art/Tools/Button_Skip.png). Пока курсор над полем, системная стрелка
## спрятана — за мышью ходит сама горелка, соплом в точку клика.
##
## Клики оверлей разбирает сам: по кнопке — сигнал [signal skipped], мимо
## поля — глотаются (затемнённые кнопки HUD и мешок под тенью не работают),
## по полю — проходят вниз, к режиму боя (`gm_combat._try_burn_at`).
## Открывает и закрывает оверлей режим боя: [method open] на входе в фазу
## BURN, [method lock] после клика по ингредиенту (надпись, кнопка и горелка
## уходят, тень висит до конца растворения), [method close] в конце фазы.
## Узла может не быть в сцене — тогда HUD рисует запасной баннер
## (`CombatHud._draw_burn_banner`).
class_name BurnOverlay
extends Node2D

## Нажата кнопка «SKIP» — игрок отказался жечь.
signal skipped

@export_group("Затемнение")
## Цвет и максимальная плотность тени.
@export var dim := Color(0.0, 0.0, 0.0, 0.72)
## Сколько секунд тень наплывает.
@export_range(0.0, 3.0, 0.05, "or_greater") var fade_in_duration := 0.3
## Сколько секунд свет возвращается.
@export_range(0.0, 3.0, 0.05, "or_greater") var fade_out_duration := 0.25
## Насколько светлое окно шире границ стола, px.
@export var hole_margin := 30.0

@export_group("Надпись")
@export var title := "Burn one ingredient!"
## Шрифт надписи. Пусто — шрифт проекта (Grunge Bold V2), как у имён.
@export var font: Font
@export_range(6, 200, 1, "or_greater") var title_font_size := 40
## Центр надписи на экране.
@export var title_pos := Vector2(576, 226)
@export var title_color := Color(0.98, 0.9, 0.62)
## Тёмная обводка букв — надпись читается и над тенью, и над столом.
@export var title_outline_size := 8
@export var title_outline_color := Color(0.12, 0.09, 0.06, 0.85)
## Дрожь букв — как у имён сторон ([HudNameLabel]).
@export var jitter_amount := 0.44
@export var jitter_speed := 6.0
@export var jitter_rotation := 2.5

@export_group("Кнопка SKIP")
## Картинка кнопки (Art/Tools/Button_Skip.png); пусто — прямоугольник-заглушка.
@export var skip_texture: Texture2D
## Центр кнопки на экране.
@export var skip_pos := Vector2(576, 566)
@export var skip_scale := Vector2(0.3, 0.3)
## Насколько кнопка подрастает под курсором (0.06 — на 6%).
@export_range(0.0, 1.0) var hover_swell := 0.06
## Насколько кликабельная область шире картинки, px.
@export var hit_padding := 6.0

@export_group("Горелка у курсора")
## Картинка горелки; пусто — картинка активного инструмента (передаёт режим боя).
@export var cursor_texture: Texture2D
@export var cursor_scale := Vector2(0.24, 0.24)
## Точка сопла на картинке, px исходной картинки: она и стоит под курсором.
## У Burner.png срез сопла упирается в левый верхний угол картинки, его
## верхний угол — почти в (0, 0).
@export var cursor_hotspot := Vector2(6, 10)

@export_group("Редактор")
## Превью в редакторе: нарисовать тень с окном, надпись и кнопку.
@export var editor_preview := false
## Границы стола для превью (в игре приходят из режима боя).
@export var editor_preview_field := Rect2(236, 282, 674, 338)

## Границы стола на текущую фазу (экранные координаты).
var _field := Rect2()
## Картинка активного инструмента — фолбэк для [member cursor_texture].
var _tool_texture: Texture2D
## Текущая плотность тени 0..1, куда она идёт и с какой скоростью.
var _strength := 0.0
var _target := 0.0
var _speed := 0.0
## Идёт фаза: надпись, кнопка и горелка на экране, клики разбираются.
var _interactive := false
## Системная стрелка спрятана — вместо неё рисуется горелка.
var _cursor_hidden := false
var _time := 0.0


## Начать фазу горелки: тень наплывает, появляются надпись, кнопка и горелка
## у курсора. tool_texture — картинка активного инструмента (для курсора).
func open(field: Rect2, tool_texture: Texture2D = null) -> void:
	_field = field
	_tool_texture = tool_texture
	_interactive = true
	_fade_to(1.0, fade_in_duration)


## Клик по ингредиенту сделан: надпись, кнопка и горелка уходят сразу, а тень
## висит, пока растворение не кончится и режим боя не позовёт [method close].
func lock() -> void:
	_interactive = false
	_show_system_cursor()


## Фаза кончилась: свет возвращается.
func close() -> void:
	_interactive = false
	_show_system_cursor()
	_fade_to(0.0, fade_out_duration)


func is_open() -> bool:
	return _interactive or _strength > 0.0


func _fade_to(target: float, duration: float) -> void:
	_target = clampf(target, 0.0, 1.0)
	if duration <= 0.0:
		_strength = _target
		_speed = 0.0
	else:
		_speed = 1.0 / duration
	queue_redraw()


func _exit_tree() -> void:
	_show_system_cursor()


func _process(delta: float) -> void:
	_time += delta
	if Engine.is_editor_hint():
		queue_redraw()
		return
	if not is_open():
		return
	_strength = move_toward(_strength, _target, _speed * delta)
	_update_cursor()
	queue_redraw()


## Пока курсор над столом, стрелка спрятана — за мышь цепляется горелка.
func _update_cursor() -> void:
	var over := _interactive and _hole_rect().has_point(get_global_mouse_position())
	if over and not _cursor_hidden:
		_cursor_hidden = true
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	elif not over:
		_show_system_cursor()


func _show_system_cursor() -> void:
	if _cursor_hidden:
		_cursor_hidden = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _unhandled_input(event: InputEvent) -> void:
	if not _interactive:
		return
	var button := event as InputEventMouseButton
	if button == null or button.button_index != MOUSE_BUTTON_LEFT or not button.pressed:
		return
	var point := get_global_mouse_position()
	if _skip_rect().grow(hit_padding).has_point(point):
		Audio.play(AudioDirector.CLICK)
		skipped.emit()
		get_viewport().set_input_as_handled()
		return
	# Клик мимо стола глотается: затемнённое в фазе горелки не трогается —
	# кнопки HUD и мешок не должны открываться под тенью.
	if not _hole_rect().has_point(point):
		get_viewport().set_input_as_handled()


# --- Отрисовка ---

func _draw() -> void:
	var editor := Engine.is_editor_hint()
	if editor and not editor_preview:
		return
	var strength := 1.0 if editor else _strength
	if strength <= 0.0:
		return
	_draw_dim(_hole_rect(), strength)
	# Тень без надписи и кнопки — фаза уже заперта ([method lock]): идёт
	# растворение, выбирать больше нечего.
	if not _interactive and not editor:
		return
	_draw_title()
	_draw_skip_button()
	if not editor:
		_draw_cursor_burner()


## Тень на весь вьюпорт с окном над столом: четыре полосы вокруг окна.
func _draw_dim(hole: Rect2, strength: float) -> void:
	var view := get_viewport_rect()
	var color := Color(dim, dim.a * strength)
	var window := hole.intersection(view)
	if window.size.x <= 0.0 or window.size.y <= 0.0:
		draw_rect(_to_local_rect(view), color)
		return
	var strips := [
		Rect2(view.position, Vector2(view.size.x, window.position.y - view.position.y)),
		Rect2(Vector2(view.position.x, window.end.y),
				Vector2(view.size.x, view.end.y - window.end.y)),
		Rect2(Vector2(view.position.x, window.position.y),
				Vector2(window.position.x - view.position.x, window.size.y)),
		Rect2(Vector2(window.end.x, window.position.y),
				Vector2(view.end.x - window.end.x, window.size.y)),
	]
	for strip in strips:
		var rect := strip as Rect2
		if rect.size.x > 0.0 and rect.size.y > 0.0:
			draw_rect(_to_local_rect(rect), color)


func _draw_title() -> void:
	if title == "":
		return
	# Дрожь — общая для всех дрожащих надписей боя ([JitterText]).
	JitterText.draw_centered(self, UiFont.resolve(font), to_local(title_pos), title,
			title_font_size, title_color, _time, jitter_amount, jitter_speed,
			jitter_rotation, title_outline_size, title_outline_color)


func _draw_skip_button() -> void:
	var rect := _skip_rect()
	var swell := 1.0
	if not Engine.is_editor_hint() \
			and rect.grow(hit_padding).has_point(get_global_mouse_position()):
		swell += hover_swell
	if skip_texture == null:
		draw_rect(_to_local_rect(rect), Color(0.3, 0.3, 0.34, 0.95))
		draw_string(UiFont.resolve(font),
				to_local(Vector2(rect.position.x, rect.get_center().y + 8.0)), "SKIP",
				HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 24, Color(0.95, 0.95, 0.97))
		return
	var size := rect.size * swell
	draw_texture_rect(skip_texture, Rect2(to_local(skip_pos) - size / 2.0, size), false)


## Горелка вместо курсора: пока он над столом, картинка инструмента ходит за
## мышью соплом в точку клика ([member cursor_hotspot]).
func _draw_cursor_burner() -> void:
	var mouse := get_global_mouse_position()
	if not _hole_rect().has_point(mouse):
		return
	var texture := cursor_texture if cursor_texture != null else _tool_texture
	if texture == null:
		return
	var scale_abs := cursor_scale.abs()
	draw_texture_rect(texture,
			Rect2(to_local(mouse) - cursor_hotspot * scale_abs,
					texture.get_size() * scale_abs), false)


## Светлое окно над столом в экранных координатах.
func _hole_rect() -> Rect2:
	var field := editor_preview_field if Engine.is_editor_hint() else _field
	return field.grow(hole_margin)


## Кликабельная область кнопки в экранных координатах. Подрастание под
## курсором её не трогает — кнопка не «убегает» из-под клика.
func _skip_rect() -> Rect2:
	var size := Vector2(182, 90)
	if skip_texture != null:
		size = Vector2(skip_texture.get_size()) * skip_scale.abs()
	return Rect2(skip_pos - size / 2.0, size)


## Экранный прямоугольник в координатах узла. Узел стоит в начале сцены без
## масштаба и поворота, поэтому хватает сдвига начала.
func _to_local_rect(rect: Rect2) -> Rect2:
	return Rect2(to_local(rect.position), rect.size)
