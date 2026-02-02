extends Node

## Gestiona la configuración global del juego, puntuación y datos de partida
##
## Este singleton maneja:
## - Configuración de reglas (vidas, puntos para ganar)
## - Catálogo de personajes y mapas
## - Puntuación de jugadores
## - Controles de entrada

# === CONSTANTES ===
const MIN_VIDA: int = 1
const MAX_VIDA: int = 10
const VIDA_DEFECTO: int = 1
const MIN_PUNTOS: int = 1
const MAX_PUNTOS: int = 50
const PUNTOS_DEFECTO: int = 10

# === SEÑALES ===
signal puntuacion_cambiada(id_jugador: int, nueva_puntuacion: int)
signal vida_cambiada(nueva_vida: int)
signal puntos_ganar_cambiados(nuevos_puntos: int)
signal partida_ganada(id_ganador: int)

# === CONFIGURACIÓN DE PARTIDA ===
var vida_maxima: int = VIDA_DEFECTO:
	set(value):
		vida_maxima = clampi(value, MIN_VIDA, MAX_VIDA)
		vida_cambiada.emit(vida_maxima)

var puntos_ganar: int = PUNTOS_DEFECTO:
	set(value):
		puntos_ganar = clampi(value, MIN_PUNTOS, MAX_PUNTOS)
		puntos_ganar_cambiados.emit(puntos_ganar)

# === PUNTUACIÓN (PRIVADA) ===
var _p1_score: int = 0
var _p2_score: int = 0

# === CATÁLOGO DE PERSONAJES ===
var catalogo_personajes: Array[Dictionary] = [
	{
		"nombre": "Amarillo",
		"retrato": "res://assets/sprites/personajes/pato_amarillo/pato_amarillo.png",
		"escena": "res://scenes/personajes/Pato_Amarillo.tscn"
	},
	{
		"nombre": "Blanco",
		"retrato": "res://assets/sprites/personajes/pato_blanco/pato_blanco.png",
		"escena": "res://scenes/personajes/Pato_Blanco.tscn"
	},
	{
		"nombre": "Gris",
		"retrato": "res://assets/sprites/personajes/pato_gris/pato_gris.png",
		"escena": "res://scenes/personajes/Pato_Gris.tscn"
	},
	{
		"nombre": "Marron",
		"retrato": "res://assets/sprites/personajes/pato_marron/pato_marron.png",
		"escena": "res://scenes/personajes/Pato_Marron.tscn"
	},
	{
		"nombre": "Steve",
		"retrato": "res://assets/sprites/personajes/steve/Steveee.png",
		"escena": "res://scenes/personajes/steve.tscn"
	},
	{
		"nombre": "Mulan",
		"retrato": "res://assets/sprites/personajes/mulan/caminarMulan_001.png",
		"escena": "res://scenes/personajes/Mulan.tscn"
	}
]

# === SELECCIÓN ACTUAL ===
var p1_seleccion: Dictionary = {}
var p2_seleccion: Dictionary = {}

# === CONTROLES (AHORA CONSTANTES) ===
const p1_controls: Dictionary = {
	"up": "j1_arriba",
	"down": "j1_abajo",
	"left": "j1_izquierda",
	"right": "j1_derecha",
	"jump": "j1_salto",
	"shoot": "j1_disparo",
	"action": "j1_accion"
}

const p2_controls: Dictionary = {
	"up": "j2_arriba",
	"down": "j2_abajo",
	"left": "j2_izquierda",
	"right": "j2_derecha",
	"jump": "j2_salto",
	"shoot": "j2_disparo",
	"action": "j2_accion"
}

# === MAPAS ===
var mapas_disponibles: Array[String] = [
	"res://scenes/mapas/Mapa1.tscn",
	"res://scenes/mapas/Mapa2.tscn"
]

# === MÉTODOS DE CICLO DE VIDA ===

func _ready() -> void:
	_inicializar_selecciones_defecto()

# === MÉTODOS PRIVADOS ===

func _inicializar_selecciones_defecto() -> void:
	if catalogo_personajes.size() >= 2:
		p1_seleccion = catalogo_personajes[0]
		p2_seleccion = catalogo_personajes[1]
	else:
		push_error("Global: No hay suficientes personajes en el catálogo")

func _verificar_victoria(id_jugador: int) -> void:
	var puntuacion := obtener_puntuacion(id_jugador)
	if puntuacion >= puntos_ganar:
		partida_ganada.emit(id_jugador)

# === MÉTODOS PÚBLICOS - PUNTUACIÓN ===

## Añade puntos al jugador especificado
func sumar_puntos(id_jugador: int, puntos: int = 1) -> void:
	if id_jugador == 1:
		_p1_score += puntos
		puntuacion_cambiada.emit(1, _p1_score)
		_verificar_victoria(1)
	elif id_jugador == 2:
		_p2_score += puntos
		puntuacion_cambiada.emit(2, _p2_score)
		_verificar_victoria(2)
	else:
		push_warning("Global: ID de jugador inválido: %d" % id_jugador)

## Obtiene la puntuación de un jugador
func obtener_puntuacion(id_jugador: int) -> int:
	if id_jugador == 1:
		return _p1_score
	elif id_jugador == 2:
		return _p2_score
	else:
		push_warning("Global: ID de jugador inválido: %d" % id_jugador)
		return 0

## Reinicia las puntuaciones de ambos jugadores
func reiniciar_puntuaciones() -> void:
	_p1_score = 0
	_p2_score = 0
	puntuacion_cambiada.emit(1, 0)
	puntuacion_cambiada.emit(2, 0)

# === MÉTODOS PÚBLICOS - UTILIDADES ===

## Obtiene los controles de un jugador
func obtener_controles(id_jugador: int) -> Dictionary:
	if id_jugador == 1:
		return p1_controls
	elif id_jugador == 2:
		return p2_controls
	else:
		push_warning("Global: ID de jugador inválido: %d" % id_jugador)
		return {}

## Obtiene un mapa aleatorio de la lista disponible
func obtener_mapa_aleatorio() -> String:
	if mapas_disponibles.is_empty():
		push_error("Global: No hay mapas disponibles")
		return ""
	return mapas_disponibles.pick_random()
