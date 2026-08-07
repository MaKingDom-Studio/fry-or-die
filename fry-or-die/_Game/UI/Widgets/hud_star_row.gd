@tool
## Ряд звёзд одной из сторон. Позиция настраивается в редакторе (узел),
## цвета и размеры — в инспекторе; в редакторе виден превью-ряд.
##
## Звёзды — картинки из _Game/Art/Star: Star.png — контур (внутри он
## прозрачный), Star_Fill.png — белый силуэт под ним, который красится
## цветом заливки. Каждая звезда заполняется жёлтым слева направо по мере
## набора очков, а подпись под рядом считает звёзды дробью до сотых
## («1.25 / 5»), а не очки, — шрифтом проекта, как имена сторон. Сюда же
## прилетают партиклы подсчёта ([StarParticles]) — цель им выдаёт
## [method slot_global_position].
class_name HudStarRow
extends Node2D

## Чью шкалу показывать: врага или игрока.
@export var enemy := false
@export var star_radius := 13.0
@export var star_spacing := 32.0
## Перенос: сколько звёзд в строке; 0 — все в одну строку.
@export var stars_per_row := 0
## Расстояние между строками при переносе.
@export var row_spacing := 30.0
@export var filled_color := Color(1.0, 0.78, 0.2)
@export var empty_color := Color(0.3, 0.3, 0.34)
@export var outline_color := Color(0.5, 0.5, 0.55)
@export var outline_filled_color := Color(0.85, 0.7, 0.3)
@export var points_text_color := Color(0.9, 0.9, 0.92)
## Отступ подписи-счётчика от последней строки звёзд.
@export var points_label_offset := Vector2(0, 38)
## Шрифт счётчика. Пусто — шрифт проекта (Grunge Bold V2), как у имён
## сторон ([HudNameLabel]).
@export var points_font: Font
@export var points_font_size := 16

@export_group("Картинки")
## Контур звезды (внутри прозрачный). Пусто — прежняя рисованная фигура.
@export var star_texture: Texture2D = preload("res://_Game/Art/Star/Star.png")
## Белый силуэт звезды под контуром — красится цветами заполнения.
@export var fill_texture: Texture2D = preload("res://_Game/Art/Star/Star_Fill.png")

@export_group("Редактор")
## Сколько звёзд рисовать в превью редактора.
@export var editor_preview_stars := 5

var gm = null
var _shown_points := 0.0


func attach(game_mode) -> void:
	gm = game_mode


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()
		return
	if gm == null:
		return
	# Звёзды догоняют реальные очки постепенно.
	var track = gm.enemy_stars if enemy else gm.player_stars
	_shown_points = move_toward(_shown_points, track.points, delta * 26.0)
	queue_redraw()


func _draw() -> void:
	var count := editor_preview_stars
	var points_per_star := 10.0
	if gm != null:
		var track = gm.enemy_stars if enemy else gm.player_stars
		count = track.target_stars
		points_per_star = track.points_per_star
	for i in count:
		var fraction := clampf(_shown_points / points_per_star - i, 0.0, 1.0)
		_draw_star(_slot_position(i), star_radius, fraction)
	# Счётчик под звёздами — в звёздах, а не в очках: «1.25 / 5».
	draw_string(UiFont.resolve(points_font),
			points_label_offset + Vector2(0.0, _last_row_y()),
			"%s / %d" % [_counter_text(points_per_star), count],
			HORIZONTAL_ALIGNMENT_LEFT, 160, points_font_size, points_text_color)


## Позиция звезды с учётом переноса строк.
func _slot_position(index: int) -> Vector2:
	if stars_per_row <= 0:
		return Vector2(index * star_spacing, 0.0)
	var column := index % stars_per_row
	var row := floori(float(index) / stars_per_row)
	return Vector2(column * star_spacing, row * row_spacing)


## Глобальная позиция звезды с индексом index — сюда летят партиклы подсчёта.
func slot_global_position(index: int) -> Vector2:
	return to_global(_slot_position(maxi(index, 0)))


## Значение счётчика: набранные звёзды дробью — не больше двух знаков после
## запятой, лишние нули срезаются («1.25», «1.5», «2») — как в подписях
## подсчёта (`gm_combat._star_fraction_label`).
func _counter_text(points_per_star: float) -> String:
	var stars := _shown_points / points_per_star if points_per_star > 0.0 else 0.0
	var text := "%.2f" % stars
	if text.contains("."):
		text = text.rstrip("0").rstrip(".")
	return "0" if text == "" else text


## Y последней строки звёзд — от неё отсчитывается подпись-счётчик.
func _last_row_y() -> float:
	var count := editor_preview_stars
	if gm != null:
		var track = gm.enemy_stars if enemy else gm.player_stars
		count = track.target_stars
	if stars_per_row <= 0 or count <= 0:
		return 0.0
	return floori(float(count - 1) / stars_per_row) * row_spacing


## Одна звезда: тёмный силуэт целиком, поверх — жёлтая часть силуэта,
## обрезанная по доле слева направо, и контур сверху. Без картинок —
## прежняя рисованная фигура.
func _draw_star(center: Vector2, r: float, fraction: float) -> void:
	if star_texture == null or fill_texture == null:
		_draw_star_shape(center, r, fraction)
		return
	var box := _star_box(center, r)
	draw_texture_rect(fill_texture, box, false, empty_color)
	if fraction >= 1.0:
		draw_texture_rect(fill_texture, box, false, filled_color)
	elif fraction > 0.0:
		var source := fill_texture.get_size()
		draw_texture_rect_region(fill_texture,
				Rect2(box.position, Vector2(box.size.x * fraction, box.size.y)),
				Rect2(0.0, 0.0, source.x * fraction, source.y), filled_color)
	draw_texture_rect(star_texture, box, false)


## Бокс картинки звезды: центр в center, длинная сторона равна диаметру.
func _star_box(center: Vector2, r: float) -> Rect2:
	var source := star_texture.get_size()
	var longest := maxf(source.x, source.y)
	if longest <= 0.0:
		return Rect2(center - Vector2(r, r), Vector2(r, r) * 2.0)
	var box := source * (r * 2.0 / longest)
	return Rect2(center - box / 2.0, box)


## Запасная рисованная звезда — на случай пустой картинки.
func _draw_star_shape(center: Vector2, r: float, fraction: float) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var angle := -PI / 2.0 + TAU * i / 10.0
		var radius := r if i % 2 == 0 else r * 0.45
		pts.append(center + Vector2(cos(angle), sin(angle)) * radius)
	if fraction >= 1.0:
		draw_colored_polygon(pts, filled_color)
	elif fraction > 0.0:
		draw_colored_polygon(pts, Color(filled_color, 0.2 + fraction * 0.6))
	else:
		draw_colored_polygon(pts, empty_color)
	var outline := pts.duplicate()
	outline.append(pts[0])
	draw_polyline(outline, outline_filled_color if fraction >= 1.0 else outline_color, 1.5)
