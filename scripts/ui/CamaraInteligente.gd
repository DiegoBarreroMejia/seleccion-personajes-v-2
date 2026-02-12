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

	# Cálculo de distancia para el zoom dinámico
	var distancia := j1.global_position.distance_to(j2.global_position)
	var factor_zoom := clampf(1000.0 / (distancia + margen), zoom_minimo, zoom_maximo)

	# Si hay límites configurados, asegurar que el zoom no muestre fuera del mapa
	var tiene_limites := limit_left > -10000000 or limit_right < 10000000
	if tiene_limites:
		var viewport_size := get_viewport_rect().size
		var ancho_mapa := float(limit_right - limit_left)
		var alto_mapa := float(limit_bottom - limit_top)

		# Zoom mínimo para que la cámara quepa dentro del mapa
		var zoom_min_x := viewport_size.x / ancho_mapa
		var zoom_min_y := viewport_size.y / alto_mapa
		var zoom_minimo_real := maxf(zoom_min_x, zoom_min_y)

		# No permitir que el zoom sea menor que lo que cabe en el mapa
		factor_zoom = maxf(factor_zoom, zoom_minimo_real)

		# Aplicar zoom
		zoom = Vector2(factor_zoom, factor_zoom)

		# Ahora clampear la posición
		var medio_ancho := (viewport_size.x / 2.0) / factor_zoom
		var medio_alto := (viewport_size.y / 2.0) / factor_zoom

		punto_medio.x = clampf(punto_medio.x, limit_left + medio_ancho, limit_right - medio_ancho)
		punto_medio.y = clampf(punto_medio.y, limit_top + medio_alto, limit_bottom - medio_alto)
	else:
		zoom = Vector2(factor_zoom, factor_zoom)

	global_position = punto_medio
