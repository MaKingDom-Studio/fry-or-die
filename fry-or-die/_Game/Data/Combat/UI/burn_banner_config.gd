## Настройки баннера горелки («кликните по ингредиенту, чтобы выжечь»).
## Файл: _Game/Data/Combat/UI/da_window_burn.tres (назначен на Hud).
class_name BurnBannerConfig
extends Resource

## Положение и размер баннера на экране.
@export var rect := Rect2(176, 246, 800, 46)
@export var fill := Color(0.1, 0.1, 0.12, 0.9)
@export var border := Color(0.95, 0.35, 0.75)
@export var text_color := Color(0.95, 0.95, 0.97)
@export var font_size := 14
@export var skip_button_size := Vector2(128, 32)
@export var skip_button_fill := Color(0.3, 0.3, 0.34)
@export var skip_font_size := 13
