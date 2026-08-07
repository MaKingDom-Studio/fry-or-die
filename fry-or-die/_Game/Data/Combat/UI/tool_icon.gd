@tool
## Значок инструмента в окне инструментов: какой это инструмент, какой
## картинкой он рисуется, где стоит, какого размера и под каким наклоном.
##
## Из таких значков собираются два списка, оба настраиваются прямо в узлах
## сцены:
## [br]— все инструменты кнопки ([member HudToolButton.tool_icons]): картинка
##   на кнопке меняется вслед за выбором игрока;
## [br]— места хранилища ([member HudToolStorage.slots]): 4 штуки, у каждого
##   свой инструмент, своё место в окне, размер и наклон.
##
## Картинки может ещё не быть — тогда рисуется квадратик цвета инструмента
## размером [member fallback_size], и значки можно подставлять по одному.
##
## Ресурс помечен @tool (как и виджеты, которые его рисуют): без этого Godot
## держал бы в редакторе подставной экземпляр, у которого методы не
## вызываются, и места инструментов в 2D-виде не рисовались бы.
class_name ToolIcon
extends Resource

## Какому инструменту принадлежит значок (.tres из Data/Combat/Tools).
## Пусто — значок ни к чему не привязан и в игре не рисуется.
@export var tool_model: ToolModel

## Картинка значка. Пусто — берётся картинка самого инструмента
## ([member ToolModel.texture]), а без неё — квадратик его цвета.
@export var texture: Texture2D

## Место значка относительно центра окна (для кнопки — относительно её
## значка инструмента), px.
@export var offset := Vector2.ZERO

## Размер: множитель к картинке.
@export var icon_scale := Vector2.ONE

## Угол наклона, градусы.
@export_range(-180.0, 180.0, 0.1, "or_greater", "or_less") var rotation_degrees := 0.0

## Размер квадратика-заглушки, пока картинки нет, px.
@export var fallback_size := Vector2(96, 96)

## Готовый силуэт (точно по картинке) и контур (силуэт с полями): считаются
## по требованию и запоминаются, чтобы не пересчитывать их каждый кадр.
var _silhouette: Texture2D = null
var _silhouette_source: Texture2D = null
var _outline: Texture2D = null
var _outline_source: Texture2D = null
var _outline_width := 0
var _outline_steps := 0


## Идентификатор инструмента; пустой, если значок ни к чему не привязан.
func tool_id() -> StringName:
	return tool_model.id if tool_model != null else &""


## Картинка значка: своя, а без неё — картинка инструмента.
func resolve_texture() -> Texture2D:
	if texture != null:
		return texture
	return tool_model.texture if tool_model != null else null


## Размер значка на экране с учётом масштаба.
func size() -> Vector2:
	var tex := resolve_texture()
	if tex == null:
		return (fallback_size * icon_scale).abs()
	return (Vector2(tex.get_size()) * icon_scale).abs()


## Место значка на канве: прямоугольник вокруг [member offset] от center.
## Наклон в прямоугольник не входит — по нему считаются клик, затемнение
## кулдауна и свечение, поэтому сильные наклоны лучше держать небольшими.
func rect(center: Vector2) -> Rect2:
	return Rect2(center + offset - size() / 2.0, size())


## Нарисовать значок: картинка (или квадратик цвета инструмента) со своим
## размером и наклоном вокруг собственного центра.
func draw(canvas: CanvasItem, center: Vector2, tint := Color.WHITE) -> void:
	var box := Rect2(size() / -2.0, size())
	canvas.draw_set_transform(center + offset, deg_to_rad(rotation_degrees))
	var tex := resolve_texture()
	if tex != null:
		canvas.draw_texture_rect(tex, box, false, tint)
	else:
		canvas.draw_rect(box, fallback_color() * tint)
	canvas.draw_set_transform(Vector2.ZERO)


## Нарисовать значок, вписанным в коробку box: пропорции сохраняются, размер
## задаёт коробка ([member icon_scale] её домножает — 1 значит «во всю
## коробку»), а сдвиг и наклон остаются от самого значка. Так значок ложится
## в карман на кнопке ([member HudToolButton.tool_box]).
func draw_in_box(canvas: CanvasItem, center: Vector2, box: Vector2,
		tint := Color.WHITE) -> void:
	var tex := resolve_texture()
	if tex == null:
		draw(canvas, center, tint)
		return
	var fitted := IconDraw.fit_rect(tex, Vector2.ZERO, (box * icon_scale).abs())
	canvas.draw_set_transform(center + offset, deg_to_rad(rotation_degrees))
	canvas.draw_texture_rect(tex, fitted, false, tint)
	canvas.draw_set_transform(Vector2.ZERO)


