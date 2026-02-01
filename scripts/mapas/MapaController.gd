extends Node2D

## Controla la lógica de un mapa específico
##
## Responsable de:
## - Spawn de jugadores en sus posiciones
## - Gestión de muertes
## - Victoria/Derrota
## - Transiciones entre rondas

# === SEÑALES ===
signal jugador_spawneado(id_jugador: int, personaje: PersonajeBase)
signal jugador_murio(id_jugador: int)
signal ronda_terminada(id_ganador: int)
signal partida_terminada(id_ganador: int)

# === CONSTANTES ===
const RETRASO_VICTORIA: float = 2.0
const RETRASO_TRANSICION_RONDA: float = 1.5
const RUTA_MENU_SELECCION: String = "res://scenes/ui/CharacterSelect.tscn"

# === VARIABLES PRIVADAS ===
var _jugadores: Dictionary = {}
var _puntos_spawn: Dictionary = {}

# === MÉTODOS DE CICLO DE VIDA ===

func _ready() -> void:
	_encontrar_puntos_spawn()
	_spawn_jugadores()
	_instanciar_hud()

# === CONFIGURACIÓN INICIAL ===

func _encontrar_puntos_spawn() -> void:
	for hijo in get_children():
		# Sistema unificado: usar variable exportada id_jugador
		if hijo is Marker2D and "id_jugador" in hijo:
			_puntos_spawn[hijo.id_jugador] = hijo.global_position
	
	if _puntos_spawn.is_empty():
		push_error("MapaController: No se encontraron puntos de spawn")

# === SPAWN DE JUGADORES ===

func _spawn_jugadores() -> void:
	_spawn_jugador(1, Global.p1_seleccion)
	_spawn_jugador(2, Global.p2_seleccion)

func _spawn_jugador(id_jugador: int, datos_personaje: Dictionary) -> void:
	var ruta_escena: String = datos_personaje.get("escena", "")
	
	if ruta_escena.is_empty():
		push_error("MapaController: Escena vacía para jugador %d" % id_jugador)
		return
	
	if not ResourceLoader.exists(ruta_escena):
		push_error("MapaController: Escena no encontrada: %s" % ruta_escena)
		return
	
	var escena_personaje := load(ruta_escena) as PackedScene
	if not escena_personaje:
		push_error("MapaController: No se pudo cargar escena: %s" % ruta_escena)
		return
	
	var personaje := escena_personaje.instantiate() as PersonajeBase
	if not personaje:
		push_error("MapaController: La escena no es un PersonajeBase")
		return
	
	personaje.player_id = id_jugador
	
	var pos_spawn: Vector2 = _puntos_spawn.get(id_jugador, Vector2.ZERO)
	personaje.position = pos_spawn
	
	personaje.murio.connect(_on_jugador_murio)
	
	add_child(personaje)
	_jugadores[id_jugador] = personaje
	
	jugador_spawneado.emit(id_jugador, personaje)
	print("Jugador %d spawneado: %s" % [id_jugador, datos_personaje.get("nombre", "?")])

# === GESTIÓN DE MUERTE ===

func _on_jugador_murio(id_jugador_muerto: int) -> void:
	var id_ganador := 2 if id_jugador_muerto == 1 else 1
	
	Global.sumar_puntos(id_ganador)
	
	var puntos_p1 := Global.obtener_puntuacion(1)
	var puntos_p2 := Global.obtener_puntuacion(2)
	
	print("Muerte: J%d eliminado. Marcador: %d - %d" % [id_jugador_muerto, puntos_p1, puntos_p2])
	
	jugador_murio.emit(id_jugador_muerto)
	ronda_terminada.emit(id_ganador)
	
	await get_tree().create_timer(0.5).timeout
	_verificar_victoria()

# === GESTIÓN DE VICTORIA ===

func _verificar_victoria() -> void:
	var puntos_p1 := Global.obtener_puntuacion(1)
	var puntos_p2 := Global.obtener_puntuacion(2)
	var objetivo := Global.puntos_ganar
	
	if puntos_p1 >= objetivo:
		_manejar_victoria_partida(1)
	elif puntos_p2 >= objetivo:
		_manejar_victoria_partida(2)
	else:
		_iniciar_siguiente_ronda()

func _manejar_victoria_partida(id_ganador: int) -> void:
	print("=========================")
	print("¡PARTIDA GANADA POR JUGADOR %d!" % id_ganador)
	print("=========================")
	
	partida_terminada.emit(id_ganador)
	
	await get_tree().create_timer(RETRASO_VICTORIA).timeout
	
	Global.reiniciar_puntuaciones()
	get_tree().change_scene_to_file(RUTA_MENU_SELECCION)

func _iniciar_siguiente_ronda() -> void:
	print("Nadie ha ganado aún. Siguiente ronda en %.1fs..." % RETRASO_TRANSICION_RONDA)
	
	await get_tree().create_timer(RETRASO_TRANSICION_RONDA).timeout
	
	var mapa_siguiente := Global.obtener_mapa_aleatorio()
	if mapa_siguiente.is_empty():
		push_error("MapaController: No se pudo obtener siguiente mapa")
		return
	
	get_tree().change_scene_to_file(mapa_siguiente)

# === MÉTODOS PÚBLICOS ===

func obtener_jugador(id_jugador: int) -> PersonajeBase:
	return _jugadores.get(id_jugador)

func reaparecer_jugador(id_jugador: int) -> void:
	var personaje: PersonajeBase = _jugadores.get(id_jugador)
	
	if personaje:
		var pos_spawn: Vector2 = _puntos_spawn.get(id_jugador, Vector2.ZERO)
		personaje.position = pos_spawn
		print("Jugador %d reaparecido" % id_jugador)

func obtener_marcador_texto() -> String:
	var p1 := Global.obtener_puntuacion(1)
	var p2 := Global.obtener_puntuacion(2)
	return "%d - %d" % [p1, p2]

func _instanciar_hud() -> void:
	var hud_scene := load("res://scenes/ui/HUD.tscn") as PackedScene
	if not hud_scene:
		push_warning("MapaController: No se pudo cargar HUD.tscn")
		return
	
	var hud := hud_scene.instantiate()
	add_child(hud)
