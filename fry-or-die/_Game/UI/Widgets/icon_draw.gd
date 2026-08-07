## Отрисовка значков в HUD: картинка вписывается в отведённый ей прямоугольник
## без искажения пропорций.
##
## Общая механика кнопки хранилища ([HudToolButton]) и самого хранилища
## ([HudToolStorage]): значки инструментов и аксессуары рисуются одинаково,
## поэтому и подгонка размера считается здесь.
class_name IconDraw
extends RefCounted


## Прямоугольник картинки, вписанный в коробку box с центром center:
## пропорции сохраняются, картинка не выходит за коробку. Пустой
## прямоугольник — картинки нет.
static func fit_rect(texture: Texture2D, center: Vector2, box: Vector2) -> Rect2:
	if texture == null:
		return Rect2()
	var size := Vector2(texture.get_size())
	if size.x <= 0.0 or size.y <= 0.0:
		return Rect2()
	var scale := minf(box.x / size.x, box.y / size.y)
	var fitted := size * scale
	return Rect2(center - fitted / 2.0, fitted)


## Нарисовать картинку, вписанную в коробку box с центром center.
static func draw_fitted(canvas: CanvasItem, texture: Texture2D, center: Vector2,
		box: Vector2, tint := Color.WHITE) -> void:
	var rect := fit_rect(texture, center, box)
	if rect.size.x <= 0.0:
		return
	canvas.draw_texture_rect(texture, rect, false, tint)


## Нарисовать картинку в натуральную величину с масштабом и сдвигом от center.
static func draw_scaled(canvas: CanvasItem, texture: Texture2D, center: Vector2,
		texture_scale: Vector2, tint := Color.WHITE) -> void:
	if texture == null:
		return
	var size := Vector2(texture.get_size()) * texture_scale.abs()
	canvas.draw_texture_rect(texture, Rect2(center - size / 2.0, size), false, tint)
