extends Node

const SOUNDTRACKS: Array[Dictionary] = [
	{"nombre": "Soundtrack 1", "ruta": "res://assets/sonidos/soundtrack/Soundtrack1 - Crossover Battle.ogg"},
	{"nombre": "Soundtrack 2", "ruta": "res://assets/sonidos/soundtrack/Soundtrack2 - Crossover Battle.ogg"},
	{"nombre": "Soundtrack 3", "ruta": "res://assets/sonidos/soundtrack/Soundtrack3 - Crossover Battle.ogg"},
	{"nombre": "Soundtrack 4", "ruta": "res://assets/sonidos/soundtrack/Soundtrack4 - Crossover Battle.ogg"},
	{"nombre": "Soundtrack 5", "ruta": "res://assets/sonidos/soundtrack/Soundtrack5 - Crossover Battle.ogg"},
	{"nombre": "Soundtrack 6", "ruta": "res://assets/sonidos/soundtrack/Soundtrack6 - Crossover Battle.ogg"},
]

const ESCENAS_CON_MUSICA: Array[String] = [
	"MenuInicio",
	"CharacterSelect",
	"Ajustes",
]

const MUSICA_MAPAS: Dictionary = {
	"res://scenes/mapas/Mapa3.tscn": "res://assets/sonidos/Minecraft/musica_minecraft.ogg",
	"res://scenes/mapas/Mapa7.tscn": "res://assets/sonidos/God_of_war/cancion_god_of_war_mapa2.ogg",
	"res://scenes/mapas/Mapa6.tscn": "res://assets/sonidos/God_of_war/cancion_god_of_war_mapa1.ogg",
	"res://scenes/mapas/Mapa4.tscn": "res://assets/sonidos/mulan/musica_mulan.ogg",
	"res://scenes/mapas/Mapa8.tscn": "res://assets/sonidos/mapa_cuadrado/musica_mapa_cuadrado.ogg",
}

var _player: AudioStreamPlayer
var _player_mapa: AudioStreamPlayer
var _soundtrack_actual: int = 0
var _musica_permitida: bool = true
var _escena_anterior: String = ""

# Crea reproductores de musica y carga config guardada
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	_player = AudioStreamPlayer.new()
	_player.bus = "Musica"
	_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_player)

	_player_mapa = AudioStreamPlayer.new()
	_player_mapa.bus = "Musica"
	_player_mapa.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_player_mapa)

	_player.finished.connect(_on_musica_terminada)
	_player_mapa.finished.connect(_on_musica_mapa_terminada)

	await get_tree().process_frame

	_soundtrack_actual = ConfigManager.soundtrack_seleccionado
	cambiar_volumen(ConfigManager.volumen_musica)

	var escena := get_tree().current_scene
	if escena and escena.name in ESCENAS_CON_MUSICA:
		_musica_permitida = true
		_escena_anterior = escena.name
		reproducir(_soundtrack_actual)
	else:
		_musica_permitida = false
		if escena:
			_escena_anterior = escena.name
			_intentar_musica_mapa(escena)

# Detecta cambios de escena cada frame
func _process(_delta: float) -> void:
	_detectar_cambio_escena()

# Gestiona musica de menu o mapa al cambiar de escena
func _detectar_cambio_escena() -> void:
	var escena := get_tree().current_scene
	if not escena:
		return

	var nombre := escena.name
	if nombre == _escena_anterior:
		return

	_escena_anterior = nombre

	if nombre in ESCENAS_CON_MUSICA:
		_detener_musica_mapa()
		_musica_permitida = true
		reanudar()
	else:
		_musica_permitida = false
		pausar()
		_intentar_musica_mapa(escena)

# Reproduce el soundtrack con el indice dado
func reproducir(indice: int) -> void:
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

	if _musica_permitida:
		_player.play()
	else:
		pass

# Pausa la musica de menu
func pausar() -> void:
	if _player.playing:
		_player.stream_paused = true

# Reanuda la musica de menu
func reanudar() -> void:
	if _player.stream_paused:
		_player.stream_paused = false
	elif not _player.playing and _player.stream:
		_player.play()

# Cambia el volumen de toda la musica
func cambiar_volumen(valor: float) -> void:
	valor = clampf(valor, 0.0, 1.0)
	var db: float
	if valor <= 0.0:
		db = -80.0
	else:
		db = linear_to_db(valor)
	_player.volume_db = db
	_player_mapa.volume_db = db

# Devuelve el indice del soundtrack actual
func obtener_soundtrack_actual() -> int:
	return _soundtrack_actual

# Devuelve los nombres de todos los soundtracks
func obtener_nombres_soundtracks() -> Array[String]:
	var nombres: Array[String] = []
	for st in SOUNDTRACKS:
		nombres.append(st["nombre"])
	return nombres

# Devuelve la cantidad de soundtracks
func obtener_cantidad_soundtracks() -> int:
	return SOUNDTRACKS.size()

# Reproduce musica del mapa si tiene una asignada
func _intentar_musica_mapa(escena: Node) -> void:
	var ruta_escena := escena.scene_file_path
	if ruta_escena in MUSICA_MAPAS:
		_reproducir_musica_mapa(MUSICA_MAPAS[ruta_escena])
	else:
		_detener_musica_mapa()

# Reproduce musica de mapa en loop
func _reproducir_musica_mapa(ruta_audio: String) -> void:
	var stream := load(ruta_audio) as AudioStream
	if not stream:
		push_warning("MusicManager: No se pudo cargar música de mapa: %s" % ruta_audio)
		return

	_player_mapa.stream = stream
	_player_mapa.play()

# Detiene la musica del mapa
func _detener_musica_mapa() -> void:
	if _player_mapa.playing:
		_player_mapa.stop()

# Loop de musica de menu
func _on_musica_terminada() -> void:
	if _musica_permitida:
		_player.play()

# Loop de musica de mapa
func _on_musica_mapa_terminada() -> void:
	if not _musica_permitida and _player_mapa.stream:
		_player_mapa.play()
