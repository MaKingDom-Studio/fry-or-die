@tool
## Портрет стороны в HUD. Позиция (в том числе позиция врага) настраивается
## в редакторе перетаскиванием узла; внешность — [PortraitStyle] из Data
## персонажа/врага.
##
## Размер портрета задаётся в узле ([member texture_size],
## [member portrait_scale]) — это постановка HUD, она настраивается в сцене
## и от того, кто сейчас стоит напротив, не зависит. Пусто — размер из Data.
##
## Картинка, наоборот, всегда берётся из Data стороны: враг меняется каждый
## бой, и [member texture] из сцены показывала бы всем врагам одно лицо.
## Она нужна для превью в редакторе (там Data ещё не подключена) и как
## запасная, если в Data картинки нет.
##
## Имя стороны портрет не пишет — это отдельный узел [HudNameLabel].
class_name HudPortrait
extends Node2D

## Чей портрет: врага или игрока.
@export var enemy := false:
	set(value):
		enemy = value
		queue_redraw()

@export_group("Картинка")
## Превью портрета в редакторе, пока Data ещё не подключена. В игре
## главнее картинка из Data стороны — эта берётся, только если там пусто.
@export var texture: Texture2D:
	set(value):
		texture = value
		queue_redraw()

## Размер портрета в HUD, px (умножается на масштаб) — это сторона квадрата,
## в который вписывается картинка: длинная сторона PNG равна ему, короткая
## считается по пропорциям. 0 — как в Data.
@export var texture_size := 0.0:
	set(value):
		texture_size = maxf(value, 0.0)
		queue_redraw()

## Масштаб портрета; 0 — как в Data.
@export var portrait_scale := 0.0:
	set(value):
		portrait_scale = maxf(value, 0.0)
		queue_redraw()

var gm = null
var _style: PortraitStyle


func attach(game_mode) -> void:
	gm = game_mode
	_style = gm.enemy.portrait if enemy else gm.player.character.portrait
	queue_redraw()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()


func _draw() -> void:
	var style := _style
	if style == null:
		style = PortraitStyle.new()
		if enemy:
			style.has_mustache = true
			style.scale = 1.5
	# Картинка — из Data стороны: враг в забеге меняется от боя к бою, а узел
	# в сцене один. Узловая текстура — превью редактора и запасной вариант.
	# Размер и масштаб, наоборот, главнее из узла: это постановка HUD.
	var art := style.texture if style.texture != null else texture
	var art_scale := portrait_scale if portrait_scale > 0.0 else style.scale
	var art_size := texture_size if texture_size > 0.0 else style.texture_size
	if art != null:
		draw_texture_rect(art, _fitted_box(art, art_size * art_scale), false)
	else:
		_draw_chef(style, art_scale)


## Бокс отрисовки портрета: центр в нуле, пропорции PNG сохранены — длинная
## сторона равна side. Без этого повара (1472×1059) растягивались в квадрат
## и выглядели сжатыми по горизонтали.
func _fitted_box(art: Texture2D, side: float) -> Rect2:
	var source := art.get_size()
	var longest := maxf(source.x, source.y)
	if longest <= 0.0:
		return Rect2(Vector2(-side, -side) / 2.0, Vector2(side, side))
	var box := source * (side / longest)
	return Rect2(-box / 2.0, box)


func _draw_chef(style: PortraitStyle, f: float) -> void:
	draw_circle(Vector2(0, 16) * f, 20.0 * f, style.body_color)
	draw_circle(Vector2.ZERO, 13.0 * f, style.skin_color)
	# Колпак.
	draw_rect(Rect2(Vector2(-10, -26) * f, Vector2(20, 12) * f), style.hat_color)
	draw_circle(Vector2(-6, -26) * f, 7.0 * f, style.hat_color)
	draw_circle(Vector2(5, -28) * f, 8.0 * f, style.hat_color)
	# Глаза.
	draw_circle(Vector2(-4, -2) * f, 1.6 * f, style.eyes_color)
	draw_circle(Vector2(4, -2) * f, 1.6 * f, style.eyes_color)
	if style.has_mustache:
		draw_circle(Vector2(-6, 5) * f, 5.0 * f, style.mustache_color)
		draw_circle(Vector2(6, 5) * f, 5.0 * f, style.mustache_color)
