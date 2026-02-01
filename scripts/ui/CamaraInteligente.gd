extends Camera2D

## Cámara que sigue a ambos jugadores y ajusta el zoom según la distancia

@export var margen: float = 200.0
@export var zoom_min: float = 0.5
@export var zoom_max: float = 1.5
@export var suavizado_posicion: float = 2.0
@export var suavizado_zoom: float = 3.0

var _jugadores: Array = []
var _zoom_objetivo: Vector2 = Vector2.ONE

func _ready() -> void:
	# IMPORTANTE: Deshabilitamos el suavizado nativo para evitar conflicto con pixel snapping
	position_smoothing_enabled = false
	
	_encontrar_jugadores()

func _encontrar_jugadores() -> void:
	await get_tree().process_frame
	_jugadores = get_tree().get_nodes_in_group("jugadores")

func _process(delta: float) -> void:
	if _jugadores.is_empty():
		return
	
	# Limpiar jugadores inválidos
	_jugadores = _jugadores.filter(func(j): return is_instance_valid(j))
	
	if _jugadores.is_empty():
		return
	
	# Calcular centro entre jugadores
	var centro := Vector2.ZERO
	var jugadores_validos := 0
	
	for jugador in _jugadores:
		if is_instance_valid(jugador):
			centro += jugador.global_position
			jugadores_validos += 1
	
	if jugadores_validos == 0:
		return
	
	centro /= jugadores_validos
	
	# Calcular distancia para ajustar zoom
	var distancia_maxima := 0.0
	for jugador in _jugadores:
		if is_instance_valid(jugador):
			var dist := centro.distance_to(jugador.global_position)
			distancia_maxima = max(distancia_maxima, dist)
	
	# Ajustar zoom según distancia
	var zoom_valor := clampf(
		1.0 - (distancia_maxima / 1000.0),
		zoom_min,
		zoom_max
	)
	_zoom_objetivo = Vector2.ONE * zoom_valor
	
	# Suavizado manual con redondeo a píxeles para evitar vibración
	var posicion_suavizada := global_position.lerp(centro, delta * suavizado_posicion)
	global_position = posicion_suavizada.round() # Redondear a píxeles enteros
	
	# Suavizar zoom manualmente
	zoom = zoom.lerp(_zoom_objetivo, delta * suavizado_zoom)
