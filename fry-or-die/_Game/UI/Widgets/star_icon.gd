## Пятиконечная звёздочка — общая фигура для всех подписей со звездой:
## всплывающих подписей подсчёта ([CombatScoreLabels]), подсказок при
## наведении ([HoverTooltip]) и летящих партиклов ([StarParticles]).
##
## Рисуется картинками из _Game/Art/Star: белый силуэт Star_Fill.png красится
## цветом заливки, поверх ложится контур Star.png (внутри он прозрачный) —
## поэтому звезда выглядит одинаково везде. Без картинок — прежняя
## рисованная фигура.
class_name StarIcon
extends RefCounted

## Контур звезды (внутри прозрачный).
const TEXTURE := preload("res://_Game/Art/Star/Star.png")
## Белый силуэт звезды под контуром — красится цветом заливки.
const FILL_TEXTURE := preload("res://_Game/Art/Star/Star_Fill.png")

## Во сколько раз внутренние лучи короче внешних (рисованный запасной вариант).
const INNER_RATIO := 0.45


## Точки звезды радиуса radius вокруг center (верхний луч смотрит вверх).
static func points(center: Vector2, radius: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	for i in 10:
		var angle := -PI / 2.0 + TAU * i / 10.0
		var ray := radius if i % 2 == 0 else radius * INNER_RATIO
		result.append(center + Vector2(cos(angle), sin(angle)) * ray)
	return result


## Нарисовать звезду. Картинки вписываются в круг радиуса radius: силуэт
## красится color, контур сверху гаснет вместе с ним (альфа от color);
## обводка у контура своя, поэтому outline_* нужны только запасной фигуре.
static func draw(canvas: CanvasItem, center: Vector2, radius: float, color: Color,
		outline_color := Color(0.08, 0.06, 0.05, 0.85), outline_width := 1.5) -> void:
	if radius <= 0.0:
		return
	if TEXTURE != null and FILL_TEXTURE != null:
		var source := TEXTURE.get_size()
		var longest := maxf(source.x, source.y)
		if longest > 0.0:
			var rect := Rect2(center - source * (radius / longest), source * (radius * 2.0 / longest))
			canvas.draw_texture_rect(FILL_TEXTURE, rect, false, color)
			canvas.draw_texture_rect(TEXTURE, rect, false, Color(1.0, 1.0, 1.0, color.a))
			return
	var star := points(center, radius)
	canvas.draw_colored_polygon(star, color)
	if outline_width <= 0.0 or outline_color.a <= 0.0:
		return
	var outline := star.duplicate()
	outline.append(star[0])
	canvas.draw_polyline(outline, outline_color, outline_width)
