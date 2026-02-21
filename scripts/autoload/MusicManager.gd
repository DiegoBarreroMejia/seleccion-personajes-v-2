extends Node

## Gestor de música del juego
##
## Autoload que reproduce soundtracks en loop durante los menús
## y música específica por mapa durante las partidas.
## - Menús (MenuInicio, CharacterSelect, Ajustes): soundtracks del juego
## - Mapas: música específica por mapa (configurable en MUSICA_MAPAS)

# === CONSTANTES ===
const SOUNDTRACKS: Array[Dictionary] = [
	{"nombre": "Soundtrack 1", "ruta": "res://assets/sonidos/soundtrack/Soundtrack1 - Crossover Battle.ogg"},
	{"nombre": "Soundtrack 2", "ruta": "res://assets/sonidos/soundtrack/Soundtrack2 - Crossover Battle.ogg"},
	{"nombre": "Soundtrack 3", "ruta": "res://assets/sonidos/soundtrack/Soundtrack3 - Crossover Battle.ogg"},
	{"nombre": "Soundtrack 4", "ruta": "res://assets/sonidos/soundtrack/Soundtrack4 - Crossover Battle.ogg"},
	{"nombre": "Soundtrack 5", "ruta": "res://assets/sonidos/soundtrack/Soundtrack5 - Crossover Battle.ogg"},
	{"nombre": "Soundtrack 6", "ruta": "res://assets/sonidos/soundtrack/Soundtrack6 - Crossover Battle.ogg"},
]

## Escenas donde SÍ debe sonar la música de menú
const ESCENAS_CON_MUSICA: Array[String] = [
	"MenuInicio",
	"CharacterSelect",
	"Ajustes",
]

## Música específica por mapa (ruta de escena → ruta de audio)
## Los mapas que no estén aquí no tendrán música de fondo.
const MUSICA_MAPAS: Dictionary = {
	"res://scenes/mapas/Mapa3.tscn": "res://assets/sonidos/Minecraft/musica_minecraft.ogg",
	# Añadir más mapas aquí:
	# "res://scenes/mapas/Mapa1.tscn": "res://assets/sonidos/ruta/musica.ogg",
}

# === VARIABLES PRIVADAS ===
var _player: AudioStreamPlayer          ## Player para música de menú
var _player_mapa: AudioStreamPlayer     ## Player para música de mapa
var _soundtrack_actual: int = 0
var _musica_permitida: bool = true  ## Si la escena actual permite música de menú
var _escena_anterior: String = ""

# === CICLO DE VIDA ===

func _ready() -> void:
	# IMPORTANTE: process_mode ALWAYS para que funcione incluso en pausa
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Crear el AudioStreamPlayer para música de menú
	_player = AudioStreamPlayer.new()
	_player.bus = "Musica"
	_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_player)

	# Crear el AudioStreamPlayer para música de mapa
	# PAUSABLE: la música de mapa se pausa automáticamente con el juego
	# (menú de pausa, ajustes desde pausa, etc.)
	_player_mapa = AudioStreamPlayer.new()
	_player_mapa.bus = "Musica"
	_player_mapa.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_player_mapa)

	# Conectar señales para loop manual
	_player.finished.connect(_on_musica_terminada)
	_player_mapa.finished.connect(_on_musica_mapa_terminada)

	# Esperar un frame para que ConfigManager ya haya cargado
	await get_tree().process_frame

	# Aplicar configuración guardada
	_soundtrack_actual = ConfigManager.soundtrack_seleccionado
	cambiar_volumen(ConfigManager.volumen_musica)

	# Cargar y reproducir si estamos en una escena con música
	var escena := get_tree().current_scene
	if escena and escena.name in ESCENAS_CON_MUSICA:
		_musica_permitida = true
		_escena_anterior = escena.name
		reproducir(_soundtrack_actual)
	else:
		_musica_permitida = false
		if escena:
			_escena_anterior = escena.name
			# Verificar si es un mapa con música
			_intentar_musica_mapa(escena)

func _process(_delta: float) -> void:
	_detectar_cambio_escena()

# === DETECCIÓN DE ESCENA ===

