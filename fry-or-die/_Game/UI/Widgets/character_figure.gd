@tool
## Фигурка персонажа на уровне: поварёнок, стоящий в магазине.
##
## Узел ставится туда, где фигурка стоит ногами: точка узла — низ по центру
## рисунка, а не середина холста PNG. Высота фигурки задаётся в пикселях
## ([member figure_height]), пропорции картинки сохраняются.
##
## Прозрачные поля картинки при этом не считаются
## ([member trim_transparent_margins]): у портретов персонажей они занимают
## большую часть холста (у `Player.png` сам поварёнок — нижняя треть), и без
## обрезки фигурка уезжала за нижний край экрана — в магазине игрока просто
## не было видно.
##
## В игре режим уровня подставляет сюда внешность своего персонажа
## ([member PortraitStyle.texture] из [member CharacterModel.portrait]), так
## что при смене персонажа менять сцену не нужно, а постановка фигурки от
## смены картинки не ломается: она считается заново по новому рисунку.
## Выключите [member use_character_portrait] — и останется картинка из
## инспектора.
class_name CharacterFigure
extends Node2D

## Непрозрачная часть картинок: текстура → прямоугольник рисунка в её
## пикселях. Считается один раз на текстуру, как силуэты ингредиентов.
static var _art_rects := {}

## Картинка фигурки. Видна прямо в редакторе; в игре её меняет
## [method apply].
@export var texture: Texture2D:
	set(value):
		texture = value
		queue_redraw()

## Брать картинку у персонажа уровня. Выключено — рисуется текстура,
## выставленная в инспекторе.
@export var use_character_portrait := true

@export_group("Постановка")
## Высота фигурки на экране, px (масштаб узла учитывается). Считается по
## самому рисунку, без прозрачных полей картинки. 0 — родной размер PNG.
@export var figure_height := 260.0:
	set(value):
		figure_height = maxf(value, 0.0)
		queue_redraw()

## Не считать прозрачные поля картинки: фигурка встаёт по рисунку, а не по
## холсту PNG. Выключено — рисуется вся картинка целиком, как есть.
@export var trim_transparent_margins := true:
	set(value):
		trim_transparent_margins = value
		queue_redraw()

## Сдвиг фигурки от точки узла, px: положительный y опускает её ниже (ноги
## уходят за край экрана), отрицательный — поднимает.
@export var offset := Vector2.ZERO:
	set(value):
		offset = value
		queue_redraw()


## Показать внешность этого персонажа. Вызывает режим уровня при старте;
## если у персонажа нет портрета-картинки, остаётся текстура из сцены.
func apply(character: CharacterModel) -> void:
	if not use_character_portrait or character == null:
		return
	if character.portrait != null and character.portrait.texture != null:
		texture = character.portrait.texture


## Место фигурки в локальных координатах узла: ширина по пропорциям
## рисунка, низ — на точке узла (там она стоит ногами). Пустой
## прямоугольник — рисовать нечего.
func figure_rect() -> Rect2:
	var source := _art_rect()
	if source.size.x <= 0.0 or source.size.y <= 0.0:
		return Rect2()
	var scale_factor := (figure_height / source.size.y) if figure_height > 0.0 else 1.0
	var size := source.size * scale_factor
	return Rect2(offset + Vector2(-size.x / 2.0, -size.y), size)


func _draw() -> void:
	if texture == null:
		return
	var source := _art_rect()
	var box := figure_rect()
	if box.size.x <= 0.0 or box.size.y <= 0.0:
		return
	draw_texture_rect_region(texture, box, source)


## Часть картинки с рисунком (в её пикселях): непрозрачный прямоугольник
## PNG или весь холст, если поля не обрезаются. Считается один раз на
## текстуру и запоминается — картинки персонажей большие.
func _art_rect() -> Rect2:
	if texture == null:
		return Rect2()
	var whole := Rect2(Vector2.ZERO, texture.get_size())
	if not trim_transparent_margins:
		return whole
	if _art_rects.has(texture):
		var cached: Rect2 = _art_rects[texture]
		return cached
	var rect := whole
	var image := texture.get_image()
	if image != null and not image.is_empty():
		if image.is_compressed():
			image.decompress()
		var used := image.get_used_rect()
		if used.size.x > 0 and used.size.y > 0:
			rect = Rect2(used)
	_art_rects[texture] = rect
	return rect
