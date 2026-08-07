@tool
## Баланс звёзд игрока в HUD магазина: звезда и число рядом.
##
## Позиция настраивается в редакторе, вид — в инспекторе. Режим магазина
## подключает игрока через [method attach] — виджет сам слушает
## [signal Player.stars_changed].
class_name StarBalance
extends Node2D

@export var star_radius := 14.0:
	set(value):
		star_radius = maxf(value, 4.0)
		queue_redraw()

@export var star_color := Color(1.0, 0.78, 0.2):
	set(value):
		star_color = value
		queue_redraw()

## Обводка самой звезды.
@export var outline_color := Color(0.85, 0.7, 0.3):
	set(value):
		outline_color = value
		queue_redraw()

@export var text_color := Color(0.96, 0.93, 0.88):
	set(value):
		text_color = value
		queue_redraw()

@export var font_size := 22:
	set(value):
		font_size = maxi(value, 8)
		queue_redraw()

## Шрифт баланса. Пусто — шрифт проекта (Grunge Bold V2, см. [UiFont]),
## а если его файла ещё нет — системная заглушка.
@export var font: Font:
	set(value):
		font = value
		queue_redraw()

## Тёмная обводка цифр — баланс читается на любом фоне.
@export var text_outline_size := 4:
	set(value):
		text_outline_size = maxi(value, 0)
		queue_redraw()

@export var text_outline_color := Color(0.12, 0.09, 0.06, 0.85):
	set(value):
		text_outline_color = value
		queue_redraw()

## Число в превью редактора.
@export var editor_preview_stars := 25

var _player: Player = null


func attach(player: Player) -> void:
	_player = player
	_player.stars_changed.connect(func(_stars: int) -> void: queue_redraw())
	queue_redraw()


func _draw() -> void:
	var stars := editor_preview_stars
	if not Engine.is_editor_hint() and _player != null:
		stars = _player.stars
	PriceTag.draw_star_shape(self, Vector2.ZERO, star_radius, star_color, outline_color)
	var text_font := UiFont.resolve(font)
	var text_at := Vector2(star_radius + 8.0, font_size * 0.36)
	if text_outline_size > 0:
		draw_string_outline(text_font, text_at, str(stars), HORIZONTAL_ALIGNMENT_LEFT,
				-1, font_size, text_outline_size, text_outline_color)
	draw_string(text_font, text_at, str(stars), HORIZONTAL_ALIGNMENT_LEFT, -1,
			font_size, text_color)
