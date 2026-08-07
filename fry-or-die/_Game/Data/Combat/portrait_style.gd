## Внешность стороны боя в HUD: портрет-текстура или рисованный повар.
##
## Лежит в Data персонажа ([member CharacterModel.portrait]) и врага
## ([member EnemyModel.portrait]) — визуал каждой стороны настраивается
## в её собственном .tres, без правки кода.
class_name PortraitStyle
extends Resource

## Портрет-изображение; если не задано, рисуется фигурка повара.
@export var texture: Texture2D
## Размер текстуры-портрета в HUD, px (умножается на scale).
@export var texture_size := 64.0
## Общий масштаб портрета (и рисованного, и текстуры).
@export var scale := 1.0

@export_group("Рисованный повар")
@export var body_color := Color(0.93, 0.93, 0.95)
@export var skin_color := Color(0.95, 0.93, 0.9)
@export var hat_color := Color.WHITE
@export var eyes_color := Color(0.1, 0.1, 0.12)
@export var has_mustache := false
@export var mustache_color := Color(0.35, 0.2, 0.08)

@export_group("Подпись")
@export var name_color := Color(0.9, 0.9, 0.92)
