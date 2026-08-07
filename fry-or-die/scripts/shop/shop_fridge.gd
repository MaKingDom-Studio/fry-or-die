@tool
## Холодильник (мешок) магазина — область покупки.
##
## Сделан областью, как зоны боя: позиция узла — левый верхний угол,
## размер — в инспекторе, превью видно в редакторе. Чтобы купить товар,
## игрок переносит его сюда: пока товар в руке, область подсвечивается и
## в ней появляется слово «Купить» (жёлтое, если звёзд хватает, красное —
## если нет). Клик по холодильнику без товара в руке открывает мешок
## игрока ([BagPanel]) — он работает так же, как в бою.
class_name ShopFridge
extends Node2D

## Размер области; [member Node2D.position] узла — её левый верхний угол.
@export var area_size := Vector2(250, 380):
	set(value):
		area_size = value.max(Vector2.ZERO)
		queue_redraw()

## Изображение холодильника; растягивается на область с сохранением
## пропорций (по длинной стороне).
@export var texture: Texture2D:
	set(value):
		texture = value
		queue_redraw()

@export_group("Вид")
@export var fill_color := Color(0.16, 0.2, 0.26, 0.35):
	set(value):
		fill_color = value
		queue_redraw()

@export var border_color := Color(0.5, 0.65, 0.85, 0.5):
	set(value):
		border_color = value
		queue_redraw()

## Подсветка области, когда игрок несёт товар, но ещё не донёс.
@export var highlight_color := Color(1.0, 0.85, 0.3, 0.28):
	set(value):
		highlight_color = value
		queue_redraw()

@export var highlight_border_color := Color(1.0, 0.85, 0.3, 0.9):
	set(value):
		highlight_border_color = value
		queue_redraw()

@export var highlight_border_width := 4.0:
	set(value):
		highlight_border_width = maxf(value, 0.0)
		queue_redraw()

@export_subgroup("Товар над зоной")
## Заливка, когда товар уже попал в зону покупки: отпустишь — купишь,
## поэтому подсветка заметно сильнее.
@export var hover_color := Color(1.0, 0.9, 0.4, 0.62):
	set(value):
		hover_color = value
		queue_redraw()

@export var hover_border_color := Color(1.0, 0.97, 0.7, 1.0):
	set(value):
		hover_border_color = value
		queue_redraw()

@export var hover_border_width := 9.0:
	set(value):
		hover_border_width = maxf(value, 0.0)
		queue_redraw()

## Во сколько раз крупнее слово «Купить», когда товар над зоной.
@export var hover_caption_scale := 1.25:
	set(value):
		hover_caption_scale = maxf(value, 0.1)
		queue_redraw()

## Скорость перехода между обычной и сильной подсветкой, доля в секунду.
@export var hover_speed := 8.0:
	set(value):
		hover_speed = maxf(value, 0.1)

@export_subgroup("Не хватает звёзд")
## Красная подсветка зоны, когда взятый товар не по карману.
@export var blocked_color := Color(0.85, 0.18, 0.14, 0.3):
	set(value):
		blocked_color = value
		queue_redraw()

@export var blocked_border_color := Color(1.0, 0.33, 0.26, 0.95):
	set(value):
		blocked_border_color = value
		queue_redraw()

## Та же красная подсветка, когда товар уже над зоной, — сильнее.
@export var blocked_hover_color := Color(0.88, 0.14, 0.1, 0.66):
	set(value):
		blocked_hover_color = value
		queue_redraw()

@export var blocked_hover_border_color := Color(1.0, 0.45, 0.36, 1.0):
	set(value):
		blocked_hover_border_color = value
		queue_redraw()

## Слово в области, когда игрок несёт товар.
@export var buy_caption := "Buy":
	set(value):
		buy_caption = value
		queue_redraw()

## Цвет слова «Купить» по умолчанию — тёмно-коричневый.
@export var buy_color := Color(0.26, 0.15, 0.06):
	set(value):
		buy_color = value
		queue_redraw()

## Цвет слова «Купить», когда звёзд на товар не хватает: бежевый, чтобы
## читаться на красной подсветке зоны.
@export var buy_blocked_color := Color(0.96, 0.91, 0.78):
	set(value):
		buy_blocked_color = value
		queue_redraw()

@export var buy_font_size := 30:
	set(value):
		buy_font_size = maxi(value, 8)
		queue_redraw()

