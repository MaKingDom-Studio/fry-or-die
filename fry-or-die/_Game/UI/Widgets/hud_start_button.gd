@tool
## Кнопка «Обратный отсчёт» — запускает таймер раунда. Позиция (центр
## кнопки — начало узла), размер, цвета и подпись настраиваются в редакторе
## (узел под Hud, превью видно в 2D-виде). Масштаб узла учитывается.
##
## Кнопка видна всегда: приглушённой, пока нажать нельзя, и активной, когда
## все ингредиенты на столе (фаза READY режима боя) — только тогда её и
## можно нажать. Клик обрабатывает [CombatHud] через [method get_global_rect]
## и [method is_active]; по нажатию идёт обратный отсчёт «3 2 1» на весь
## экран ([HudStartCountdown]), и лишь после него режим боя запускает таймер
## и разрешает двигать ингредиенты. На время отсчёта кнопка гаснет — фаза
## боя уже не READY.
class_name HudStartButton
extends Node2D

@export var size := Vector2(270, 52):
	set(value):
		size = value.max(Vector2.ONE)
		queue_redraw()

@export var label := "COUNTDOWN":
	set(value):
		label = value
		queue_redraw()

@export var font_size := 20:
	set(value):
		font_size = maxi(value, 1)
		queue_redraw()

@export var border_width := 2.5:
	set(value):
		border_width = maxf(value, 0.0)
		queue_redraw()

@export_group("Активная (все ингредиенты на столе)")
@export var fill_color := Color(0.2, 0.62, 0.28):
	set(value):
		fill_color = value
		queue_redraw()

@export var border_color := Color(0.9, 0.95, 0.85):
	set(value):
		border_color = value
		queue_redraw()

@export var text_color := Color(0.97, 0.98, 0.95):
	set(value):
		text_color = value
		queue_redraw()

@export_group("Приглушённая (ингредиенты ещё падают)")
@export var disabled_fill_color := Color(0.28, 0.3, 0.32):
	set(value):
		disabled_fill_color = value
		queue_redraw()

@export var disabled_text_color := Color(0.62, 0.64, 0.66):
	set(value):
		disabled_text_color = value
		queue_redraw()

## Режим боя (gm_combat). Без типа, чтобы не плодить циклическую зависимость.
var gm = null


func attach(game_mode) -> void:
	gm = game_mode


func _process(_delta: float) -> void:
	# В игре фаза боя меняется — перерисовываем, чтобы кнопка появлялась,
	# загоралась и гасла вовремя. В редакторе перерисовка идёт из сеттеров.
	if not Engine.is_editor_hint():
		queue_redraw()


## Кликабельная область в экранных координатах (центр — на позиции узла).
func get_global_rect() -> Rect2:
	var s := size * global_scale
	return Rect2(global_position - s / 2.0, s)


## Кнопку можно нажать: все ингредиенты на столе, ждём старт (фаза READY).
func is_active() -> bool:
	return gm != null and gm.phase == gm.Phase.READY


func _draw() -> void:
	# Кнопка на экране всегда; загорается активной только в фазе READY.
	# В редакторе показываем активный вид — так удобнее подбирать цвета.
	var active := is_active() or Engine.is_editor_hint()
	var rect := Rect2(-size / 2.0, size)
	draw_rect(rect, fill_color if active else disabled_fill_color)
	draw_rect(rect, border_color, false, border_width)
	var color := text_color if active else disabled_text_color
	draw_string(ThemeDB.fallback_font, Vector2(-size.x / 2.0, font_size * 0.35), label,
			HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, color)
