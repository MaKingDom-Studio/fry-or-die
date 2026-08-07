## Игла со стопкой листков и вид самих листков.
## Настраивается в `_Game/Data/Map/da_map_spike.tres`.
##
## Правая панель экрана карты — накалыватель: игла с подставкой
## (`Map_Needle`) и стопка листков пройденных уровней. Листки берутся из
## [SheetArt] по порядку прохождения: `Back_Sheet_01`/`Forward_Sheet_01` —
## первый уровень, дальше по номерам; за магазин всегда накалывается
## [member shop_sheet] (список покупок).
##
## Игла рассчитана на всю стопку: шаг между листками считается от её
## свободной части и от того, сколько уровней вообще есть на маршруте
## ([method stack_step]), поэтому последний листок не уезжает за острие.
class_name SpikeStyle
extends Resource

@export_group("Игла")
## Картинка иглы вместе с подставкой (`Map_Needle`); пусто — рисуется
## линией и прямоугольной подставкой.
@export var needle_texture: Texture2D
## Где стоит игла внутри правой панели, в долях её ширины.
@export_range(0.0, 1.0, 0.01) var needle_x_frac := 0.49
## Сколько высоты панели занимает картинка иглы.
@export_range(0.1, 1.5, 0.01) var needle_height_frac := 0.95
## Где у панели стоит низ подставки, в долях высоты панели.
@export_range(0.0, 1.2, 0.01) var needle_bottom_frac := 0.99
## Где на картинке иглы её стержень, острие и верх подставки — в долях
## картинки. По ним считается, докуда листки насаживаются.
@export_range(0.0, 1.0, 0.001) var shaft_uv_x := 0.481
@export_range(0.0, 1.0, 0.001) var tip_uv_y := 0.006
@export_range(0.0, 1.0, 0.001) var base_uv_y := 0.807

@export_group("Игла без картинки")
## Верх иглы и её основание — в долях высоты панели.
@export_range(0.0, 1.0, 0.01) var needle_top_frac := 0.02
@export_range(0.0, 1.0, 0.01) var needle_base_frac := 0.82
@export var needle_width := 7.0
@export var needle_color := Color(0.45, 0.28, 0.15)
@export var base_size := Vector2(190.0, 30.0)
@export var base_color := Color(0.07, 0.07, 0.08)
@export var base_top_color := Color(0.55, 0.55, 0.57)
@export var base_texture: Texture2D

@export_group("Листок")
## Размер холста листка, px. Держи пропорции картинок листков (1125×497),
## иначе рисунок сплющится.
@export var sheet_size := Vector2(300.0, 133.0)
## Где игла протыкает холст листка, в долях холста.
@export var pierce_uv := Vector2(0.494, 0.4)
## Листки стопки по порядку накалывания: 1-й уровень — первый в списке.
## Когда список кончился, он идёт с начала.
@export var sheets: Array[SheetArt] = []
## Листок за пройденный магазин — всегда он, на каком бы месте магазин
## ни попался.
@export var shop_sheet: SheetArt

@export_group("Листок без картинки")
@export var paper_color := Color(0.97, 0.97, 0.95)
@export var paper_border := Color(0.15, 0.14, 0.16)
@export var border_width := 2.0
## Дырка от иглы на листке.
@export var hole_color := Color(0.24, 0.16, 0.09)
@export var hole_radius := 4.0
@export var shadow_color := Color(0.0, 0.0, 0.0, 0.22)
@export var shadow_offset := Vector2(6.0, 8.0)

@export_group("Подпись на листке")
## Нужна только листку-заглушке: у нарисованных листков номер напечатан.
@export var letter_color := Color(0.16, 0.14, 0.16)
@export var letter_font_size := 30
@export var number_color := Color(0.95, 0.6, 0.1)
@export var number_font_size := 20
@export var font: Font

