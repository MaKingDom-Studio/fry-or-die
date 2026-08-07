## Одна группа выкладки внутри хода врага ([EnemyMove]).
##
## Группа — это либо N копий конкретного ингредиента, либо случайный набор
## из инвентаря врага заданной ценности ([member random_points]), либо
## случайные ингредиенты с эффектом ([member random_effect_count]). У каждой
## группы свой участок стола ([member placement]), поэтому один и тот же
## ингредиент в разных ходах может падать врагу, игроку или в центр —
## размещение больше не зашито в самом ингредиенте.
class_name EnemySpawnGroup
extends Resource

## Куда падает содержимое группы.
enum Placement {
	## На половину врага (по умолчанию).
	ENEMY,
	## На половину игрока (вредит игроку при подсчёте).
	PLAYER,
	## В центральную зону высыпания — очков не приносит никому, мешает.
	CENTER,
}

## Ингредиент группы. Игнорируется, если задан [member random_points]
## или [member random_effect_count].
@export var ingredient: IngredientModel
## Сколько копий [member ingredient] заспавнить.
@export var count := 1
## Участок стола, куда падает вся группа.
@export var placement: Placement = Placement.ENEMY

@export_group("Случайный набор")
## Если больше 0 — вместо [member ingredient] спавнится случайный набор
## из [member EnemyModel.inventory] суммарной ценностью примерно на столько
## очков (по [method IngredientModel.base_points]). Набираются только
## ингредиенты с положительной ценностью.
@export var random_points := 0
## Разброс цели набора: ценность роллится в диапазоне
## [member random_points] ± столько очков. 0 — цель ровно [member random_points].
@export var random_points_variance := 0

@export_group("Случайный эффект")
## Если больше 0 — вместо [member ingredient] спавнится столько случайных
## ингредиентов с эффектом ([member IngredientModel.effect]). Берутся они из
## [member EnemyModel.effect_pool], а если он пуст — из ингредиентов
## с эффектом в [member EnemyModel.inventory]. Проверяется раньше
## [member random_points]: группа со случайным эффектом — только эффекты.
@export var random_effect_count := 0

@export_group("Случайный мусор")
## Если больше 0 — вместо [member ingredient] спавнится столько случайных
## **вредных** ингредиентов (множитель меньше 0). Берутся они из
## [member EnemyModel.bad_pool], а если он пуст — из вредных ингредиентов
## в [member EnemyModel.inventory]. Штуки роллятся с повторами.
## Проверяется раньше [member random_effect_count] и [member random_points].
@export var random_bad_count := 0
## Верхняя граница числа штук: если больше [member random_bad_count], число
## роллится в диапазоне [member random_bad_count]…столько (один раз на раунд,
## поэтому предпросмотр корзины совпадает с высыпанием). 0 или меньше
## нижней границы — штук ровно [member random_bad_count].
@export var random_bad_count_max := 0
