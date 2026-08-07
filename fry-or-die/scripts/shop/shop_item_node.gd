## Физический товар на витрине магазина: ингредиент или специя.
##
## Лежит замороженным в своём слоте ([ShopSlot]), ужатый так, чтобы
## поместиться в его площадку; коллизия — по непрозрачным пикселям PNG
## (общие кэши силуэтов [IngredientNode] и [SpiceNode], приведённые к
## размеру товара на витрине), за силуэт товар берут мышью. Когда игрок
## берёт товар, его коллизия отключается ([method set_carried]) и узел
## следует за курсором (двигает режим магазина); отпущенный мимо
## холодильника товар возвращается в свой слот ([method return_home]),
## купленный — улетает внутрь холодильника и исчезает
## ([method consume_into]).
class_name ShopItemNode
extends RigidBody2D

## Физический слой товаров магазина — отдельный от стола (1), корзин (2),
## секций мешка (3+) и специй (10–11).
const SHOP_ITEM_LAYER := 1 << 12

signal consumed

var entry: ShopEntry
## Тень под товаром — тем же цветом, что у ингредиентов боя.
var shadow_color := Color(0.02, 0.02, 0.04, 0.45)

## Тень «выезжает» из-под товара: у лежащего видна только тонкая бледная
## полоска, у взятого в руку тень отъезжает дальше, вырастает и темнеет —
## товар как будто поднят над полкой. Переход плавный в обе стороны
## (см. [member shadow_speed]), параметры задаёт [ShopConfig].
var shadow_rest_offset := 1.5
var shadow_rest_alpha := 0.45
var shadow_lift_offset := 15.0
var shadow_lift_scale := 1.18
var shadow_lift_alpha := 0.75
var shadow_speed := 6.0

## Точка слота, куда товар возвращается, если его отпустили.
var home_position := Vector2.ZERO
var carried := false
## Хватает ли звёзд на товар в руке: обводка жёлтая или красная
## (обновляет режим магазина).
var affordable := true

var _tex_box := Rect2()
var _outline_polys := []
## Выпуклые части силуэта под коллизию (уже в размере товара на витрине).
var _convex_parts := []
var _texture: Texture2D = null
var _fallback_radius := 20.0
var _fallback_is_circle := true
var _fallback_color := Color.WHITE
var _collisions: Array[CollisionShape2D] = []
var _tween: Tween = null
## Насколько тень «выехала»: 0 — товар лежит, 1 — товар в руке.
var _shadow_t := 0.0


## Собрать товар для витрины. fit_size — во что он должен вписаться
## (площадка слота); Vector2.ZERO — оставить натуральный размер.
## max_scale ограничивает увеличение мелких товаров.
static func create(shop_entry: ShopEntry, shadow: Color,
		fit_size := Vector2.ZERO, max_scale := 1.0) -> ShopItemNode:
	var node := ShopItemNode.new()
	node.entry = shop_entry
	node.shadow_color = shadow
	if shop_entry.ingredient != null:
		node._read_ingredient(shop_entry.ingredient)
	elif shop_entry.spice != null:
		node._read_spice(shop_entry.spice)
	node._fit_into(fit_size, max_scale)
	node._build_collisions()
	node.freeze = true
	node.gravity_scale = 0.0
	node.collision_layer = SHOP_ITEM_LAYER
	node.collision_mask = 0
	return node


## Размер товара на витрине — по нему слот решает, куда его положить.
func box_size() -> Vector2:
	return _tex_box.size


## Что показать в подсказке при наведении ([HoverTooltip]): ингредиент или
## специю этого товара.
func tooltip_model() -> Resource:
	if entry == null:
		return null
	return entry.ingredient if entry.ingredient != null else entry.spice


## Параметры «выезжающей» тени — из конфига магазина.
func set_shadow_params(config: ShopConfig) -> void:
	shadow_rest_offset = config.shadow_rest_offset
	shadow_rest_alpha = config.shadow_rest_alpha
	shadow_lift_offset = config.shadow_lift_offset
	shadow_lift_scale = config.shadow_lift_scale
	shadow_lift_alpha = config.shadow_lift_alpha
	shadow_speed = config.shadow_speed


