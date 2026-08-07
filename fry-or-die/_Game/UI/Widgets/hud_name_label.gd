@tool
## Имя стороны боя — отдельный узел, не связанный с портретом
## ([HudPortrait]).
##
## Пишется шрифтом проекта (Grunge Bold V2, см. [UiFont]) с настройкой
## размера, а каждая буква при этом чуть дрожит на своём месте — имя
## «живое», но читается спокойно. Сила и скорость дрожи настраиваются в
## инспекторе, [member jitter_amount] = 0 выключает её совсем.
##
## Текст берётся из Data стороны ([member CharacterModel.display_name] /
## [member EnemyModel.display_name]) или задаётся прямо в узле
## ([member text_override]) — от текстуры портрета имя не зависит.
class_name HudNameLabel
extends Node2D

## Чьё имя показывать: врага или игрока.
@export var enemy := false:
	set(value):
		enemy = value
		queue_redraw()

## Текст вместо имени из Data; пусто — имя стороны.
@export var text_override := "":
	set(value):
		text_override = value
		queue_redraw()

@export_group("Вид")
## Шрифт имени. Пусто — шрифт проекта (Grunge Bold V2).
@export var font: Font:
	set(value):
		font = value
		queue_redraw()

@export_range(6, 200, 1, "or_greater") var font_size := 16:
	set(value):
		font_size = maxi(value, 6)
		queue_redraw()

## Цвет имени; полностью прозрачный — цвет из Data стороны
## ([member PortraitStyle.name_color]).
@export var color := Color(0.0, 0.0, 0.0, 0.0):
	set(value):
		color = value
		queue_redraw()

## Тёмная обводка букв — имя читается на любом фоне.
@export var outline_size := 0:
	set(value):
		outline_size = maxi(value, 0)
		queue_redraw()

@export var outline_color := Color(0.12, 0.09, 0.06, 0.85):
	set(value):
		outline_color = value
		queue_redraw()

@export_group("Дрожь букв")
## Насколько сильно каждая буква гуляет вокруг своего места, px.
## 0 — букву не трясёт.
@export var jitter_amount := 1.2:
	set(value):
		jitter_amount = maxf(value, 0.0)
		queue_redraw()

## Как быстро дрожат буквы.
@export var jitter_speed := 7.0:
	set(value):
		jitter_speed = maxf(value, 0.0)
		queue_redraw()

## Насколько буква при этом качается, градусы.
@export var jitter_rotation := 2.5:
	set(value):
		jitter_rotation = value
		queue_redraw()

@export_group("Редактор")
## Что писать в превью редактора, пока Data ещё не подключена.
@export var editor_preview_text := "Player":
	set(value):
		editor_preview_text = value
		queue_redraw()

var gm = null

var _style: PortraitStyle
var _time := 0.0


func attach(game_mode) -> void:
	gm = game_mode
	_style = gm.enemy.portrait if enemy else gm.player.character.portrait
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var text := _text()
	if text == "":
		return
	var text_font := UiFont.resolve(font)
	var tint := color
	if tint.a <= 0.0:
		tint = _style.name_color if _style != null else Color(0.9, 0.9, 0.92)
	# Дрожь — общая для всех надписей боя ([JitterText]).
	JitterText.draw_centered(self, text_font, Vector2.ZERO, text, font_size, tint,
			_time, jitter_amount, jitter_speed, jitter_rotation, outline_size, outline_color)


## Имя стороны: из узла, из Data, а в редакторе — превью-текст.
func _text() -> String:
	if text_override != "":
		return text_override
	var model = null
	if gm != null:
		model = gm.enemy if enemy else gm.player.character
	if model != null and model.display_name != "":
		return model.display_name
	return editor_preview_text
