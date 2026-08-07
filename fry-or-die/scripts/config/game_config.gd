## Глобальные настройки раундов и инструментов.
##
## Создайте .tres-ресурс на основе этого класса, чтобы крутить баланс
## без изменения кода, и передайте его в [method Player.create_for_new_run].
class_name GameConfig
extends Resource

## Могут ли инструменты вообще уходить в кулдаун.
## false — инструменты доступны для выбора каждый раунд.
@export var tool_cooldown_enabled: bool = true

## Кулдаун инструмента (в раундах) по умолчанию.
## Применяется к инструментам, у которых [member ToolModel.cooldown_rounds] = -1.
@export var default_tool_cooldown: int = 1

## Сбрасывать ли кулдауны всех инструментов после окончания боя.
@export var reset_tool_cooldowns_after_combat: bool = true

## Сколько ингредиентов набирается в корзину (то, что выпадет на следующий ход).
@export var basket_size: int = 5