## Тень догоняет своё состояние: взяли товар — постепенно растёт и
## отъезжает, отпустили — так же плавно возвращается под товар.
func _process(delta: float) -> void:
	var target := 1.0 if carried else 0.0
	if _shadow_t == target:
		return
	if is_equal_approx(_shadow_t, target):
		# Хвост снимаем сразу: иначе тень замирает, чуть-чуть не доехав
		# до края, и состояние никогда не становится ровным.
		_shadow_t = target
		queue_redraw()
		return
	_shadow_t = move_toward(_shadow_t, target, maxf(shadow_speed, 0.01) * delta)
	queue_redraw()


func _read_ingredient(model: IngredientModel) -> void:
	_texture = model.texture
	_fallback_radius = model.radius
	_fallback_is_circle = model.shape == IngredientModel.ShapeKind.CIRCLE
	_fallback_color = model.color
	_tex_box = _box_for(model.texture, model.radius)
	if model.texture != null and model.texture_collision:
		var silhouette := IngredientNode.silhouette_for(model)
		_outline_polys = silhouette["outlines"]
		_convex_parts = silhouette["convex"]


func _read_spice(model: SpiceModel) -> void:
	_texture = model.texture
	_fallback_radius = SpiceNode.effective_radius(model)
	_fallback_is_circle = true
	_fallback_color = model.color
	_tex_box = SpiceNode.texture_box(model)
	if model.texture != null:
		var silhouette := SpiceNode.silhouette_for(model)
		_outline_polys = silhouette["outlines"]
		_convex_parts = silhouette["convex"]


## Ужать товар под площадку слота: масштабируются и бокс отрисовки, и
## силуэт под коллизию. Силуэты приходят из общего кэша (его использует
## бой), поэтому точки не правятся на месте, а копируются.
func _fit_into(fit_size: Vector2, max_scale: float) -> void:
	var factor := 1.0
	if fit_size.x > 0.0 and fit_size.y > 0.0 and _tex_box.size.x > 0.0 \
			and _tex_box.size.y > 0.0:
		factor = minf(fit_size.x / _tex_box.size.x, fit_size.y / _tex_box.size.y)
		factor = minf(factor, maxf(max_scale, 0.01))
	if is_equal_approx(factor, 1.0):
		return
	_tex_box = Rect2(_tex_box.position * factor, _tex_box.size * factor)
	_fallback_radius *= factor
	_outline_polys = _scaled_polygons(_outline_polys, factor)
	_convex_parts = _scaled_polygons(_convex_parts, factor)


static func _scaled_polygons(polygons: Array, factor: float) -> Array:
	var result := []
	for points in polygons:
		var scaled := PackedVector2Array()
		for point in points:
			scaled.append(point * factor)
		result.append(scaled)
	return result


func _build_collisions() -> void:
	for points in _convex_parts:
		if (points as PackedVector2Array).size() < 3:
			continue
		var shape := ConvexPolygonShape2D.new()
		shape.points = points
		var collision := CollisionShape2D.new()
		collision.shape = shape
		add_child(collision)
		_collisions.append(collision)
	if not _collisions.is_empty():
		return
	var collision := CollisionShape2D.new()
	if _fallback_is_circle:
		var circle := CircleShape2D.new()
		circle.radius = _fallback_radius
		collision.shape = circle
	else:
		var rect := RectangleShape2D.new()
		rect.size = Vector2.ONE * _fallback_radius * 2.0
		collision.shape = rect
	add_child(collision)
	_collisions.append(collision)


## Можно ли взять товар: не продан, не в руке и не летит.
func can_be_grabbed() -> bool:
	return entry != null and entry.is_stocked() and not carried and _tween == null


## Взять/отпустить товар. У взятого товара коллизия отключается — он не
## расталкивает соседей по витрине; узел поднимается над ней.
func set_carried(value: bool) -> void:
	carried = value
	_set_collisions_disabled(value)
	z_index = 80 if value else 0
	queue_redraw()


