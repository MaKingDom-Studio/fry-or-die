@tool
## Один шаг последовательного появления ([RevealSequence]).
##
## Узлы из [member targets] появляются вместе, одним шагом: перед шагом
## выдерживается пауза [member delay], затем они плавно проявляются за
## [member fade] секунд. Всё настраивается в редакторе — узлы
## перетаскиваются в список, порядок шагов задаётся порядком дочерних
## узлов последовательности.
class_name RevealStep
extends Node

## Что появляется на этом шаге (несколько узлов — появятся вместе).
@export var targets: Array[Node2D] = []:
	set(value):
		targets = value
		update_configuration_warnings()

## Пауза перед этим шагом, с.
@export var delay := 0.45:
	set(value):
		delay = maxf(value, 0.0)

## Длительность проявления, с.
@export var fade := 0.5:
	set(value):
		fade = maxf(value, 0.0)


func _get_configuration_warnings() -> PackedStringArray:
	for target in targets:
		if target == null:
			return PackedStringArray(["В списке появления есть пустая ячейка."])
	if targets.is_empty():
		return PackedStringArray(["Шаг ничего не показывает: список узлов пуст."])
	return PackedStringArray()


## Спрятать узлы шага, записав их исходную прозрачность в общий на всю
## последовательность словарь (узел -> прозрачность). Словарь общий, чтобы
## узел, попавший сразу в несколько шагов, не запомнил уже обнулённое
## значение.
func hide_targets(alphas: Dictionary) -> void:
	for target in targets:
		if target == null:
			continue
		if not alphas.has(target):
			alphas[target] = target.modulate.a
		target.visible = false
		target.modulate.a = 0.0


## Плавно проявить узлы шага до их исходной прозрачности.
func reveal(alphas: Dictionary) -> void:
	for target in targets:
		if target == null:
			continue
		var alpha: float = alphas.get(target, 1.0)
		target.visible = true
		if fade <= 0.0:
			target.modulate.a = alpha
			continue
		var tween := target.create_tween()
		tween.tween_property(target, "modulate:a", alpha, fade) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## Показать узлы шага сразу, без анимации (последовательность выключена).
func reveal_now(alphas: Dictionary) -> void:
	for target in targets:
		if target == null:
			continue
		target.visible = true
		target.modulate.a = alphas.get(target, 1.0)