## Шрифт слова «Купить». Пусто — шрифт проекта (см. [UiFont]), как у
## ценников и баланса.
@export var buy_font: Font:
	set(value):
		buy_font = value
		queue_redraw()

@export var title := "Fridge":
	set(value):
		title = value
		queue_redraw()

@export var title_color := Color(0.75, 0.82, 0.92):
	set(value):
		title_color = value
		queue_redraw()

## Подсказка под областью (клик — открыть мешок).
@export var hint := "click — bag":
	set(value):
		hint = value
		queue_redraw()

## true, пока игрок несёт товар: область подсвечена, показано «Купить».
var _active := false
## Хватает ли звёзд на товар в руке (цвет слова «Купить»).
var _affordable := true
## Товар сейчас над зоной — отпустишь, и покупка пройдёт.
var _hovered := false
## Насколько подсветка усилена: 0 — товар просто в руке, 1 — уже над зоной.
var _hover_t := 0.0
## Пульс подсветки.
var _pulse := 0.0


## Область в локальных координатах узла (для отрисовки).
func area_rect() -> Rect2:
	return Rect2(Vector2.ZERO, area_size)


## Область в глобальных координатах (учитывает масштаб узла из редактора).
func area_global_rect() -> Rect2:
	return Rect2(global_position, area_size * global_scale)


func has_point(global_point: Vector2) -> bool:
	return area_global_rect().has_point(global_point)


## Точка, куда улетает купленный товар.
func consume_point() -> Vector2:
	return area_global_rect().get_center()


## Игрок взял/отпустил товар: подсветить область и показать «Купить».
## hovered — товар уже над зоной: подсветка усиливается, потому что
## отпущенный здесь товар будет куплен.
func set_active(active: bool, affordable := true, hovered := false) -> void:
	_active = active
	_affordable = affordable
	_hovered = hovered and active
	queue_redraw()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	# Усиление подсветки нарастает и спадает плавно — зона не мигает,
	# когда товар ходит по краю.
	var target := 1.0 if _hovered else 0.0
	if _hover_t != target:
		_hover_t = move_toward(_hover_t, target, hover_speed * delta)
		queue_redraw()
	if _active:
		_pulse = fmod(_pulse + delta * 3.0, TAU)
		queue_redraw()


func _draw() -> void:
	var rect := area_rect()
	if texture != null:
		var tex_size := texture.get_size()
		var longest := maxf(tex_size.x, tex_size.y)
		if longest > 0.0:
			var fitted := tex_size * minf(rect.size.x / tex_size.x, rect.size.y / tex_size.y)
			var offset := (rect.size - fitted) / 2.0
			draw_texture_rect(texture, Rect2(offset, fitted), false)
	draw_rect(rect, fill_color)
	draw_rect(rect, border_color, false, 2.0)
	if title != "":
		draw_string(ThemeDB.fallback_font, Vector2(4.0, -8.0), title,
				HORIZONTAL_ALIGNMENT_LEFT, rect.size.x, 13, title_color)
	if hint != "":
		draw_string(ThemeDB.fallback_font, Vector2(0.0, rect.size.y + 16.0), hint,
				HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 11, Color(title_color, 0.7))
	if not _active and _hover_t <= 0.0:
		return
	# Товар в руке: область подсвечена (пульсирует) и в ней слово «Купить».
	# Как только товар попадает в зону, подсветка усиливается: заливка
	# плотнее, рамка толще и ярче, слово крупнее. Не хватает звёзд —
	# та же подсветка, но красная, а слово бежевое.
	var glow := 0.75 + 0.25 * sin(_pulse)
	var fill := (highlight_color if _affordable else blocked_color).lerp(
			hover_color if _affordable else blocked_hover_color, _hover_t)
	var border := (highlight_border_color if _affordable else blocked_border_color).lerp(
			hover_border_color if _affordable else blocked_hover_border_color, _hover_t)
	var border_width := lerpf(highlight_border_width, hover_border_width, _hover_t)
	draw_rect(rect, Color(fill, fill.a * glow))
	draw_rect(rect, Color(border, border.a * glow), false, border_width)
	var caption_color := buy_color if _affordable else buy_blocked_color
	var caption_size := int(round(buy_font_size * lerpf(1.0, hover_caption_scale, _hover_t)))
	draw_string(UiFont.resolve(buy_font),
			Vector2(0.0, rect.size.y / 2.0 + caption_size * 0.36), buy_caption,
			HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, caption_size, caption_color)