## Вернуться в свой слот (отпустили мимо холодильника): плавный перелёт
## назад, по прилёте коллизия включается.
func return_home(duration: float) -> void:
	set_carried(false)
	_set_collisions_disabled(true)
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(self, "global_position", home_position,
			maxf(duration, 0.01)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(func() -> void:
		_set_collisions_disabled(false)
		_tween = null)


## Купленный товар улетает в точку холодильника, сжимаясь, и исчезает.
func consume_into(target: Vector2, duration: float) -> void:
	set_carried(false)
	_set_collisions_disabled(true)
	_kill_tween()
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(self, "global_position", target,
			maxf(duration, 0.01)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_tween.tween_property(self, "scale", Vector2.ONE * 0.1, maxf(duration, 0.01))
	_tween.set_parallel(false)
	_tween.tween_callback(func() -> void:
		consumed.emit()
		queue_free())


func _kill_tween() -> void:
	if _tween != null:
		_tween.kill()
		_tween = null


func _set_collisions_disabled(value: bool) -> void:
	for collision in _collisions:
		collision.disabled = value


func _draw() -> void:
	# Тень-силуэт «выезжает» из-под товара: у лежащего сдвиг минимальный,
	# у поднятого тень отъезжает дальше, вырастает и бледнеет. Смещение
	# считается в экранных координатах — поворот тела компенсируется.
	var shift := lerpf(shadow_rest_offset, shadow_lift_offset, _shadow_t)
	var shadow_scale := lerpf(1.0, shadow_lift_scale, _shadow_t)
	var shadow_offset := Vector2(0.0, shift).rotated(-rotation)
	var tint := Color(shadow_color,
			shadow_color.a * lerpf(shadow_rest_alpha, shadow_lift_alpha, _shadow_t))
	draw_set_transform(shadow_offset, 0.0, Vector2.ONE * shadow_scale)
	if _texture != null:
		draw_texture_rect(_texture, _tex_box, false, tint)
	else:
		_draw_fallback_shape(tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if _texture != null:
		draw_texture_rect(_texture, _tex_box, false)
	else:
		_draw_fallback_shape(_fallback_color)
		_draw_fallback_outline(Color(0.1, 0.1, 0.12), 2.0)
	if carried:
		var outline := Color(1.0, 0.83, 0.25, 0.95) if affordable \
				else Color(0.9, 0.3, 0.25, 0.95)
		_draw_grab_outline(outline, 3.0)


func _draw_fallback_shape(color: Color) -> void:
	if _fallback_is_circle:
		draw_circle(Vector2.ZERO, _fallback_radius, color)
	else:
		draw_rect(Rect2(-_fallback_radius, -_fallback_radius,
				_fallback_radius * 2.0, _fallback_radius * 2.0), color)


func _draw_fallback_outline(color: Color, width: float) -> void:
	if _fallback_is_circle:
		draw_arc(Vector2.ZERO, _fallback_radius, 0.0, TAU, 32, color, width)
	else:
		draw_rect(Rect2(-_fallback_radius, -_fallback_radius,
				_fallback_radius * 2.0, _fallback_radius * 2.0), color, false, width)


## Обводка взятого товара — по контуру силуэта PNG (там же, где коллизия);
## без изображения — по фигуре.
func _draw_grab_outline(color: Color, width: float) -> void:
	if _outline_polys.is_empty():
		_draw_fallback_outline(color, width)
		return
	for outline in _outline_polys:
		var points := outline as PackedVector2Array
		if points.size() < 3:
			continue
		var closed := points.duplicate()
		closed.append(closed[0])
		draw_polyline(closed, color, width)


## Бокс отрисовки: пропорции PNG сохранены, длинная сторона = 2r.
static func _box_for(texture: Texture2D, radius: float) -> Rect2:
	var box := Rect2(-radius, -radius, radius * 2.0, radius * 2.0)
	if texture == null:
		return box
	var tex_size := texture.get_size()
	var longest := maxf(tex_size.x, tex_size.y)
	if longest <= 0.0:
		return box
	var size := tex_size * (radius * 2.0 / longest)
	return Rect2(-size * 0.5, size)
