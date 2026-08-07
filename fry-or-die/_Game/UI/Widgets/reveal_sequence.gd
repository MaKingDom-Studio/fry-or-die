@tool
## Последовательное появление узлов сцены: в начале их не видно, дальше
## они проявляются один за другим.
##
## Шаги — дочерние узлы [RevealStep] в порядке появления; в каждом шаге
## свой список узлов (несколько в одном шаге появятся вместе), своя пауза
## перед ним и своя длительность проявления. Всё настраивается в
## редакторе: чтобы поменять порядок, достаточно переставить дочерние
## узлы местами.
##
## Узлы прячутся сразу при загрузке сцены (до первого кадра), поэтому
## вспышки «показались и исчезли» не бывает.
class_name RevealSequence
extends Node

## Выключить последовательность: всё показывается сразу (удобно при
## настройке сцены, чтобы не ждать анимацию).
@export var enabled := true

## Пауза перед самым первым шагом, с.
@export var start_delay := 0.3:
	set(value):
		start_delay = maxf(value, 0.0)


func _get_configuration_warnings() -> PackedStringArray:
	if _steps().is_empty():
		return PackedStringArray([
				"Нет шагов: добавьте дочерние узлы со скриптом RevealStep."])
	return PackedStringArray()


## Исходная прозрачность каждого узла (узел -> alpha): к ней шаг и
## проявляет. Общая на всю последовательность, чтобы узел, попавший
## в несколько шагов, не «запомнил» уже спрятанное состояние.
var _alphas := {}


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var steps := _steps()
	for step in steps:
		step.hide_targets(_alphas)
	if not enabled:
		for step in steps:
			step.reveal_now(_alphas)
		return
	_play(steps)


func _play(steps: Array[RevealStep]) -> void:
	if start_delay > 0.0:
		await get_tree().create_timer(start_delay).timeout
	for step in steps:
		if step.delay > 0.0:
			await get_tree().create_timer(step.delay).timeout
		step.reveal(_alphas)


## Шаги в порядке следования дочерних узлов.
func _steps() -> Array[RevealStep]:
	var steps: Array[RevealStep] = []
	for child in get_children():
		var step := child as RevealStep
		if step != null:
			steps.append(step)
	return steps
