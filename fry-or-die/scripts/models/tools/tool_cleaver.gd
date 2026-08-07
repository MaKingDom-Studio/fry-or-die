## Тесак игрока: после выбора инструмента лезвие падает ровно на середину
## стола, рубит и увозит накрытое собой на половину игрока.
##
## Зеркало способности минибосса «Barbara» ([CleaverAbility]): удар рисует тот
## же узел [CleaverNode], только лезвие увозит задетое не к врагу, а к игроку.
## От удара так же подпрыгивает всё, чего лезвие не накрыло.
class_name ToolCleaver
extends ToolModel

## Изображение лезвия (вид сверху), сила подскока и дальность сдвига.
## Настраивается в _Game/Data/Combat/Tools/da_tool_cleaver.tres.
@export var ability: CleaverAbility


func get_cleaver_ability() -> CleaverAbility:
	return ability
