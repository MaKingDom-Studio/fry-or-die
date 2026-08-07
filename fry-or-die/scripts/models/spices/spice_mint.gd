## Мята: не сильно притягивает к полю игрока все полезные ингредиенты —
## всё, у чего множитель больше 0 (и нейтральные, и положительные).
##
## Вся настройка притяжения — здесь, в ресурсе специи
## (_Game/Data/Combat/Spices/da_spice_mint.tres): сила, кого тянет, до какой
## скорости разгоняет, отпускать ли долетевшее и работать ли только в раунде.
## Само притяжение раздаёт режим боя (gm_combat._process_spice_attraction).
class_name SpiceMint
extends SpiceModel

@export_group("Притяжение")
## Ускорение притяжения, px/s^2. Небольшое — ингредиенты лишь слегка дрейфуют.
@export var attraction := 3.0

## Кого тянет: ингредиенты с множителем больше этого числа. 0 — всё полезное
## (и нейтральные, и положительные); 1 — только положительные; меньше 0 —
## мята потянет к игроку и вредное.
@export var min_multiplier := 0.0

## Предел скорости дрейфа, px/s: быстрее этого мята ингредиент не разгоняет,
## дальше он катится сам. 0 — без предела, тянет всё время, пока не долетел.
@export var max_drift_speed := 0.0

## Отпускать ингредиент, как только он оказался на поле игрока. Выключено —
## мята продолжает сгонять всё к середине поля.
@export var stops_on_player_field := true

## Тянуть только в раунде (таймер пошёл, стол можно трогать). Выключено —
## мята тянет и пока всё высыпается, и на подсчёте, то есть растаскивает
## стол ещё до «Обратного отсчёта».
@export var only_during_round := true


func get_useful_attraction() -> float:
	return attraction


func get_attraction_min_multiplier() -> float:
	return min_multiplier


func get_attraction_max_speed() -> float:
	return max_drift_speed


func get_attraction_stops_on_field() -> bool:
	return stops_on_player_field


func get_attraction_only_in_round() -> bool:
	return only_during_round
