## Пер-бойное состояние игрока. Пересоздаётся на каждый бой
## через [method Player.start_combat].
##
## Жизненный цикл раунда:
## 1. [method start_round] — содержимое корзины «выпадает» и возвращается
##    вызывающему, чтобы раскидать по [DropZone]; когда высыпание долетело
##    до стола, вызывающий наполняет корзину заново из мешочка через
##    [method refill_basket] — это предпросмотр следующего хода;
## 2. [method get_selectable_tools] / [method select_tool] — выбор инструмента
##    идёт по накрытому столу, поэтому он уже после высыпания (null — играть
##    без инструмента). Выбор можно менять сколько угодно; когда игрок его
##    подтвердил, вызывающий зовёт [method apply_selected_tool] — только тогда
##    инструмент вступает в силу;
## 3. ...игрок и враги действуют...
## 4. [method end_round] — активный инструмент уходит в кулдаун (по конфигу),
##    кулдауны остальных тикают, номер раунда растёт.
class_name PlayerRoundState
extends RefCounted

signal round_started(round_number: int)
signal round_ended(round_number: int)
signal active_tool_changed(old_tool: ToolState, new_tool: ToolState)

var player: Player
var config: GameConfig

## Мешочек со всеми ингредиентами игрока (заменяет стопки добора и сброса).
var bag: IngredientBag

## Корзина: ингредиенты, которые выпадут на следующий ход.
var basket: Basket

## Номер текущего раунда. Начинается с 1.
var round_number: int = 1

var _active_tool: ToolState = null

## Инструмент, выбранный на текущий раунд; null — раунд без инструмента.
var active_tool: ToolState:
	get:
		return _active_tool

func _init(owning_player: Player, game_config: GameConfig, rng: RandomNumberGenerator = null) -> void:
	player = owning_player
	config = game_config
	bag = IngredientBag.new(rng)
	bag.fill_from(player.ingredients)
	basket = Basket.new()
	basket.refill(bag, get_basket_size())

## Инструменты, доступные для выбора в этом раунде (не на кулдауне).
func get_selectable_tools() -> Array[ToolState]:
	return player.get_ready_tools()

## Выбрать инструмент на раунд. null — играть без инструмента.
## Инструмент должен принадлежать игроку и не быть на кулдауне.
func select_tool(tool_state: ToolState) -> void:
	if tool_state != null:
		if not player.tools.has(tool_state):
			push_error("Нельзя выбрать инструмент, которого нет у игрока.")
			return
		if not tool_state.is_ready():
			push_error("Инструмент '%s' на кулдауне ещё %d раунд(а)." % [
					tool_state.model.display_name, tool_state.cooldown_remaining])
			return
	if _active_tool == tool_state:
		return
	var old := _active_tool
	_active_tool = tool_state
	active_tool_changed.emit(old, _active_tool)

## Начать раунд. Возвращает ингредиенты, которые выпадают в этом раунде, —
## вызывающий (режим боя) раскидывает их по зоне высыпания. Корзина при
## этом пустеет; заново её наполняет [method refill_basket] — режим боя
## вызывает его после перелёта высыпания на стол.
func start_round() -> Array[IngredientModel]:
	for spice in player.spices:
		spice.on_round_start(player)
	var dropped := basket.take_all()
	round_started.emit(round_number)
	return dropped


## Выбор инструмента подтверждён: он вступает в силу на этот раунд. Вызывается
## один раз за раунд, уже после высыпания — до этого выбор можно менять
## сколько угодно, и хук [method ToolModel.on_round_start] не срабатывает.
func apply_selected_tool() -> void:
	if _active_tool != null:
		_active_tool.model.on_round_start(player)


## Наполнить корзину из мешочка — предпросмотр следующего хода.
func refill_basket() -> void:
	basket.refill(bag, get_basket_size())

## Завершить раунд: активный инструмент уходит в кулдаун и сбрасывается,
## кулдауны остальных инструментов уменьшаются на 1.
func end_round() -> void:
	for spice in player.spices:
		spice.on_round_end(player)
	for tool_state in player.tools:
		if tool_state != _active_tool:
			tool_state.tick_cooldown()
	if _active_tool != null:
		_active_tool.model.on_round_end(player)
		_active_tool.put_on_cooldown(config)
		select_tool(null)
	round_ended.emit(round_number)
	round_number += 1

## Размер корзины с учётом хуков специй и активного инструмента. Корзина
## наполняется сразу после высыпания, то есть до выбора инструмента, поэтому
## инструмент меняет размер той корзины, что наполнится в следующем раунде.
func get_basket_size() -> int:
	var size := config.basket_size
	for spice in player.spices:
		size = spice.modify_basket_size(player, size)
	if _active_tool != null:
		size = _active_tool.model.modify_basket_size(player, size)
	return maxi(size, 0)

## Вызывается из [method Player.end_combat] при завершении боя.
func end_combat() -> void:
	select_tool(null)
	basket.clear()
	if config.reset_tool_cooldowns_after_combat:
		for tool_state in player.tools:
			tool_state.reset_cooldown()
