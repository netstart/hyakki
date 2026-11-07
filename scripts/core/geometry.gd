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


## Fração t em [0, 1] do segmento a→b em que ele entra no círculo (`center`, `r`), ou -1 se não
## entra. Quem já começa dentro não conta (sai livre).
static func segment_enters_circle(a: Vector2, b: Vector2, center: Vector2, r: float) -> float:
	var d := b - a
	var f := a - center
	var c := f.length_squared() - r * r
	var bb := f.dot(d)
	if c < 0.0 or bb >= 0.0:
		return -1.0
	var aa := d.length_squared()
	var disc := bb * bb - aa * c
	if disc < 0.0:
		return -1.0
	var t := (-bb - sqrt(disc)) / aa
	return t if t <= 1.0 else -1.0
