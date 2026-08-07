## Экземпляр инструмента в инвентаре игрока: модель + текущий кулдаун.
##
## Кулдаун N означает, что инструмент пропустит N раундов:
## он уходит в кулдаун в конце раунда, где был активен
## ([method PlayerRoundState.end_round]), и тикает в конце каждого последующего.
class_name ToolState
extends RefCounted

signal cooldown_changed(old_value: int, new_value: int)

var model: ToolModel

var _cooldown_remaining: int = 0

## Сколько раундов инструмент ещё будет недоступен.
var cooldown_remaining: int:
	get:
		return _cooldown_remaining

func _init(tool_model: ToolModel) -> void:
	model = tool_model

## Готов ли инструмент к выбору перед раундом.
func is_ready() -> bool:
	return _cooldown_remaining <= 0

## Отправить инструмент в кулдаун после использования (длительность — по конфигу).
func put_on_cooldown(config: GameConfig) -> void:
	var cooldown := model.get_cooldown(config)
	if cooldown > 0:
		_set_cooldown(cooldown)

## Уменьшить кулдаун на один раунд.
func tick_cooldown() -> void:
	if _cooldown_remaining > 0:
		_set_cooldown(_cooldown_remaining - 1)

## Полностью снять кулдаун (например, при окончании боя).
func reset_cooldown() -> void:
	_set_cooldown(0)

func _set_cooldown(value: int) -> void:
	if _cooldown_remaining == value:
		return
	var old := _cooldown_remaining
	_cooldown_remaining = value
	cooldown_changed.emit(old, _cooldown_remaining)
