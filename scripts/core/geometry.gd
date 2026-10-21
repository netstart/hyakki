class_name Geometry
extends RefCounted
## Testes geométricos puros usados pela física própria (plano 8.7.2).


## Teste contínuo: o segmento a→b passa a menos de `r` do centro?
## Evita que projéteis rápidos atravessem inimigos (tunneling).
static func segment_hits_circle(a: Vector2, b: Vector2, center: Vector2, r: float) -> bool:
	var ab := b - a
	var t := 0.0
	var length2 := ab.length_squared()
	if length2 > 0.0:
		t = clampf((center - a).dot(ab) / length2, 0.0, 1.0)
	return (a + ab * t).distance_squared_to(center) <= r * r
