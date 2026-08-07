## Дрожащая надпись: каждая буква гуляет вокруг своего места и чуть
## качается, поэтому текст «живой», но читается спокойно.
##
## Общая математика для всех дрожащих надписей боя — имён сторон
## ([HudNameLabel]) и заголовка хранилища инструментов ([HudToolStorage]):
## дрожь везде выглядит одинаково, потому что считается здесь.
class_name JitterText
extends RefCounted


## Написать надпись, центрированную по точке center канвы canvas. Перенос
## строки — обычный «\n» в тексте: строки идут одна под другой, каждая
## центрируется сама, а весь блок стоит серединой на center. Расстояние между
## строками — высота шрифта × line_spacing. Вызывается из
## [method CanvasItem._draw] владельца; трансформация канвы после отрисовки
## сбрасывается.
static func draw_centered(canvas: CanvasItem, font: Font, center: Vector2, text: String,
		font_size: int, color: Color, time: float, amount: float, speed: float,
		rotation_degrees: float, outline_size := 0,
		outline_color := Color(0.12, 0.09, 0.06, 0.85), line_spacing := 1.0) -> void:
	if text == "" or font == null:
		return
	var lines := text.split("\n")
	var step := font.get_height(font_size) * line_spacing
	var first_y := center.y - step * float(lines.size() - 1) / 2.0
	# Номер буквы идёт сквозь все строки — соседние буквы дрожат вразнобой
	# и на переносе тоже.
	var index := 0
	for row in lines.size():
		var line: String = lines[row]
		# Буквы рисуются по одной, каждой — свой сдвиг и наклон. Место буквы
		# берётся как ширина начала строки до неё: так буквы стоят ровно там же,
		# где стояли бы в целой строке.
		var total := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		for i in line.length():
			var x := font.get_string_size(line.left(i), HORIZONTAL_ALIGNMENT_LEFT, -1,
					font_size).x - total / 2.0
			canvas.draw_set_transform(
					Vector2(center.x + x, first_y + step * row)
							+ offset(time, index, amount, speed),
					deg_to_rad(angle(time, index, rotation_degrees, speed)))
			if outline_size > 0:
				canvas.draw_string_outline(font, Vector2.ZERO, line[i],
						HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, outline_size, outline_color)
			canvas.draw_string(font, Vector2.ZERO, line[i], HORIZONTAL_ALIGNMENT_LEFT, -1,
					font_size, color)
			index += 1
	canvas.draw_set_transform(Vector2.ZERO)


## Сдвиг буквы, px: две несовпадающие синусоиды, у каждой буквы своя фаза —
## соседние буквы дрожат вразнобой.
static func offset(time: float, index: int, amount: float, speed: float) -> Vector2:
	if amount <= 0.0:
		return Vector2.ZERO
	var t := time * speed
	return Vector2(
			sin(t + index * 2.39),
			cos(t * 1.31 + index * 3.71)) * amount


## Наклон буквы, градусы.
static func angle(time: float, index: int, degrees: float, speed: float) -> float:
	if degrees == 0.0:
		return 0.0
	return sin(time * speed * 0.83 + index * 1.77) * degrees
