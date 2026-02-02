extends Camera2D

## Cámara que sigue a ambos jugadores y ajusta el zoom según la distancia

@export var zoom_minimo: float = 0.5
@export var zoom_maximo: float = 1.5
@export var margen: float = 200.0

var _jugadores: Array = []

func _ready() -> void:
	# Sin smoothing - asignación directa como el código original
	position_smoothing_enabled = false
	_encontrar_jugadores()

func _encontrar_jugadores() -> void:
	await get_tree().process_frame
	_jugadores = get_tree().get_nodes_in_group("jugadores")

func _process(_delta: float) -> void:
	# Limpiar jugadores inválidos
	_jugadores = _jugadores.filter(func(j): return is_instance_valid(j))

	if _jugadores.size() < 2:
		return

	var j1: Node2D = _jugadores[0]
	var j2: Node2D = _jugadores[1]

	# Punto medio exacto entre los dos
	var punto_medio := (j1.global_position + j2.global_position) / 2.0
	global_position = punto_medio

	# Cálculo de distancia para el zoom dinámico
	var distancia := j1.global_position.distance_to(j2.global_position)
	var factor_zoom := clampf(1000.0 / (distancia + margen), zoom_minimo, zoom_maximo)
	zoom = Vector2(factor_zoom, factor_zoom)
