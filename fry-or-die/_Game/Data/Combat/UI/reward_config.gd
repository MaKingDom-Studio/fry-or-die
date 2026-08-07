## Настройки награды за бой: что выпадает и как это разложено на экране
## ([RewardScreen]).
## Файл: _Game/Data/Combat/UI/da_window_reward.tres (назначен на узел Reward).
##
## Раскладка задана в координатах вьюпорта 1152 x 648 — ровно так, как
## нарисовано в `_Game/Art/Reward/Layout_Reward.png`: посередине счёт
## ([member check_texture]), под ним в ряд предметы награды, слева и справа
## от них бумажки с описаниями, снизу кнопка «Пропустить».
class_name RewardConfig
extends Resource

## Шрифт всех надписей экрана. Пусто — шрифт проекта (см. [UiFont]).
## В шрифте проекта нет знака процента, поэтому в описаниях предметов
## пишется сокращение «pct».
@export var font: Font

## Во сколько раз ужать всю раскладку награды относительно центра экрана:
## 1 — ровно так, как задано полями ниже, 0.6 — на 40 процентов меньше.
## Ужимается всё разом — счёт, бумажки, кнопка и кегли надписей, — поэтому
## пропорции экрана не меняются. Не ужимаются только значки ингредиентов и
## специй: они рисуются в свою боевую величину ([member item_scale]).
## Картинок победы и поражения это тоже не касается: у них свои
## [member victory_rect] и [member defeat_rect].
@export_range(0.1, 2.0, 0.01) var layout_scale := 0.6

@export_group("Что выпадает")
## Шанс, что ингредиент за бой окажется положительным (иначе — с уникальным
## эффектом). 0.75 — три четверти боёв.
@export_range(0.0, 1.0, 0.01) var positive_chance := 0.75
## Шанс, что вдобавок выпадет случайная специя.
@export_range(0.0, 1.0, 0.01) var spice_chance := 0.25
## Положительные ингредиенты (множитель больше 1).
@export var positive_pool: Array[IngredientModel] = []
## Ингредиенты с уникальным эффектом.
@export var effect_pool: Array[IngredientModel] = []
## Специи, которые могут выпасть за бой. Те, что у игрока уже есть, не
## выпадают — их бонус постоянный и не складывается.
@export var spice_pool: Array[SpiceModel] = []
## Специя, которую всегда отдаёт минибосс (крутой перец). Второй его
## наградой идёт собственное орудие ([member EnemyModel.reward_tool]).
@export var miniboss_spice: SpiceModel

@export_group("Экран победы")
## Картинка «You're on fire!», которую видно перед наградой.
@export var victory_texture: Texture2D
## Сколько секунд держать экран победы.
@export_range(0.0, 10.0, 0.1, "or_greater") var victory_seconds := 2.0
## Куда вписана картинка победы (пропорции сохраняются).
@export var victory_rect := Rect2(307, 94, 537, 460)
## Затемнение фона: и под экраном победы, и под наградой.
@export var dim_color := Color(0.0, 0.0, 0.0, 0.85)
## За сколько секунд затемнение и картинка проявляются.
@export_range(0.0, 2.0, 0.01, "or_greater") var fade_seconds := 0.25

@export_group("Экран поражения")
## Картинка «Chopped», которую видно вместо награды, когда бой проигран.
@export var defeat_texture: Texture2D
## Куда вписана картинка поражения (пропорции сохраняются). По умолчанию —
## то же место, что и у картинки победы ([member victory_rect]).
@export var defeat_rect := Rect2(307, 94, 537, 460)
## Кнопка «Fry Again» под картинкой поражения (Button_Try_Again.png).
@export var try_again_texture: Texture2D
## Куда вписана кнопка — снизу по центру, под картинкой.
@export var try_again_rect := Rect2(476, 500, 200, 98)
## Кнопка появляется не сразу: столько секунд после картинки, с.
@export_range(0.0, 5.0, 0.05, "or_greater") var try_again_delay := 0.8
## Во сколько раз крупнее кнопка под курсором.
@export_range(1.0, 2.0, 0.01) var try_again_hover_scale := 1.06
## Надпись на кнопке, если картинки нет.
@export var try_again_text := "FRY AGAIN"
@export var try_again_font_size := 32
@export var try_again_text_color := Color(0.98, 0.88, 0.7)
@export var try_again_fill := Color(0.45, 0.16, 0.07)
@export var try_again_border := Color(0.95, 0.6, 0.15)

