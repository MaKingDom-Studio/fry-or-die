## Баланс боя. Настраивается в _Game/Data/Combat/da_combat.tres.
## Зоны стола настраиваются узлами CombatZone в сцене l_combat.tscn,
## визуал — в CombatTheme (da_combat_theme.tres).
class_name CombatConfig
extends GameConfig

@export_group("Звёзды")
## Сколько очков (веса ингредиентов) нужно на одну звезду.
@export var points_per_star := 10.0
## Характеристика игрока: сколько звёзд нужно заполнить, чтобы победить его.
## Цели заданы «крест-накрест» — это число идёт врагу, а игроку цель берётся
## из [member EnemyModel.star_target]. В HUD этот ряд стоит у врага.
@export var player_star_target := 5

@export_group("Раунд")
## Базовая длительность таймера. Отсчёт начинается, когда все ингредиенты упали.
@export var round_timer_seconds := 20.0
## Пауза между начислениями при подсчёте — звёзды заполняются постепенно.
@export var score_step_delay := 0.32

@export_group("Физика")
## Значения по умолчанию повторяют песочницу (da_sandbox.tres).
@export_range(0.0, 1.0) var ingredient_friction := 0.4
@export_range(0.0, 1.0) var elasticity := 0.805
## Торможение скольжения: 0 — ингредиенты скользят без замедления,
## как кубы в песочнице.
@export var slide_damp := 0.1
## Сопротивление вращения: 0 = крутится свободно, 1 = гаснет мгновенно.
@export_range(0.0, 1.0) var rotation_resistance := 0.142
@export var drag_stiffness := 60.0
@export var max_stretch := 300.0
@export var max_speed := 1400.0
@export_range(0.0, 1.0) var drag_inertia := 0.6
## Круг захвата под курсором, px: предмет можно схватить, кликнув не только
## точно по нему, но и рядом — берётся ближайший предмет, задетый кругом
## ([GrabArea]). Действует на ингредиенты стола, фишки корзин и мешка,
## специи и товары магазина. 0 — хватать только точным попаданием.
@export var grab_radius := 8.0

@export_group("Высыпание")
@export var drop_gravity := 2600.0
## Выдача ингредиентов на стол: базовая пауза между вылетами, с,
## и случайная добавка к каждой паузе (0..drop_stagger_random), с, —
## ритм выдачи получается неравномерным.
@export var drop_stagger := 0.12
@export var drop_stagger_random := 0.12
@export_range(0.0, 0.9) var drop_bounce := 0.3
## Перелёт содержимого корзины на стол в начале раунда.
@export var basket_flight_duration := 0.6
@export var basket_flight_arc := 90.0
## Наполнение корзины: скорость полёта фишек из точки появления, px/с,
## базовая пауза между вылетами соседних фишек, с, и случайная добавка
## к каждой паузе (0..basket_fill_stagger_random), с.
@export var basket_fill_speed := 900.0
@export var basket_fill_stagger := 0.1
@export var basket_fill_stagger_random := 0.1
## Высота сброса: полёт заканчивается на этой высоте над местом фишки
## в кучке, последний отрезок она падает — виден эффект пополнения.
@export var basket_fill_drop_height := 70.0
## Пауза в самом начале боя: после того как первые ингредиенты высыпались
## в корзины и осели, перед первым высыпанием на стол — игрок успевает
## разглядеть стартовый набор.
@export var combat_start_delay := 1.5

@export_group("Линия тяги")
## Линия от точки захвата до курсора при перетаскивании.
@export var drag_line_color := Color(0.13, 0.68, 0.96)
@export var drag_line_width := 6.0

@export_group("Круг захвата")
## Показывать ли круг захвата под курсором ([GrabCircleOverlay]);
## сам радиус — [member grab_radius]. Сам захват от галочки не зависит.
@export var grab_circle_visible := false
## Цвет контура круга; заливка — тот же цвет, ослабленный втрое.
@export var grab_circle_color := Color(0.13, 0.68, 0.96, 0.35)
## Толщина контура, px.
@export var grab_circle_width := 2.0
