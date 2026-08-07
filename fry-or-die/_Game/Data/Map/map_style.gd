## Внешность экрана карты: две панели, граф на левой, игла на правой.
## Настраивается в `_Game/Data/Map/da_map_style.tres`, рисует — `gm_map.gd`.
##
## Экран поделён надвое: слева панель графа — её можно прокручивать, потому
## что карта выше экрана; справа панель накалывателя с иглой и стопкой
## пройденных уровней (её вид — в [SpikeStyle]).
##
## Каждый вид точки — свой ресурс [MapPointArt], поэтому картинку, размер
## и наклон магазина, боя, минибосса и босса можно менять в редакторе
## по отдельности:
##
## [codeblock]
## art_enemy     Map_Sheet_Battle             обычный бой
## art_miniboss  Map_Sheet__Mini_Boss_Battle  минибосс
## art_shop      Map_Sheet_Supermarket        магазин
## art_boss      Map_Sheet_Boss_Battle        финальный босс
## art_start     —                            вход в кухню
## [/codeblock]
##
## Это листки на весь тип точки. У минибосса же на листке нарисовано его
## орудие, поэтому свой листок он держит сам ([member EnemyModel.map_art]) —
## он и перебивает общий, см. [method art_for_node].
##
## Точка, где стоит игрок, обведена нарисованным овалом ([CircleStyle]) —
## он лежит поверх дорог ([member CircleStyle.layer]). Карта нарисована
## от руки, поэтому прямых на ней нет: точки гуляют от сетки, а линии
## маршрутов виляют.
class_name MapStyle
extends Resource

@export_group("Экран")
## Рамка вокруг обеих панелей.
@export var frame_color := Color(0.22, 0.22, 0.23)
@export var frame_margin := Vector2(0.0, 0.0)
## Зазор между панелями, px.
@export var panel_gap := 0.0
## Доля ширины под панель графа; остальное уходит под иглу.
@export_range(0.3, 0.9, 0.01) var graph_width_frac := 0.59
## Панель графа — светлая, как лист бумаги.
@export var graph_bg := Color(0.89, 0.83, 0.68)
@export var graph_bg_texture: Texture2D
## Панель накалывателя — тёмная.
@export var spike_bg := Color(0.29, 0.29, 0.29)
@export var spike_bg_texture: Texture2D

@export_group("Точки карты")
## Вход в кухню — нижняя точка карты.
@export var art_start: MapPointArt
## Обычный бой.
@export var art_enemy: MapPointArt
## Минибосс.
@export var art_miniboss: MapPointArt
## Магазин.
@export var art_shop: MapPointArt
## Финальный босс.
@export var art_boss: MapPointArt
## Общая поправка размера всех точек — чтобы разом сделать граф крупнее
## или мельче, не правя каждый вид точки.
@export_range(0.2, 3.0, 0.01) var point_scale := 1.0
## Наклон точек чередуется через одну; здесь — включать ли чередование.
@export var alternate_tilt := true

@export_group("Обводка точки")
## Нарисованный овал (`Circle_01`…`Circle_03`): стоит на точке, где игрок
## сейчас, и переезжает на выбранный уровень перед его запуском.
@export var circle: CircleStyle

@export_group("Раскладка графа")
## Высота карты в развёрнутом виде, px. Панель её прокручивает, поэтому
## места можно давать сколько угодно — листки не будут налезать друг
## на друга.
@export var content_height := 1600.0
## Отступы графа внутри содержимого, px.
@export var content_margin_top := 90.0
@export var content_margin_bottom := 90.0
## На столько линия отходит от центра панели, px.
@export var column_width := 150.0
## Насколько листки гуляют от идеальной сетки, px (на это множится
## [member MapNode.wobble]).
@export var wobble_pixels := Vector2(46.0, 22.0)
## Наклон листков в графе, градусы: знак чередуется через точку.
@export var sheet_tilt := 0.0

