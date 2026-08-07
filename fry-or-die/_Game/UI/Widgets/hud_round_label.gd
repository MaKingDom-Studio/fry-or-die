@tool
## Номер раунда — отдельный узел HUD, настраивается в редакторе.
##
## Пишется шрифтом проекта (Grunge Bold V2, см. [UiFont]), как имена сторон.
## Слово и вид задаются в инспекторе: шаблон текста ([member text_template],
## «%d» подменяется номером раунда), шрифт, размер, цвет и обводка.
##
## По умолчанию надпись стоит ровно под таймером, по его центру
## ([member follow_timer] — позиция считается от кликабельной области узла
## Timer, поэтому надпись едет за ним при перестановке в редакторе);
## выключенный флаг ставит её на место самого узла — тогда она двигается
## мышью, как любой виджет.
class_name HudRoundLabel
extends Node2D

## Что писать; «%d» подменяется номером раунда. Без «%d» — просто текст.
@export var text_template := "Round %d":
	set(value):
		text_template = value
		queue_redraw()

@export_group("Вид")
## Шрифт надписи. Пусто — шрифт проекта (Grunge Bold V2).
@export var font: Font:
	set(value):
		font = value
		queue_redraw()

@export_range(6, 200, 1, "or_greater") var font_size := 16:
	set(value):
		font_size = maxi(value, 6)
		queue_redraw()

## Цвет надписи; полностью прозрачный — цвет текста темы боя
## ([member CombatTheme.text_primary]).
@export var color := Color(0.0, 0.0, 0.0, 0.0):
	set(value):
		color = value
		queue_redraw()

## Тёмная обводка букв; 0 — без обводки.
@export var outline_size := 0:
	set(value):
		outline_size = maxi(value, 0)
		queue_redraw()

@export var outline_color := Color(0.12, 0.09, 0.06, 0.85):
	set(value):
		outline_color = value
		queue_redraw()

@export_group("Привязка")
## Стоять под таймером (узел Timer рядом в HUD): позиция узла не важна,
## надпись центрируется под его кликабельной областью. Выключено — надпись
## рисуется на месте самого узла.
@export var follow_timer := true:
	set(value):
		follow_timer = value
		queue_redraw()

## Сдвиг от середины нижнего края таймера, px.
@export var timer_offset := Vector2(0, 22):
	set(value):
		timer_offset = value
		queue_redraw()

@export_group("Редактор")
## Номер раунда в превью редактора.
@export var editor_preview_round := 1:
	set(value):
		editor_preview_round = value
		queue_redraw()

var gm = null


func attach(game_mode) -> void:
	gm = game_mode
	queue_redraw()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var text := _text()
	if text == "":
		return
	var text_font := UiFont.resolve(font)
	var tint := color
	if tint.a <= 0.0:
		tint = gm.theme.text_primary if gm != null else Color(0.9, 0.9, 0.92)
	# Точка — середина строки: под таймером или на месте узла.
	var center := to_local(_anchor())
	var width := 400.0
	var at := center + Vector2(-width / 2.0, 0.0)
	if outline_size > 0:
		draw_string_outline(text_font, at, text, HORIZONTAL_ALIGNMENT_CENTER, width,
				font_size, outline_size, outline_color)
	draw_string(text_font, at, text, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, tint)


func _text() -> String:
	# gm без типа (циклическая зависимость), поэтому тип задан явно — из
	# Variant вывод типа не работает.
	var round_number: int = gm.round_number if gm != null else editor_preview_round
	if text_template.contains("%d"):
		return text_template % round_number
	return text_template


## Середина строки в экранных координатах: под кликабельной областью таймера
## ([method HudTimer.get_global_rect]) или на месте узла.
func _anchor() -> Vector2:
	if follow_timer and get_parent() != null:
		var timer := get_parent().get_node_or_null("Timer") as HudTimer
		if timer != null:
			var rect := timer.get_global_rect()
			return Vector2(rect.get_center().x, rect.end.y) + timer_offset
	return global_position
