@tool
## Кнопка слева от хранилища инструментов: прячет и показывает окно
## ([HudToolStorage]). Картинка на кнопке меняется — по ней сразу видно,
## что произойдёт по нажатию ([member hide_texture] / [member show_texture]).
##
## Пока окно спрятано, выбор инструмента никуда не девается: можно открыть
## холодильник, потрогать специи и фишки в корзине, а потом вернуть окно
## этой же кнопкой. Клики раздаёт [CombatHud].
class_name HudToolToggleButton
extends Node2D

@export_category("Кнопка скрытия окна")

## Картинка, когда окно на экране: нажатие его спрячет.
@export var hide_texture: Texture2D:
	set(value):
		hide_texture = value
		queue_redraw()

## Картинка, когда окно спрятано: нажатие его вернёт.
@export var show_texture: Texture2D:
	set(value):
		show_texture = value
		queue_redraw()

## Масштаб картинки; размер кнопки = размер картинки × масштаб.
@export var texture_scale := Vector2.ONE:
	set(value):
		texture_scale = value
		queue_redraw()

## Насколько кликабельная область шире картинки, px (может быть < 0).
@export var hit_padding := 0.0:
	set(value):
		hit_padding = value
		queue_redraw()

@export_group("Свечение под курсором")
@export var glow_tint := Color(1.45, 1.35, 1.15):
	set(value):
		glow_tint = value
		queue_redraw()

@export var glow_time := 0.12:
	set(value):
		glow_time = maxf(value, 0.01)
		queue_redraw()

@export_group("Подсказка, пока окно спрятано")
## Пока окно спрятано, кнопка сама зовёт обратно: разгорается и гаснет.
## Во сколько раз ярче картинка на пике (1 — не ярче).
@export var attention_tint := Color(1.6, 1.45, 1.15):
	set(value):
		attention_tint = value
		queue_redraw()

## Ореол вокруг кнопки на пике: та же картинка крупнее и полупрозрачная.
@export var attention_halo := Color(1.0, 0.85, 0.45, 0.5):
	set(value):
		attention_halo = value
		queue_redraw()

@export var attention_halo_padding := 10.0:
	set(value):
		attention_halo_padding = maxf(value, 0.0)
		queue_redraw()

## Сколько раз в секунду (в радианах) кнопка разгорается.
@export var attention_speed := 3.0:
	set(value):
		attention_speed = maxf(value, 0.0)
		queue_redraw()

@export_group("Заглушка без картинок")
@export var fallback_size := Vector2(64, 64):
	set(value):
		fallback_size = value.max(Vector2.ONE)
		queue_redraw()

@export var fallback_fill := Color(0.18, 0.17, 0.2, 0.94):
	set(value):
		fallback_fill = value
		queue_redraw()

@export var fallback_border := Color(0.85, 0.7, 0.35):
	set(value):
		fallback_border = value
		queue_redraw()

@export var hide_label := "«":
	set(value):
		hide_label = value
		queue_redraw()

@export var show_label := "»":
	set(value):
		show_label = value
		queue_redraw()

@export_range(6, 200, 1, "or_greater") var fallback_font_size := 34:
	set(value):
		fallback_font_size = maxi(value, 6)
		queue_redraw()

## HUD боя ([CombatHud]) — у него состояние окна. Без типа, чтобы не плодить
## циклическую зависимость.
var hud = null

var _glow := 0.0
var _time := 0.0


## Кнопка нужна, только пока есть что прятать и показывать: идёт выбор
## инструмента или открыто хранилище.
func is_active() -> bool:
	return hud != null and hud.is_tool_window_available()


## Кликабельная область в экранных координатах.
func get_global_rect() -> Rect2:
	var size := _size() * global_scale.abs()
	return Rect2(global_position - size / 2.0, size).grow(hit_padding)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_time += delta
	var hovered := is_active() and get_global_rect().has_point(get_global_mouse_position())
	_glow = move_toward(_glow, 1.0 if hovered else 0.0, delta / glow_time)
	queue_redraw()


func _draw() -> void:
	# В редакторе кнопка видна всегда — иначе её не разместить.
	if not is_active() and not Engine.is_editor_hint():
		return
	var texture := _texture()
	# Пока окно спрятано, кнопка подсвечивается сама — иначе непонятно, чем
	# его вернуть. Под курсором свечение всё равно ярче.
	var attention := _attention()
	var tint := Color.WHITE.lerp(glow_tint, _glow).lerp(attention_tint, attention)
	if texture == null:
		_draw_fallback(tint)
		return
	var size := _size()
	var rect := Rect2(-size / 2.0, size)
	if attention > 0.0 and attention_halo.a > 0.0 and attention_halo_padding > 0.0:
		var halo := attention_halo
		halo.a *= attention
		draw_texture_rect(texture, rect.grow(attention_halo_padding * attention), false, halo)
	draw_texture_rect(texture, rect, false, tint)


## Насколько сейчас разгорелась подсказка: 0 — окно на экране (звать некуда),
## иначе плавная пульсация. В редакторе кнопка не мигает.
func _attention() -> float:
	if Engine.is_editor_hint() or _window_shown() or not is_active():
		return 0.0
	return 0.5 + 0.5 * sin(_time * attention_speed)


## Какая картинка сейчас: окно на экране — «спрятать», иначе — «показать».
func _texture() -> Texture2D:
	return hide_texture if _window_shown() else show_texture


func _window_shown() -> bool:
	if hud == null:
		return true
	return hud.is_tool_storage_shown()


func _draw_fallback(tint: Color) -> void:
	var rect := Rect2(-fallback_size / 2.0, fallback_size)
	draw_rect(rect, fallback_fill)
	draw_rect(rect, fallback_border * tint, false, 2.5)
	var label := hide_label if _window_shown() else show_label
	draw_string(UiFont.resolve(), Vector2(rect.position.x, fallback_font_size * 0.36), label,
			HORIZONTAL_ALIGNMENT_CENTER, fallback_size.x, fallback_font_size,
			fallback_border * tint)


func _size() -> Vector2:
	var texture := _texture()
	if texture == null:
		return fallback_size
	return Vector2(texture.get_size()) * texture_scale.abs()