@export_group("Падение вниз")
## Первый шаг: листок пройденного уровня падает вниз и уходит за экран.
@export var fall_gravity := 1500.0
@export var fall_side_speed := 70.0
@export var fall_start_speed := 40.0
@export var fall_spin := 2.6

@export_group("Падение на иглу")
## Листок падает на иглу сверху и строго ровно: он появляется прямо над
## острием, на одной оси с ним, и не качается — как будто его насаживают
## руками.
## На сколько выше своего места в стопке листок появляется, px.
@export var drop_height := 340.0
## Не ниже, чем на столько выше острия иглы, — иначе листок появился бы
## уже наколотым, px.
@export var drop_above_tip := 40.0
## Начальная скорость падения и разгон, px/с и px/с².
@export var drop_start_speed := 90.0
@export var drop_gravity := 900.0
## Пауза перед падением — чтобы листок точки успел упасть в графе, с.
@export var spawn_delay := 0.45

@export_group("Спуск по игле")
## Скорость в момент накалывания (если падение разогналось меньше)
## и разгон вниз по игле.
@export var slide_start_speed := 210.0
@export var slide_gravity := 700.0
## Как быстро листок доворачивается до наклона своего места.
@export var settle_speed := 7.0

@export_group("Места в стопке")
## Куда садится каждый по счёту листок ([SpikeSlot]) — ручная раскладка.
## Пусто (обычный случай) — места считаются шагом, чтобы вся стопка
## уместилась на игле.
@export var slots: Array[SpikeSlot] = []
## Шаг стопки, px. 0 — считать так, чтобы все листки маршрута уместились
## между подставкой и острием.
@export var fallback_step := 0.0
## Больше этого шаг не растёт: на коротком маршруте стопка не должна
## расползаться по всей игле.
@export var step_max := 46.0
## На сколько первый листок поднят над подставкой, px.
@export var stack_bottom_margin := 10.0
## Сколько пустой иглы остаётся над стопкой, px, — острие должно быть видно.
@export var stack_top_margin := 24.0
## Наклон мест, посчитанных шагом: у нарисованных листков он свой, поэтому
## по умолчанию 0.
@export var fallback_tilt := 0.0
@export var fallback_scale := 1.0


## Место index-го по счёту листка в стопке (с 0). `capacity` — сколько
## листков вообще может собраться за забег, `shaft` — свободная длина
## иглы, px: по ним считается шаг, если ручной раскладки нет.
func slot_for(index: int, capacity := 0, shaft := 0.0) -> SpikeSlot:
	if index < 0:
		index = 0
	if index < slots.size() and slots[index] != null:
		return slots[index]
	var slot := SpikeSlot.new()
	var step := stack_step(capacity, shaft)
	var last_height := stack_bottom_margin
	var extra := index
	if not slots.is_empty():
		var last: SpikeSlot = slots[slots.size() - 1]
		if last != null:
			last_height = last.height
		extra = index - slots.size() + 1
	slot.height = last_height + step * extra
	slot.tilt_degrees = fallback_tilt if index % 2 == 0 else -fallback_tilt
	slot.scale = fallback_scale
	return slot


## Шаг стопки: столько, чтобы `capacity` листков уместились на свободной
## части иглы длиной `shaft`. Заданный вручную [member fallback_step]
## всегда главнее.
func stack_step(capacity := 0, shaft := 0.0) -> float:
	if fallback_step > 0.0:
		return fallback_step
	var places: int = maxi(capacity - 1, 1)
	var room := shaft - stack_bottom_margin - stack_top_margin
	if room <= 0.0:
		return step_max
	return minf(room / float(places), step_max)


## Листок `index`-го по счёту пройденного уровня; `is_shop` — это был
## магазин, тогда листок всегда один и тот же.
func sheet_art(index: int, is_shop := false) -> SheetArt:
	if is_shop and shop_sheet != null:
		return shop_sheet
	if sheets.is_empty():
		return null
	return sheets[maxi(index, 0) % sheets.size()]
