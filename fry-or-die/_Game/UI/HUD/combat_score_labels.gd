@tool
## Всплывающие подписи подсчёта: сначала звезда, затем доля звезды, которую дал
## ингредиент («0.33»).
##
## Подписи рисует отдельный узел-оверлей, а не сам ингредиент, — поэтому цифры
## всегда лежат поверх всего: и стола с ингредиентами, и корзин, и HUD, и
## затемнения подсчёта. Узел кладётся ребёнком корня боевой сцены с z-индексом
## выше всех остальных (в l_combat.tscn — 130); режим боя вызывает [method pop]
## на каждый посчитанный ингредиент.
##
## Подпись всплывает над ингредиентом и к концу гаснет; размеры, цвет звезды
## и время жизни настраиваются в инспекторе.
class_name CombatScoreLabels
extends Node2D

## Сколько секунд висит одна подпись.
@export_range(0.1, 5.0, 0.05, "or_greater") var duration := 0.9
## Радиус звёздочки перед числом.
@export var star_radius := 9.0
## Цвет звёздочки (число красится цветом из [method pop]).
@export var star_color := Color(1.0, 0.85, 0.3)
## Шрифт числа. Пусто — шрифт проекта (Grunge Bold V2, см. [UiFont]).
@export var font: Font
@export_range(8, 96, 1, "or_greater") var font_size := 20
## Тёмная обводка — подпись читается на любом фоне.
@export var outline_size := 4
@export var outline_color := Color(0.08, 0.06, 0.05, 0.85)
## Отступ подписи от края ингредиента и насколько она всплывает за жизнь.
@export var lift := 14.0
@export var rise := 16.0
## Зазор между звездой и числом.
@export var gap := 5.0

@export_group("Редактор")
## Превью в редакторе: нарисовать подпись с этим текстом в начале узла.
@export var editor_preview_text := ""

## Живые подписи: {"position": Vector2, "text": String, "color": Color,
## "offset": float (радиус ингредиента), "left": float}.
var _labels: Array[Dictionary] = []


## Показать подпись над точкой стола: text — доля звезды, color — цвет числа,
## from_radius — радиус ингредиента, чтобы подпись встала над ним.
func pop(world_position: Vector2, text: String, color: Color, from_radius := 0.0) -> void:
	if text == "":
		return
	_labels.append({
		"position": world_position,
		"text": text,
		"color": color,
		"offset": from_radius,
		"left": duration,
	})
	queue_redraw()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()
		return
	if _labels.is_empty():
		return
	for i in range(_labels.size() - 1, -1, -1):
		_labels[i]["left"] -= delta
		if _labels[i]["left"] <= 0.0:
			_labels.remove_at(i)
	queue_redraw()


func _draw() -> void:
	if Engine.is_editor_hint():
		if editor_preview_text != "":
			_draw_label(Vector2.ZERO, editor_preview_text, star_color, 0.0, 1.0)
		return
	for label in _labels:
		var left: float = clampf(label["left"] / duration, 0.0, 1.0)
		_draw_label(to_local(label["position"]), label["text"], label["color"],
				label["offset"], left)


## Одна подпись: звезда и число справа от неё, обе поднимаются и гаснут.
func _draw_label(at: Vector2, text: String, color: Color, from_radius: float,
		left: float) -> void:
	# Гаснет только в последней трети жизни.
	var alpha := minf(left * 3.0, 1.0)
	var center := at + Vector2(0.0, -(from_radius + lift + rise * (1.0 - left)))
	var text_font := UiFont.resolve(font)
	var text_width := text_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT,
			-1, font_size).x
	var total_width := star_radius * 2.0 + gap + text_width
	var star_center := center + Vector2(-total_width / 2.0 + star_radius, 0.0)
	_draw_star(star_center, alpha)
	var baseline := (text_font.get_ascent(font_size) - text_font.get_descent(font_size)) / 2.0
	var text_at := star_center + Vector2(star_radius + gap, baseline)
	if outline_size > 0:
		draw_string_outline(text_font, text_at, text, HORIZONTAL_ALIGNMENT_LEFT, -1,
				font_size, outline_size, Color(outline_color, outline_color.a * alpha))
	draw_string(text_font, text_at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
			Color(color, alpha))


## Звёздочка подписи — общая фигура [StarIcon]: та же звезда, что и в
## подсказках при наведении.
func _draw_star(center: Vector2, alpha: float) -> void:
	StarIcon.draw(self, center, star_radius, Color(star_color, alpha),
			Color(outline_color, outline_color.a * alpha))