## Подсветка строго по контуру: заранее посчитанный контур ([method outline])
## рисуется одной картинкой под самим значком — ровная обводка по форме
## инструмента, без наложений и зубцов. width — толщина на экране, px.
func draw_outline(canvas: CanvasItem, center: Vector2, color: Color, width: float,
		steps := 24) -> void:
	if color.a <= 0.0 or width <= 0.0:
		return
	# Толщина задаётся на экране, а раздувается картинка в своих точках —
	# переводим одно в другое через масштаб значка.
	var unit := maxf(minf(icon_scale.abs().x, icon_scale.abs().y), 0.001)
	var mask := outline(maxi(roundi(width / unit), 1), steps)
	if mask == null:
		return
	var full := (Vector2(mask.get_size()) * icon_scale).abs()
	canvas.draw_set_transform(center + offset, deg_to_rad(rotation_degrees))
	canvas.draw_texture_rect(mask, Rect2(full / -2.0, full), false, color)
	canvas.draw_set_transform(Vector2.ZERO)


## Затемнение (или подкраска) ровно по форме инструмента: тот же силуэт, но
## без раздувания — ложится точно на картинку. Так гасится инструмент на
## кулдауне, чтобы темнел он сам, а не прямоугольник вокруг него.
func draw_shade(canvas: CanvasItem, center: Vector2, color: Color) -> void:
	var mask := silhouette()
	if mask == null or color.a <= 0.0:
		return
	var box := Rect2(size() / -2.0, size())
	canvas.draw_set_transform(center + offset, deg_to_rad(rotation_degrees))
	canvas.draw_texture_rect(mask, box, false, color)
	canvas.draw_set_transform(Vector2.ZERO)


## Контур значка: белый силуэт, раздутый на width точек картинки во все
## стороны. Считает движок: силуэт переносится на холст с полями из steps
## положений по кругу, их объединение и есть равномерно толстая обводка.
## Результат запоминается — пока картинка, толщина и число шагов те же,
## пересчёта нет, поэтому пульсировать можно только прозрачностью.
func outline(width: int, steps: int) -> Texture2D:
	var tex := resolve_texture()
	if tex == null:
		return null
	var count := maxi(steps, 8)
	if _outline != null and _outline_source == tex and _outline_width == width \
			and _outline_steps == count:
		return _outline
	var image := _readable_image(tex)
	if image == null:
		return null
	var white := image.duplicate() as Image
	white.fill(Color.WHITE)
	var size_px := image.get_size()
	var out := image.duplicate() as Image
	out.crop(size_px.x + width * 2, size_px.y + width * 2)
	out.fill(Color(1.0, 1.0, 1.0, 0.0))
	var src_rect := Rect2i(Vector2i.ZERO, size_px)
	for i in count:
		var angle := TAU * float(i) / float(count)
		out.blit_rect_mask(white, image, src_rect, Vector2i(
				width + roundi(cos(angle) * float(width)),
				width + roundi(sin(angle) * float(width))))
	_outline = ImageTexture.create_from_image(out)
	_outline_source = tex
	_outline_width = width
	_outline_steps = count
	return _outline


## Силуэт значка: та же картинка, но все непрозрачные точки — белые, поэтому
## её можно красить в любой цвет. Считается один раз на картинку.
func silhouette() -> Texture2D:
	var tex := resolve_texture()
	if tex == null:
		return null
	if _silhouette != null and _silhouette_source == tex:
		return _silhouette
	var image := _readable_image(tex)
	if image == null:
		return null
	# Белая заливка переносится на прозрачный холст по маске самой картинки:
	# получается её силуэт. Всё считает движок, попиксельного перебора нет.
	var white := image.duplicate() as Image
	white.fill(Color.WHITE)
	var out := image.duplicate() as Image
	out.fill(Color(1.0, 1.0, 1.0, 0.0))
	out.blit_rect_mask(white, image, Rect2i(Vector2i.ZERO, image.get_size()), Vector2i.ZERO)
	_silhouette = ImageTexture.create_from_image(out)
	_silhouette_source = tex
	return _silhouette


## Картинка значка, пригодная для обработки: без сжатия, без мип-уровней и в
## RGBA8 — только с такой работают заливка и перенос по маске.
func _readable_image(tex: Texture2D) -> Image:
	var image := tex.get_image()
	if image == null:
		return null
	if image.is_compressed():
		image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	if image.has_mipmaps():
		image.clear_mipmaps()
	return image


## Цвет квадратика-заглушки — цвет инструмента из его .tres.
func fallback_color() -> Color:
	return tool_model.color if tool_model != null else Color(0.5, 0.5, 0.55)
