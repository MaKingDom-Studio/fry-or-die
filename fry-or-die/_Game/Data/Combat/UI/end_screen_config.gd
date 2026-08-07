## Настройки финального экрана ([EndScreen]) — того, что открывается после
## победы над последним боссом.
## Файл: _Game/Data/Combat/UI/da_window_end.tres (назначен на узел EndScreen).
##
## Экран простой: сплошной чёрный фон во весь вьюпорт, поверх него картинка
## концовки (`_Game/Art/Victory_Defeat/END.png`), а снизу — кнопка
## перезапуска (`Button_Try_Again.png`). Размеры заданы долями экрана, чтобы
## экран одинаково собирался при любом размере окна.
class_name EndScreenConfig
extends Resource

## Шрифт надписи на кнопке, если картинки кнопки нет. Пусто — шрифт проекта
## (см. [UiFont]).
@export var font: Font

@export_group("Фон")
## Заливка под всем экраном: по умолчанию сплошной чёрный.
@export var background := Color(0.0, 0.0, 0.0, 1.0)
## За сколько секунд экран проявляется.
@export_range(0.0, 3.0, 0.01, "or_greater") var fade_seconds := 0.6

@export_group("Картинка концовки")
## Картинка END.png. Пусто — берётся по пути
## [constant EndScreen.END_TEXTURE_PATH], если файл лежит в проекте.
@export var texture: Texture2D
## Во что вписана картинка, в долях вьюпорта: (0, 0) — от левого верхнего
## угла, (1, 0.8) — вся ширина и 80 процентов высоты (ниже стоит кнопка).
## Пропорции картинки сохраняются, лишнее место остаётся чёрным.
@export var rect := Rect2(0.0, 0.0, 1.0, 0.8)

@export_group("Кнопка перезапуска")
## Картинка кнопки (Button_Try_Again.png).
@export var button_texture: Texture2D
## Куда вписана кнопка, в долях вьюпорта — она стоит снизу по центру.
@export var button_rect := Rect2(0.36, 0.8, 0.28, 0.16)
## Во сколько раз крупнее кнопка под курсором.
@export_range(1.0, 2.0, 0.01) var button_hover_scale := 1.08
## Кнопка появляется не сразу: столько секунд после картинки, с.
@export_range(0.0, 5.0, 0.05, "or_greater") var button_delay := 0.8
## Надпись на кнопке, если картинки нет.
@export var button_text := "FRY AGAIN"
@export var button_font_size := 32
@export var button_text_color := Color(0.98, 0.88, 0.7)
@export var button_fill := Color(0.45, 0.16, 0.07)
@export var button_border := Color(0.95, 0.6, 0.15)
