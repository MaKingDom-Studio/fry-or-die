@tool
## Ценник товара — отдельный узел сцены, не привязанный к слоту.
##
## Скрипт вешается на спрайт-ценник (арт Price_Tag_*): картинка остаётся
## фоном ценника, а поверх неё, ровно по центру изображения, рисуется
## сама цена — маленькая звёздочка, затем число. Своего фона цена не
## рисует. Товар, который игрок может купить, подсвечивается жёлтым,
## который не может — красным.
##
## Какому слоту принадлежит ценник, задаётся в самом слоте
## ([member ShopSlot.price_tag]) — так ценник можно повесить где угодно,
## независимо от площадки товара.
##
## Цена рисуется в экранных пикселях: масштаб узла (арт обычно ужат до
## ~0.3) компенсируется, поэтому [member font_size] и
## [member star_radius] не зависят от размера картинки.
class_name PriceTag
extends Sprite2D

@export var price := 0:
	set(value):
		price = maxi(value, 0)
		queue_redraw()

## Хватает ли игроку звёзд (жёлтая цена); false — красная.
@export var affordable := true:
	set(value):
		affordable = value
		queue_redraw()

## Товар продан: цена не рисуется, а сам ценник блёкнет.
@export var sold := false:
	set(value):
		sold = value
		self_modulate = Color(1.0, 1.0, 1.0, sold_alpha if sold else 1.0)
		queue_redraw()

@export_group("Вид")
## Шрифт цены. Пусто — шрифт проекта (Grunge Bold V2, см. [UiFont]),
## а если его файла ещё нет — системная заглушка.
@export var font: Font:
	set(value):
		font = value
		queue_redraw()

## Заливка цены, когда товар по карману: белая, поверх тёмной обводки.
@export var affordable_color := Color.WHITE:
	set(value):
		affordable_color = value
		queue_redraw()

## Цвет цены, когда звёзд не хватает.
@export var blocked_color := Color(0.9, 0.27, 0.22):
	set(value):
		blocked_color = value
		queue_redraw()

## Насколько блёкнет ценник проданного товара.
@export_range(0.0, 1.0) var sold_alpha := 0.35:
	set(value):
		sold_alpha = value
		if sold:
			self_modulate = Color(1.0, 1.0, 1.0, sold_alpha)

## Радиус маленькой звёздочки перед ценой, px.
@export var star_radius := 7.0:
	set(value):
		star_radius = maxf(value, 2.0)
		queue_redraw()

@export var font_size := 16:
	set(value):
		font_size = maxi(value, 6)
		queue_redraw()

## Тёмная обводка цифр — цена читается на любой картинке ценника.
@export var outline_size := 4:
	set(value):
		outline_size = maxi(value, 0)
		queue_redraw()

@export var outline_color := Color(0.12, 0.09, 0.06, 0.85):
	set(value):
		outline_color = value
		queue_redraw()

## Сдвиг цены от центра изображения, экранные px.
@export var text_offset := Vector2.ZERO:
	set(value):
		text_offset = value
		queue_redraw()

## Вспышка ценника при неудачной покупке (гаснет сама).
var _flash := 0.0


## Пятиконечная звезда — общая отрисовка для ценника и баланса звёзд.
static func draw_star_shape(canvas: CanvasItem, center: Vector2, r: float,
		fill: Color, outline: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var angle := -PI / 2.0 + TAU * i / 10.0
		var radius := r if i % 2 == 0 else r * 0.45
		pts.append(center + Vector2(cos(angle), sin(angle)) * radius)
	canvas.draw_colored_polygon(pts, fill)
	var closed := pts.duplicate()
	closed.append(pts[0])
	canvas.draw_polyline(closed, outline, 1.2)


## Мигнуть красным — покупка не удалась (не хватает звёзд).
func flash_blocked() -> void:
	_flash = 1.0


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _flash <= 0.0:
		return
	_flash = maxf(_flash - delta * 2.0, 0.0)
	queue_redraw()


func _draw() -> void:
	if sold:
		return
	# Цена рисуется поверх картинки ценника в экранных пикселях: масштаб
	# узла компенсируется, иначе текст ужался бы вместе с артом.
	var node_scale := global_scale.abs()
	var compensation := Vector2(1.0 / maxf(node_scale.x, 0.01),
			1.0 / maxf(node_scale.y, 0.01))
	draw_set_transform(text_offset * compensation, 0.0, compensation)
	var tint := affordable_color if affordable else blocked_color
	if _flash > 0.0:
		tint = tint.lerp(Color(1.0, 0.2, 0.15), _flash)
	var text_font := UiFont.resolve(font)
	var text := str(price)
	var text_width := text_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			font_size).x
	var gap := 4.0
	var left := -(star_radius * 2.0 + gap + text_width) / 2.0
	# Сначала маленькая звёздочка, потом цена. Обводка у звёздочки та же
	# тёмная, что у цифр, — иначе жёлтая звезда теряется на жёлтом ценнике.
	draw_star_shape(self, Vector2(left + star_radius, 0.0), star_radius,
			tint, outline_color)
	var text_at := Vector2(left + star_radius * 2.0 + gap, font_size * 0.36)
	if outline_size > 0:
		draw_string_outline(text_font, text_at, text, HORIZONTAL_ALIGNMENT_LEFT, -1,
				font_size, outline_size, outline_color)
	draw_string(text_font, text_at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, tint)
