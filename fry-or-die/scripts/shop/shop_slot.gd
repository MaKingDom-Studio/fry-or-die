@tool
## Слот витрины магазина: прямоугольная площадка, на которой лежит товар.
##
## Узел-маркер сцены: позиция узла — центр прямоугольника, размер задаётся
## в инспекторе ([member size]), ряд — полем [member kind]. Режим магазина
## ([gm_shop]) собирает слоты по рядам в порядке следования детей узла
## Slots и кладёт в каждый по товару ([ShopItemNode]): товар ужимается,
## чтобы поместиться в прямоугольник, и ставится по выравниванию
## [member item_align] — по умолчанию лежит на дне площадки.
##
## Ценник слота — отдельный узел сцены ([PriceTag] на спрайте-ценнике),
## он не привязан к слоту позицией: слот только ссылается на него
## ([member price_tag]), а где ценник висит — решает сцена.
class_name ShopSlot
extends Node2D

## Ряд витрины: большие и средние ингредиенты, средние и маленькие,
## специи. Наполнение рядов — [ShopInventory].
enum Kind { LARGE_MEDIUM, SMALL_MEDIUM, SPICE }

## Как товар лежит в прямоугольнике слота.
enum ItemAlign {
	## По центру площадки.
	CENTER,
	## На дне площадки — товар «лежит» на полке.
	BOTTOM,
}

@export var kind: Kind = Kind.LARGE_MEDIUM:
	set(value):
		kind = value
		queue_redraw()

## Размер площадки; позиция узла — её центр.
@export var size := Vector2(120.0, 92.0):
	set(value):
		size = value.max(Vector2.ONE)
		queue_redraw()

## Ценник этого слота — отдельный узел сцены. Пустая ссылка означает, что
## слот просто не показывает цену.
@export var price_tag: PriceTag

@export_group("Товар")
## Отступ товара от краёв площадки, px.
@export var item_padding := 6.0:
	set(value):
		item_padding = maxf(value, 0.0)
		queue_redraw()

## Где лежит товар внутри площадки.
@export var item_align: ItemAlign = ItemAlign.BOTTOM:
	set(value):
		item_align = value
		queue_redraw()

## Насколько сильно разрешено увеличивать товар, если он мельче площадки.
## 1 — никогда не крупнее своего натурального размера.
@export var max_item_scale := 1.0:
	set(value):
		max_item_scale = maxf(value, 0.01)

@export_group("Вид")
## Показывать площадку в игре (в редакторе она видна всегда).
@export var show_in_game := false:
	set(value):
		show_in_game = value
		queue_redraw()

@export var fill_color := Color(0.95, 0.8, 0.35, 0.07):
	set(value):
		fill_color = value
		queue_redraw()

@export var border_color := Color(0.95, 0.8, 0.35, 0.5):
	set(value):
		border_color = value
		queue_redraw()


## Площадка в локальных координатах узла (центр — в нуле).
func rect() -> Rect2:
	return Rect2(-size * 0.5, size)


## Площадка в глобальных координатах (учитывает масштаб узла).
func global_rect() -> Rect2:
	var scaled := size * global_scale
	return Rect2(global_position - scaled * 0.5, scaled)


## Во что должен вписаться товар: площадка за вычетом отступов.
func item_fit_size() -> Vector2:
	return (global_rect().size - Vector2.ONE * item_padding * 2.0).max(Vector2.ONE)


## Куда встать центру товара с боксом box (уже ужатым под площадку):
## по центру площадки или на её дне, если товар лежит на полке.
func item_position(box: Vector2) -> Vector2:
	var area := global_rect()
	if item_align == ItemAlign.CENTER:
		return area.get_center()
	return Vector2(area.get_center().x, area.end.y - item_padding - box.y * 0.5)


func _kind_caption() -> String:
	match kind:
		Kind.LARGE_MEDIUM:
			return "Big/Med"
		Kind.SMALL_MEDIUM:
			return "Med/Small"
		_:
			return "Spice"


func _draw() -> void:
	if not Engine.is_editor_hint() and not show_in_game:
		return
	var area := rect()
	draw_rect(area, fill_color)
	draw_rect(area, border_color, false, 2.0)
	if not Engine.is_editor_hint():
		return
	# Линия дна: по ней ляжет товар при выравнивании BOTTOM.
	if item_align == ItemAlign.BOTTOM:
		var bottom := area.end.y - item_padding
		draw_line(Vector2(area.position.x + item_padding, bottom),
				Vector2(area.end.x - item_padding, bottom),
				Color(border_color, 0.7), 1.0)
	draw_string(ThemeDB.fallback_font, Vector2(area.position.x, area.position.y - 4.0),
			_kind_caption(), HORIZONTAL_ALIGNMENT_CENTER, size.x, 11, border_color)
