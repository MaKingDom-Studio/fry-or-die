## Визуальная тема боевой сцены — то, что не привязано к конкретному узлу:
## стол, верхняя панель, вспышка, вид ингредиентов.
## Настраивается в _Game/Data/Combat/da_combat_theme.tres.
##
## Окна (выбор инструмента, баннер горелки, сообщения, победа/поражение)
## настраиваются отдельными файлами _Game/Data/Combat/UI/da_window_*.tres,
## назначенными на узел Hud. Остальное — прямо на сцене l_combat.tscn:
## задний фон — узел SceneBackground; зоны стола и границы — узлы
## CombatZone; элементы HUD (портреты, звёзды, таймер, специи,
## инструменты, кнопка мешка) — виджеты-узлы под Hud; корзины —
## узлы ChipContainer, мешок — узел BagPanel; внешность персонажа
## и врага — PortraitStyle в их .tres в Data.
class_name CombatTheme
extends Resource

@export_group("Стол")
## Текстура стола (опционально; рисуется вместо цвета table_color).
@export var table_texture: Texture2D
@export var table_color := Color(0.17, 0.17, 0.19)
## Насколько стол выступает за пределы зон, px.
@export var table_margin := 12.0

@export_group("Верхняя панель")
@export var top_panel_color := Color(0.13, 0.13, 0.15)
@export var top_panel_height := 168.0
@export var top_panel_divider := Color(0.9, 0.75, 0.3)
@export var text_primary := Color(0.9, 0.9, 0.92)
@export var text_secondary := Color(0.75, 0.75, 0.8)

@export_group("Вспышка")
@export var flash_color := Color.WHITE
## Начальная непрозрачность вспышки (0..1).
@export_range(0.0, 1.0) var flash_strength := 0.9
## Скорость затухания вспышки (единиц альфы в секунду).
@export var flash_fade_speed := 2.2

@export_group("Выжигание")
## Материал растворения ингредиента: шейдер «burn dissolve from point»
## (_Game/Art/Shaders/burn_dissolve.gdshader). Работает и на горелке игрока,
## и на сжигании врагом. Пусто — ингредиент просто исчезает без эффекта.
@export var burn_material: ShaderMaterial
## Сколько длится растворение, с.
@export var burn_duration := 1.5

@export_group("Ингредиенты")
@export var ingredient_shadow := Color(0.02, 0.02, 0.04, 0.45)
@export var ingredient_outline := Color(0.08, 0.08, 0.1)
@export var locked_outline := Color(0.45, 0.45, 0.5)
@export var permanent_outline := Color(0.75, 0.2, 0.15)
@export var permanent_mark_color := Color(0.95, 0.4, 0.3)
@export var drag_outline := Color(0.13, 0.68, 0.96)
## Обводка приклеенного клеем липкого ингредиента ([member IngredientNode.glued]).
@export var glue_outline := Color(0.55, 0.85, 0.35)
## Подпись над неуязвимым ингредиентом ([member IngredientNode.untouchable] —
## первая бутылка водки за бой): текст, кегль, цвет и цвет подложки на пиксель.
## Пустой текст — подписи нет.
@export var untouchable_label := "UNTOUCHABLE"
@export var untouchable_label_font_size := 12
@export var untouchable_label_color := Color(0.95, 0.18, 0.14)
@export var untouchable_label_shadow := Color(0.05, 0.02, 0.02, 0.75)
## Затемнение недоступного: изображение рисуется поверх само на себя,
## умноженное на этот цвет, — объект гаснет ровно по пикселям PNG. Так
## помечены неуязвимый ([member IngredientNode.untouchable]) и всё, что лежит
## на половине врага ([member IngredientNode.grab_blocked]). Тёмный цвет —
## сила затемнения, альфа — его плотность.
@export var untouchable_tint := Color(0.22, 0.22, 0.22, 0.8)
## Цвет вспышки в момент прилипания: ингредиент коротко моргает — видно, что
## клей сработал. Эффект — тот же материал, что и на подсчёте
## ([member score_hit_material]); без него моргания не будет.
@export var glue_flash_color := Color(1.0, 1.0, 1.0)
## Сколько длится моргание при прилипании, с. Специально короткое.
@export var glue_flash_duration := 0.18
@export var score_highlight := Color(1.0, 0.85, 0.3)
@export var frozen_tint := Color(0.6, 0.8, 1.0, 0.25)
@export var show_ingredient_labels := true
@export var ingredient_label_font_size := 10
## Цвет подписи на светлой / тёмной заливке.
@export var label_text_dark := Color(0.1, 0.1, 0.12)
@export var label_text_light := Color(0.95, 0.95, 0.97)

@export_group("Подсчёт")
## Материал эффекта подсчёта: шейдер «trigger hit effect»
## (_Game/Art/Shaders/score_hit.gdshader) — ингредиент дрожит и мигает, когда
## его считают. Пусто — остаётся только подпись с долей звезды.
@export var score_hit_material: ShaderMaterial
## Сколько длится тряска с миганием одного ингредиента, с.
@export var score_hit_duration := 0.45
## Цвет вспышки и числа для ингредиента в минус (в плюс — score_highlight).
## Подпись «звезда + доля» рисует узел ScoreLabels ([CombatScoreLabels]) — её
## размеры и время жизни настраиваются на сцене.
@export var score_flash_negative := Color(0.95, 0.3, 0.25)
