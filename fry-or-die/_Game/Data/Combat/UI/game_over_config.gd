## Настройки экрана победы/поражения.
## Файл: _Game/Data/Combat/UI/da_window_game_over.tres (назначен на Hud).
class_name GameOverConfig
extends Resource

@export var dim := Color(0.0, 0.0, 0.0, 0.72)
@export var victory_text := "VICTORY!"
@export var defeat_text := "DEFEAT"
@export var title_y := 260.0
@export var title_font_size := 52
@export var victory_color := Color(1.0, 0.78, 0.2)
@export var defeat_color := Color(0.95, 0.3, 0.25)
@export var subtitle_y := 310.0
@export var subtitle_font_size := 16
@export var text_color := Color(0.85, 0.85, 0.88)
## Строка с наградой за победу (инструмент врага). Рисуется под подзаголовком:
## квадратик цвета инструмента и его название. %s — название инструмента.
@export var reward_text := "Tool received: %s"
@export var reward_y := 334.0
@export var reward_font_size := 18
@export var reward_color := Color(1.0, 0.9, 0.55)
## Сторона квадратика с цветом инструмента слева от названия.
@export var reward_chip_size := 16.0
@export var button_text := "Play again"
@export var button_rect := Rect2(486, 350, 180, 46)
@export var button_fill := Color(0.2, 0.45, 0.3)
@export var button_border := Color(0.7, 0.95, 0.75)
@export var button_font_size := 16
