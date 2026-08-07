@tool
## Кнопка мешка игрока — картинка холодильника: клик по ней открывает и
## закрывает мешок, а под курсором картинка подсвечивается.
##
## Картинка задаётся прямо в узле ([member texture], [member texture_scale]),
## поэтому в редакторе сразу видно и её саму, и её размер. Кликается вся
## картинка целиком — область берётся по ней ([method get_global_rect]),
## клики раздаёт [CombatHud]. Если текстуры нет, рисуется прежний
## серый круг-заглушка радиусом [member radius].
class_name HudBagButton
extends Node2D

## Картинка кнопки (холодильник игрока).
@export var texture: Texture2D:
	set(value):
		texture = value
		queue_redraw()

## Масштаб картинки; размер кнопки = размер текстуры × масштаб.
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
## Во сколько раз ярче становится картинка под курсором (1 — не ярче).
@export var glow_tint := Color(1.45, 1.35, 1.15):
	set(value):
		glow_tint = value
		queue_redraw()

## Ореол вокруг картинки: та же картинка чуть крупнее и полупрозрачная.
@export var halo_color := Color(1.0, 0.85, 0.45, 0.4):
	set(value):
		halo_color = value
		queue_redraw()

## Насколько ореол вылезает за картинку, px.
@export var halo_padding := 9.0:
	set(value):
		halo_padding = maxf(value, 0.0)
		queue_redraw()

## За сколько секунд свечение разгорается и гаснет.
@export var glow_time := 0.12:
	set(value):
		glow_time = maxf(value, 0.01)
		queue_redraw()

@export_group("Заглушка без картинки")
@export var radius := 34.0:
	set(value):
		radius = maxf(value, 1.0)
		queue_redraw()

@export var fill_color := Color(0.55, 0.55, 0.58):
	set(value):
		fill_color = value
		queue_redraw()

@export var border_color := Color(0.9, 0.5, 0.2):
	set(value):
		border_color = value
		queue_redraw()

## Насколько сейчас разгорелось свечение: 0 — курсора нет, 1 — наведён.
var _glow := 0.0


## Кликабельная область в экранных координатах — по картинке, а без
## неё — по кругу-заглушке.
func get_global_rect() -> Rect2:
	return Rect2(global_position + _size() / -2.0, _size()).grow(hit_padding)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()
		return
	var target := 1.0 if get_global_rect().has_point(get_global_mouse_position()) else 0.0
	var next := move_toward(_glow, target, delta / glow_time)
	if next != _glow:
		_glow = next
		queue_redraw()


func _draw() -> void:
	if texture == null:
		_draw_fallback()
		return
	var rect := Rect2(_size() / -2.0, _size())
	if _glow > 0.0 and halo_color.a > 0.0 and halo_padding > 0.0:
		var halo := halo_color
		halo.a *= _glow
		draw_texture_rect(texture, rect.grow(halo_padding), false, halo)
	draw_texture_rect(texture, rect, false, Color.WHITE.lerp(glow_tint, _glow))


func _draw_fallback() -> void:
	var tint := Color(fill_color.r, fill_color.g, fill_color.b).lerp(glow_tint, _glow)
	tint.a = fill_color.a
	draw_circle(Vector2.ZERO, radius, tint)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, border_color, 2.5)


## Размер кнопки: картинка с учётом масштаба, иначе круг-заглушка.
func _size() -> Vector2:
	if texture == null:
		return Vector2.ONE * radius * 2.0
	return texture.get_size() * texture_scale.abs()