@export_group("Прокрутка")
## Шаг колеса мыши, px.
@export var scroll_step := 110.0
## Плавность доводки прокрутки.
@export var scroll_follow := 12.0
## Дальше этого сдвига мыши нажатие считается протяжкой, а не кликом, px.
@export var drag_threshold := 6.0

@export_group("Нить графа")
## Вертикальная нить через весь граф, на которой листки как бы и висят.
## Толщина 0 — нити нет (так и стоит сейчас).
@export var spine_color := Color(0.05, 0.05, 0.05)
@export var spine_width := 0.0
## Рисовать нить поверх листков (как на раскладке) или пропускать её
## позади них.
@export var spine_over_points := false

@export_group("Линии маршрутов")
@export var line_color := Color(0.05, 0.05, 0.05)
@export var line_width := 9.0
## Цвет уже пройденного участка пути.
@export var line_cleared_color := Color(0.55, 0.49, 0.4)
## Линия проведена от руки: на столько она отходит от прямой в середине,
## px. 0 — линия по линейке.
@export var line_wobble := 16.0
## Из скольких кусков собрана линия. Больше — плавнее виляет.
@export_range(1, 24, 1) var line_segments := 6
## Длина штриха и промежутка пунктира, px. 0 — сплошная линия.
@export var dash_length := 0.0
@export var dash_gap := 0.0

@export_group("Состояние точки")
## Насколько листок под курсором крупнее обычного.
@export var hover_grow := 1.06
## Затемнение точек, куда сейчас шагнуть нельзя. 0 — не затемнять.
@export_range(0.0, 1.0, 0.01) var locked_dim := 0.15
## След от прокола на месте пройденной точки: листок с него улетел на иглу.
@export var pin_color := Color(0.35, 0.3, 0.24)
@export var pin_radius := 7.0

@export_group("Подпись точки")
## Имя врага или магазина под курсором.
@export var title_font_size := 20
@export var title_color := Color(0.14, 0.12, 0.12)
@export var title_offset := Vector2(0.0, -14.0)
@export var title_outline_size := 6
@export var title_outline_color := Color(0.95, 0.91, 0.83, 0.95)
## Шрифт надписей карты. Пусто — шрифт проекта (Grunge Bold V2, см. [UiFont]).
@export var font: Font

@export_group("Легенда")
## Что означают листки — под иглой, в правой панели. С нарисованными
## листками легенда не нужна: на них и так видно, куда идёшь.
@export var show_legend := false
## Место первой строки легенды в долях панели накалывателя.
@export var legend_position := Vector2(0.08, 0.86)
@export var legend_row_height := 26.0
@export var legend_font_size := 17
@export var legend_color := Color(0.82, 0.81, 0.78)
## Подписи строк легенды — их видит игрок, поэтому по-английски.
@export var legend_shop_text := "S — shop"
@export var legend_miniboss_text := "M — mini-boss"
@export var legend_boss_text := "B — boss"

@export_group("Заголовок экрана")
## Пусто — заголовка нет; на панели и так тесно от листков.
@export var header_text := ""
## Место заголовка в долях панели графа.
@export var header_position := Vector2(0.5, 0.06)
@export var header_font_size := 26
@export var header_color := Color(0.2, 0.17, 0.14)


## Вид точки на карте: сначала свой листок её врага
## ([member EnemyModel.map_art]) — у каждого минибосса на листке нарисовано
## его орудие; своего нет — общий листок по типу точки ([method art_for]).
func art_for_node(node: MapNode) -> MapPointArt:
	if node == null:
		return art_enemy
	if node.enemy != null and node.enemy.map_art != null:
		return node.enemy.map_art
	return art_for(node.kind)


## Вид точки по её типу; null — вида нет, точка нарисуется заглушкой.
func art_for(kind: MapNode.Kind) -> MapPointArt:
	match kind:
		MapNode.Kind.START:
			return art_start
		MapNode.Kind.MINIBOSS:
			return art_miniboss
		MapNode.Kind.SHOP:
			return art_shop
		MapNode.Kind.BOSS:
			return art_boss
	return art_enemy
