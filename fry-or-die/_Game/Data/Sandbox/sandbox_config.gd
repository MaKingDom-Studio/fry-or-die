class_name SandboxConfig
extends Resource

## Весь баланс песочницы в одном ресурсе (аналог DataAsset из UE).
## Значения настраиваются в da_sandbox.tres, не в коде.

@export_group("Arena")
@export var arena_width := 900.0
@export var arena_height := 540.0
@export var wall_thickness := 60.0

@export_group("Inventory")
## Стартовый инвентарь: какие кубы и в каком количестве спавнятся на арену.
@export var inventory: InventoryConfig

@export_group("Physics")
## Трение между кубами при контакте.
@export_range(0.0, 1.0) var square_friction := 0.4
## Сила упругости: 0 = удар без отскока (о стену куб останавливается,
## с другим кубом слипается по импульсу), 1 = отскок без потери скорости.
@export_range(0.0, 1.0) var elasticity := 1.0
## Сопротивление вращения: 0 = крутится свободно,
## 1 = вращение гаснет мгновенно.
@export_range(0.0, 1.0) var rotation_resistance := 0.0

@export_group("Spawn Drop")
## Ускорение падения при высыпании кубов на доску, px/s^2 (0 — без эффекта).
@export var drop_gravity := 2600.0
## Пауза между стартами падения соседних кубов (каскад при старте).
@export var drop_stagger := 0.08
## Подскок при приземлении: доля сохраняемой скорости, 0 — без отскока.
@export_range(0.0, 0.9) var drop_bounce := 0.3

@export_group("Drag")
@export var drag_stiffness := 60.0
@export var max_stretch := 300.0
@export var max_speed := 1400.0
## Инерция при перетаскивании: 0 = куб жёстко следует за курсором,
## 1 = сильно раскачивается и долго продолжает движение по инерции.
@export_range(0.0, 1.0) var drag_inertia := 0.6
## Круг захвата под курсором, px: куб можно схватить и кликом рядом с ним —
## берётся ближайший, задетый кругом ([GrabArea]). 0 — только точное попадание.
@export var grab_radius := 8.0
## Показывать ли круг захвата под курсором ([GrabCircleOverlay]).
## Сам захват от галочки не зависит.
@export var grab_circle_visible := false
## Цвет контура круга; заливка — тот же цвет, ослабленный втрое.
@export var grab_circle_color := Color(0.13, 0.68, 0.96, 0.35)
## Толщина контура, px.
@export var grab_circle_width := 2.0
