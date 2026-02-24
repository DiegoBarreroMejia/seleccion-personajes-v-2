extends Node2D

signal jugador_spawneado(id_jugador: int, personaje: PersonajeBase)
signal jugador_murio(id_jugador: int)
signal ronda_terminada(id_ganador: int)
signal partida_terminada(id_ganador: int)

const RETRASO_VICTORIA: float = 2.0
const RETRASO_TRANSICION_RONDA: float = 1.5
const VICTORIA_SCENE: PackedScene = preload("res://scenes/ui/Victoria.tscn")
const COUNTDOWN_SCENE: PackedScene = preload("res://scenes/ui/Countdown.tscn")

const SFX_DANO_MAPA: Dictionary = {
	"res://scenes/mapas/Mapa3.tscn": preload("res://assets/sonidos/Minecraft/hit1.ogg"),
	}

var _jugadores: Dictionary = {}
var _puntos_spawn: Dictionary = {}
var _ronda_finalizada: bool = false
var _sfx_dano_player: AudioStreamPlayer = null
var _sonido_dano: AudioStream = null

# Configura sfx, spawn y HUD del mapa
func _ready() -> void:
	_configurar_sfx_mapa()
	_encontrar_puntos_spawn()
	_spawn_jugadores()
	_instanciar_hud()
	_iniciar_countdown()

# Busca los Marker2D con id_jugador como puntos de spawn
func _encontrar_puntos_spawn() -> void:
	for hijo in get_children():
		if hijo is Marker2D and "id_jugador" in hijo:
			_puntos_spawn[hijo.id_jugador] = hijo.global_position

	if _puntos_spawn.is_empty():
		push_error("MapaController: No se encontraron puntos de spawn")

# Spawnea ambos jugadores
func _spawn_jugadores() -> void:
	_spawn_jugador(1, Global.p1_seleccion)
	_spawn_jugador(2, Global.p2_seleccion)

# Instancia y posiciona un jugador en su punto de spawn
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
	personaje.recibio_dano.connect(_on_jugador_recibio_dano)

	add_child(personaje)
	_jugadores[id_jugador] = personaje

	jugador_spawneado.emit(id_jugador, personaje)

# Gestiona la muerte de un jugador y suma puntos al ganador
func _on_jugador_murio(id_jugador_muerto: int) -> void:
	if _ronda_finalizada:
		return

	jugador_murio.emit(id_jugador_muerto)

	_ronda_finalizada = true

	await get_tree().process_frame

	if not is_inside_tree():
		return

	var j1_vivo := _jugador_esta_vivo(1)
	var j2_vivo := _jugador_esta_vivo(2)

	var id_ganador: int
	var es_empate := false

	if not j1_vivo and not j2_vivo:
		es_empate = true
		id_ganador = 0
	else:
		id_ganador = 1 if j1_vivo else 2
		Global.sumar_puntos(id_ganador)

	if not es_empate:
		pass

	ronda_terminada.emit(id_ganador)

	if not is_inside_tree():
		return

	await get_tree().create_timer(0.5).timeout

	if not is_inside_tree():
		return

	_verificar_victoria()

# Verifica si un jugador esta vivo
func _jugador_esta_vivo(id_jugador: int) -> bool:
	var jugador: PersonajeBase = _jugadores.get(id_jugador)
	if not is_instance_valid(jugador):
		return false
	return jugador.esta_vivo()

# Elimina armas sueltas del root
func _limpiar_armas_sueltas() -> void:
	var root := get_tree().root
	for nodo in root.get_children():
		if nodo is ArmaBase or nodo is ArmaMeleeBase:
			nodo.queue_free()

# Verifica si alguien alcanzo los puntos para ganar
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

# Muestra pantalla de victoria tras un retraso
func _manejar_victoria_partida(id_ganador: int) -> void:

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

# Cambia a un mapa aleatorio para la siguiente ronda
func _iniciar_siguiente_ronda() -> void:

	if not is_inside_tree():
		return

	await get_tree().create_timer(RETRASO_TRANSICION_RONDA).timeout

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

# Inicia countdown y bloquea jugadores hasta que termine
func _iniciar_countdown() -> void:
	_set_jugadores_bloqueados(true)

	var countdown := COUNTDOWN_SCENE.instantiate()
	add_child(countdown)
	countdown.countdown_terminado.connect(_on_countdown_terminado)

# Desbloquea jugadores al terminar el countdown
func _on_countdown_terminado() -> void:
	_set_jugadores_bloqueados(false)

# Bloquea o desbloquea a todos los jugadores
func _set_jugadores_bloqueados(valor: bool) -> void:
	for jugador in _jugadores.values():
		if is_instance_valid(jugador):
			jugador.bloqueado = valor

# Configura el sonido de dano especifico del mapa
func _configurar_sfx_mapa() -> void:
	var ruta_escena := scene_file_path
	if ruta_escena in SFX_DANO_MAPA:
		_sonido_dano = SFX_DANO_MAPA[ruta_escena]
		_sfx_dano_player = AudioStreamPlayer.new()
		_sfx_dano_player.bus = "SFX"
		add_child(_sfx_dano_player)

# Reproduce sonido de dano del mapa si tiene uno
func _on_jugador_recibio_dano(_cantidad: int) -> void:
	if _sfx_dano_player and _sonido_dano:
		_sfx_dano_player.stream = _sonido_dano
		_sfx_dano_player.play()

# Instancia el HUD como hijo del mapa
func _instanciar_hud() -> void:
	var hud_scene := load("res://scenes/ui/HUD.tscn") as PackedScene
	if not hud_scene:
		push_warning("MapaController: No se pudo cargar HUD.tscn")
		return

	var hud := hud_scene.instantiate()
	add_child(hud)
