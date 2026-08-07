## Настройки строк сообщений: «Подсчёт: поле ...» и уведомления эффектов.
## Файл: _Game/Data/Combat/UI/da_window_messages.tres (назначен на Hud).
class_name MessagesConfig
extends Resource

## Центр строки подсчёта (x — середина экрана по умолчанию).
@export var scoring_pos := Vector2(576, 300)
@export var scoring_color := Color(1.0, 0.78, 0.2)
## Шрифт строки подсчёта. Пусто — шрифт проекта (Grunge Bold V2), как у
## имён сторон ([HudNameLabel]).
@export var scoring_font: Font
@export var scoring_font_size := 26
## Центр строки уведомлений («Burner destroyed: ...», «Гриб: +2
## ингредиента...») — под строкой подсчёта, чтобы они не накрывали друг друга.
@export var notice_pos := Vector2(576, 330)
@export var notice_color := Color(0.85, 0.95, 1.0)
## Цвет сообщений о сгоревшем ингредиенте («Burner destroyed: ...»,
## «... burns: ...») — бордово-красный.
@export var burn_color := Color(0.65, 0.1, 0.15)
## Шрифт строки уведомлений. Пусто — шрифт проекта (Grunge Bold V2), тот же,
## что у строки подсчёта.
@export var notice_font: Font
@export var notice_font_size := 20
## Сколько секунд висит уведомление.
@export var notice_duration := 2.4