func _detectar_cambio_escena() -> void:
	var escena := get_tree().current_scene
	if not escena:
		return

	var nombre := escena.name
	if nombre == _escena_anterior:
		return

	_escena_anterior = nombre

	# Verificar si la escena actual está en la lista de escenas con música de menú
	if nombre in ESCENAS_CON_MUSICA:
		# Escena de menú → detener música de mapa, reanudar música de menú
		_detener_musica_mapa()
		_musica_permitida = true
		reanudar()
	else:
		# Mapa u otra escena → pausar música de menú
		_musica_permitida = false
		pausar()
		# Intentar reproducir música específica del mapa
		_intentar_musica_mapa(escena)

# === MÉTODOS PÚBLICOS ===

func reproducir(indice: int) -> void:
	## Reproduce el soundtrack con el índice dado
	if indice < 0 or indice >= SOUNDTRACKS.size():
		push_warning("MusicManager: Índice de soundtrack inválido: %d" % indice)
		return

	_soundtrack_actual = indice
	var ruta: String = SOUNDTRACKS[indice]["ruta"]

	var stream := load(ruta) as AudioStream
	if not stream:
		push_warning("MusicManager: No se pudo cargar: %s" % ruta)
		return

	_player.stream = stream

	# Solo reproducir si estamos en una escena que permite música
	if _musica_permitida:
		_player.play()
		print("MusicManager: Reproduciendo '%s'" % SOUNDTRACKS[indice]["nombre"])
	else:
		print("MusicManager: Soundtrack cambiado a '%s' (sonará al volver al menú)" % SOUNDTRACKS[indice]["nombre"])

func pausar() -> void:
	## Pausa la música (mantiene la posición)
	if _player.playing:
		_player.stream_paused = true
		print("MusicManager: Música pausada")

func reanudar() -> void:
	## Reanuda la música desde donde se pausó
	if _player.stream_paused:
		_player.stream_paused = false
		print("MusicManager: Música reanudada")
	elif not _player.playing and _player.stream:
		# Si no estaba pausada sino que se había detenido, reproducir de nuevo
		_player.play()

func cambiar_volumen(valor: float) -> void:
	## Cambia el volumen de toda la música (0.0 a 1.0)
	valor = clampf(valor, 0.0, 1.0)
	# Convertir de lineal a decibelios
	var db: float
	if valor <= 0.0:
		db = -80.0  # Silencio
	else:
		db = linear_to_db(valor)
	_player.volume_db = db
	_player_mapa.volume_db = db

func obtener_soundtrack_actual() -> int:
	return _soundtrack_actual

func obtener_nombres_soundtracks() -> Array[String]:
	## Devuelve los nombres de todos los soundtracks disponibles
	var nombres: Array[String] = []
	for st in SOUNDTRACKS:
		nombres.append(st["nombre"])
	return nombres

func obtener_cantidad_soundtracks() -> int:
	return SOUNDTRACKS.size()

# === MÚSICA DE MAPA ===

func _intentar_musica_mapa(escena: Node) -> void:
	## Busca si el mapa actual tiene música asignada y la reproduce
	var ruta_escena := escena.scene_file_path
	if ruta_escena in MUSICA_MAPAS:
		_reproducir_musica_mapa(MUSICA_MAPAS[ruta_escena])
	else:
		# Este mapa no tiene música asignada
		_detener_musica_mapa()

func _reproducir_musica_mapa(ruta_audio: String) -> void:
	## Reproduce música de mapa en loop
	var stream := load(ruta_audio) as AudioStream
	if not stream:
		push_warning("MusicManager: No se pudo cargar música de mapa: %s" % ruta_audio)
		return

	_player_mapa.stream = stream
	_player_mapa.play()
	print("MusicManager: Música de mapa iniciada: %s" % ruta_audio)

func _detener_musica_mapa() -> void:
	## Detiene la música del mapa
	if _player_mapa.playing:
		_player_mapa.stop()
		print("MusicManager: Música de mapa detenida")

# === CALLBACKS ===

func _on_musica_terminada() -> void:
	# Loop: volver a reproducir la misma canción de menú
	if _musica_permitida:
		_player.play()

func _on_musica_mapa_terminada() -> void:
	# Loop: volver a reproducir la música del mapa
	if not _musica_permitida and _player_mapa.stream:
		_player_mapa.play()
