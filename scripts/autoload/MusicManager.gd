extends Node

## Gestor de música del juego
##
## Autoload que reproduce soundtracks en loop durante los menús.
## La música suena SOLO en: MenuInicio, CharacterSelect, Ajustes (como escena).
## NO suena en: mapas (partidas), menú de pausa, pantalla de victoria.

# === CONSTANTES ===
const SOUNDTRACKS: Array[Dictionary] = [
	{"nombre": "Soundtrack 1", "ruta": "res://assets/sonidos/soundtrack/Soundtrack1 - Crossover Battle.ogg"},
	{"nombre": "Soundtrack 2", "ruta": "res://assets/sonidos/soundtrack/Soundtrack2 - Crossover Battle.ogg"},
	{"nombre": "Soundtrack 3", "ruta": "res://assets/sonidos/soundtrack/Soundtrack3 - Crossover Battle.ogg"},
	{"nombre": "Soundtrack 4", "ruta": "res://assets/sonidos/soundtrack/Soundtrack4 - Crossover Battle.ogg"},
	{"nombre": "Soundtrack 5", "ruta": "res://assets/sonidos/soundtrack/Soundtrack5 - Crossover Battle.ogg"},
	{"nombre": "Soundtrack 6", "ruta": "res://assets/sonidos/soundtrack/Soundtrack6 - Crossover Battle.ogg"},
]

## Escenas donde SÍ debe sonar la música
const ESCENAS_CON_MUSICA: Array[String] = [
	"MenuInicio",
	"CharacterSelect",
	"Ajustes",
]

# === VARIABLES PRIVADAS ===
var _player: AudioStreamPlayer
var _soundtrack_actual: int = 0
var _musica_permitida: bool = true  ## Si la escena actual permite música
var _escena_anterior: String = ""

# === CICLO DE VIDA ===

func _ready() -> void:
	# IMPORTANTE: process_mode ALWAYS para que funcione incluso en pausa
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Crear el AudioStreamPlayer
	_player = AudioStreamPlayer.new()
	_player.bus = "Musica"
	_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_player)

	# Conectar señal para cuando termine la canción (loop manual)
	_player.finished.connect(_on_musica_terminada)

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

	# Verificar si la escena actual está en la lista de escenas con música
	if nombre in ESCENAS_CON_MUSICA:
		_musica_permitida = true
		reanudar()
	else:
		# Mapa, Victoria, o cualquier otra escena → sin música
		_musica_permitida = false
		pausar()

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
	## Cambia el volumen (0.0 a 1.0)
	valor = clampf(valor, 0.0, 1.0)
	# Convertir de lineal a decibelios
	if valor <= 0.0:
		_player.volume_db = -80.0  # Silencio
	else:
		_player.volume_db = linear_to_db(valor)

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

# === CALLBACKS ===

func _on_musica_terminada() -> void:
	# Loop: volver a reproducir la misma canción
	if _musica_permitida:
		_player.play()
