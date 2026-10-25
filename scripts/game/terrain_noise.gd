class_name TerrainNoise
extends RefCounted
## Ruído de valor do chão, idêntico ao de shaders/terrain_ground.gdshader (mesmo hash sem seno,
## mesma interpolação, 2 oitavas). Assim a CPU sabe onde o shader pinta grama alta, terra ou
## calçamento e põe tufos e flores no lugar certo. Só visual: nada aqui afeta a simulação.

const OCTAVES := 2


## Hash de um ponto da grade em [0, 1) (Dave Hoskins, "hash without sine").
static func hash2(x: float, y: float) -> float:
	var ax := _fract(x * 0.1031)
	var ay := _fract(y * 0.1031)
	var az := ax
	var d := ax * (ay + 33.33) + ay * (az + 33.33) + az * (ax + 33.33)
	ax += d
	ay += d
	az += d
	return _fract((ax + ay) * az)


static func value(x: float, y: float) -> float:
	var ix := floorf(x)
	var iy := floorf(y)
	var fx := x - ix
	var fy := y - iy
	var ux := fx * fx * (3.0 - 2.0 * fx)
	var uy := fy * fy * (3.0 - 2.0 * fy)
	var a := hash2(ix, iy)
	var b := hash2(ix + 1.0, iy)
	var c := hash2(ix, iy + 1.0)
	var d := hash2(ix + 1.0, iy + 1.0)
	return lerpf(lerpf(a, b, ux), lerpf(c, d, ux), uy)


## fbm de 2 oitavas normalizado para [0, 1].
static func fbm(x: float, y: float) -> float:
	return (value(x, y) * 0.5 + value(x * 2.03 + 17.3, y * 2.03 + 9.1) * 0.25) / 0.75


## Os dois campos do chão (n1, n2) num ponto do mundo.
static func fields(p: Vector2, scales: Vector2, offset: Vector2) -> Vector2:
	return Vector2(fbm(p.x * scales.x + offset.x, p.y * scales.x + offset.y),
			fbm(p.x * scales.y + offset.y + 17.0, p.y * scales.y + offset.x + 17.0))


## Deslocamento do ruído a partir da semente (o mesmo que o shader recebe).
static func offset_for(seed_value: int) -> Vector2:
	var h := absi(hash([seed_value, "terrain"]))
	return Vector2(float(h % 997) + 0.37, float((h / 997) % 991) + 0.71)


static func _fract(v: float) -> float:
	return v - floorf(v)
