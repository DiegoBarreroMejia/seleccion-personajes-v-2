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
const VICTORIA_SCENE: PackedScene = preload("res://scenes/ui/Victoria.tscn")
const COUNTDOWN_SCENE: PackedScene = preload("res://scenes/ui/Countdown.tscn")

# === VARIABLES PRIVADAS ===
var _jugadores: Dictionary = {}
var _puntos_spawn: Dictionary = {}
var _ronda_finalizada: bool = false  # Evita procesar múltiples muertes

# === MÉTODOS DE CICLO DE VIDA ===

func _ready() -> void:
	_encontrar_puntos_spawn()
	_spawn_jugadores()
	_instanciar_hud()
	_iniciar_countdown()

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
	# Evitar procesar si la ronda ya fue finalizada
	if _ronda_finalizada:
		return

	jugador_murio.emit(id_jugador_muerto)

	# Marcar ronda como finalizada ANTES del await para evitar race condition
	# Si ambos jugadores mueren en el mismo frame, solo el primero pasa este punto
	_ronda_finalizada = true

	# Esperar un frame para detectar muerte simultánea
	await get_tree().process_frame

	if not is_inside_tree():
		return

	# Detectar muerte simultánea: verificar si ambos jugadores están muertos
	var j1_vivo := _jugador_esta_vivo(1)
	var j2_vivo := _jugador_esta_vivo(2)

	var id_ganador: int
	var es_empate := false

	if not j1_vivo and not j2_vivo:
		# Muerte simultánea = empate, no se suman puntos
		es_empate = true
		id_ganador = 0
		print("¡EMPATE! Ambos jugadores murieron simultáneamente")
	else:
		# Victoria normal
		id_ganador = 1 if j1_vivo else 2
		Global.sumar_puntos(id_ganador)

	var puntos_p1 := Global.obtener_puntuacion(1)
	var puntos_p2 := Global.obtener_puntuacion(2)

	if not es_empate:
		print("Muerte: J%d eliminado. Marcador: %d - %d" % [id_jugador_muerto, puntos_p1, puntos_p2])

	ronda_terminada.emit(id_ganador)

	# Validación defensiva antes del await
	if not is_inside_tree():
		return

	await get_tree().create_timer(0.5).timeout

	# Validación defensiva después del await
	if not is_inside_tree():
		return

	_verificar_victoria()

func _jugador_esta_vivo(id_jugador: int) -> bool:
	var jugador: PersonajeBase = _jugadores.get(id_jugador)
	if not is_instance_valid(jugador):
		return false
	return jugador.esta_vivo()

# === LIMPIEZA DE ESCENA ===

func _limpiar_armas_sueltas() -> void:
	## Elimina todas las armas que quedaron en el root (soltadas/lanzadas)
	## Esto es necesario porque las armas soltadas se añaden al root, no a la escena
	var root := get_tree().root
	for nodo in root.get_children():
		if nodo is ArmaBase or nodo is ArmaMeleeBase:
			nodo.queue_free()
	print("Armas sueltas limpiadas")

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

	if not is_inside_tree():
		return

	await get_tree().create_timer(RETRASO_VICTORIA).timeout

	if not is_inside_tree():
		return

	_limpiar_armas_sueltas()
	Global.ultimo_ganador = id_ganador
	var victoria := VICTORIA_SCENE.instantiate()
	add_child(victoria)

func _iniciar_siguiente_ronda() -> void:
	print("Nadie ha ganado aún. Siguiente ronda en %.1fs..." % RETRASO_TRANSICION_RONDA)

	if not is_inside_tree():
		return

	await get_tree().create_timer(RETRASO_TRANSICION_RONDA).timeout

	# Validación defensiva: verificar que seguimos en el árbol después del await
	if not is_inside_tree():
		push_warning("MapaController: Nodo ya no está en el árbol, cancelando cambio de escena")
		return

	_limpiar_armas_sueltas()

	var mapa_siguiente := Global.obtener_mapa_aleatorio()
	if mapa_siguiente.is_empty():
		push_error("MapaController: No se pudo obtener siguiente mapa")
		return

	if not ResourceLoader.exists(mapa_siguiente):
		push_error("MapaController: Mapa no encontrado: %s" % mapa_siguiente)
		return

	get_tree().change_scene_to_file(mapa_siguiente)

# === MÉTODOS PRIVADOS - COUNTDOWN ===

func _iniciar_countdown() -> void:
	# Bloquear jugadores mientras dura el countdown
	_set_jugadores_bloqueados(true)

	var countdown := COUNTDOWN_SCENE.instantiate()
	add_child(countdown)
	countdown.countdown_terminado.connect(_on_countdown_terminado)

func _on_countdown_terminado() -> void:
	_set_jugadores_bloqueados(false)

func _set_jugadores_bloqueados(valor: bool) -> void:
	for jugador in _jugadores.values():
		if is_instance_valid(jugador):
			jugador.bloqueado = valor

# === MÉTODOS PRIVADOS - HUD ===

func _instanciar_hud() -> void:
	var hud_scene := load("res://scenes/ui/HUD.tscn") as PackedScene
	if not hud_scene:
		push_warning("MapaController: No se pudo cargar HUD.tscn")
		return
	
	var hud := hud_scene.instantiate()
	add_child(hud)
