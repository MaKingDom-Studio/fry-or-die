## Общая математика лёгкого покачивания: медленный наклон и вертикальное
## колыхание. Используется вывеской ([SwayingSign]) и качающимися
## спрайтами ([SwayingSprite]) — каждый узел качается сам по себе, со
## своей фазой, поэтому соседние объекты не двигаются синхронно.
class_name SwayMotion
extends RefCounted


## Наклон, рад: медленное качание в пределах ±degrees с периодом period.
static func tilt(time: float, phase: float, degrees: float, period: float) -> float:
	if degrees <= 0.0:
		return 0.0
	return deg_to_rad(degrees) * sin(TAU * time / maxf(period, 0.05) + phase)


## Вертикальное колыхание, px: ±pixels с периодом period. Фаза берётся
## слегка сдвинутой относительно наклона — движение выглядит живым, а не
## строго синхронным с качанием.
static func bob(time: float, phase: float, pixels: float, period: float) -> float:
	if pixels <= 0.0:
		return 0.0
	return pixels * sin(TAU * time / maxf(period, 0.05) + phase * 0.7)