@export_group("Счёт")
## Сам счёт: «SERVED!», «Total» и «Select everything you want to take:»
## нарисованы на картинке.
@export var check_texture: Texture2D
@export var check_rect := Rect2(359, 46, 398, 462)
## Звезда в строке «Total» — её центр.
@export var total_star_pos := Vector2(680, 214)
@export var total_star_radius := 17.0
@export var total_star_color := Color(0.98, 0.65, 0.1)
## Число звёзд: левый край текста, по вертикали — середина строки.
@export var total_number_pos := Vector2(702, 214)
@export var total_font_size := 38
@export var total_color := Color(0.09, 0.08, 0.07)

@export_group("Предметы")
## Центры мест под предметы, слева направо. Один предмет встаёт посередине
## между этими точками — бумажка с описанием остаётся левой.
@export var slot_left := Vector2(478, 374)
@export var slot_right := Vector2(629, 374)
## Множитель к настоящей величине предмета. Ингредиент и специя рисуются
## ровно того размера, какого они в бою: ингредиент — по своему радиусу
## (как на столе, [method IngredientNode.texture_box]), специя — по своему
## (как на полке, [method SpiceNode.texture_box]). 1 — размер один в один.
## Величина значка от [member layout_scale] не зависит: ужимается раскладка
## вокруг предметов, а сами предметы остаются такими же, какими игрок
## только что двигал их по столу.
@export_range(0.1, 4.0, 0.01) var item_scale := 1.0
## Наименьший зазор между двумя значками, px. Предметы настоящей величины
## крупнее мокапных мест, поэтому места раздвигаются, если крупная пара
## иначе налезла бы друг на друга.
@export_range(0.0, 60.0, 1.0, "or_greater") var item_gap := 12.0
## Во что вписан значок инструмента: своей величины у инструмента нет,
## поэтому картинка вписывается в этот бокс (пропорции сохраняются).
## Бокс раскладочный — ужимается вместе с ней ([member layout_scale]).
@export var tool_box := Vector2(104, 104)
## Во сколько раз крупнее значок под курсором.
@export_range(1.0, 2.0, 0.01) var hover_scale := 1.1
## Обводка значка под курсором; прозрачная — обводки нет.
@export var hover_outline := Color(1.0, 0.85, 0.3, 0.0)
## Обводка значка предмета — у ингредиента, специи и инструмента одинаковая.
## Идёт по контуру непрозрачных пикселей картинки, как обводка ингредиента
## на столе. Прозрачная — обводки нет.
@export var item_outline := Color(0.08, 0.08, 0.1, 0.9)
## Толщина обводки значка, px на экране — та же, что у обводки ингредиента
## на столе, значки ведь и рисуются в свою боевую величину. 0 — обводки нет.
@export_range(0.0, 8.0, 0.1) var item_outline_width := 3.0

@export_group("Бумажки с описанием")
## Левая бумажка — описание левого предмета.
@export var sheet_left_texture: Texture2D
@export var sheet_left_rect := Rect2(232, 294, 172, 165)
## Правая бумажка — описание правого предмета.
@export var sheet_right_texture: Texture2D
@export var sheet_right_rect := Rect2(704, 289, 182, 170)
## Поля текста внутри бумажки, px.
@export var sheet_padding := Vector2(24, 26)
@export var sheet_title_font_size := 19
@export var sheet_title_color := Color(0.36, 0.14, 0.07)
@export var sheet_body_font_size := 14
@export var sheet_body_color := Color(0.42, 0.22, 0.11)
## Отступ описания от названия, px.
@export var sheet_title_gap := 4.0

@export_group("Кнопка «Пропустить»")
@export var skip_texture: Texture2D
## Кнопка стоит на 13 px ниже мокапа: с [member layout_scale] это примерно
## 8 px на экране — ровно настолько она отодвинута от нижнего края счёта.
@export var skip_rect := Rect2(472, 507, 159, 78)
## Надпись, если картинки кнопки нет.
@export var skip_text := "SKIP"
@export var skip_font_size := 24
@export var skip_text_color := Color(0.98, 0.88, 0.7)
@export var skip_fill := Color(0.45, 0.16, 0.07)
@export var skip_border := Color(0.95, 0.6, 0.15)
## Во сколько раз крупнее кнопка под курсором.
@export_range(1.0, 2.0, 0.01) var skip_hover_scale := 1.06

@export_group("Полёт забранного")
## Сколько летит предмет до холодильника, полки специй или сумки, с.
@export_range(0.05, 3.0, 0.01, "or_greater") var fly_seconds := 0.5
## Во сколько раз ужимается предмет к концу полёта.
@export_range(0.01, 1.0, 0.01) var fly_scale := 0.15
## Пауза после того, как забрали последний предмет, перед уходом на карту, с.
@export_range(0.0, 3.0, 0.05, "or_greater") var leave_delay := 0.25
