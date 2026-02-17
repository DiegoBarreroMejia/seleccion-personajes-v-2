extends Node

## Gestor de efectos de sonido de UI
##
## Autoload que reproduce sonidos de interfaz.
## Conecta automáticamente hover y click a todos los botones de cada escena.
## Uso: SFXManager.reproducir("click") o automáticamente al interactuar con botones.

# === CONSTANTES ===
const SONIDOS: Dictionary = {
	"click": preload("res://assets/sonidos/ui/sonido_cuando_pulsas_un_boton.ogg"),
	"hover": preload("res://assets/sonidos/ui/sonido_cuando_pasas_el_raton.ogg"),
	"flecha_reglas": preload("res://assets/sonidos/ui/sonido_cuando_pulsas_un_boton_flecha.ogg"),
	"cambiar_personaje": preload("res://assets/sonidos/ui/sonido_para_botones_cambiar_personaje.ogg"),
	"cerrar_juego": preload("res://assets/sonidos/ui/sonido_cuando_cierras_juego.ogg"),
}

## Botones de flechas de reglas (vida/puntos) en CharacterSelect
const BOTONES_FLECHA_REGLAS: Array[String] = [
	"BtnVidaMas", "BtnVidaMenos", "BtnPuntosMas", "BtnPuntosMenos"
]

## Botones de cambiar personaje en CharacterSelect
const BOTONES_CAMBIAR_PERSONAJE: Array[String] = [
	"anterior_p1", "siguiente_p1", "anterior_p2", "siguiente_p2"
]

# === VARIABLES PRIVADAS ===
var _player: AudioStreamPlayer

# === CICLO DE VIDA ===

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	_player = AudioStreamPlayer.new()
	_player.process_mode = Node.PROCESS_MODE_ALWAYS
	_player.bus = "SFX"
	add_child(_player)

	# Conectar para detectar nodos nuevos que se agregan al árbol
	get_tree().node_added.connect(_on_nodo_agregado)

	# Conectar botones de la escena inicial (ya está cargada cuando este autoload arranca)
	# Esperar 2 frames para asegurar que todo esté listo
	await get_tree().process_frame
	await get_tree().process_frame

	# Aplicar volumen SFX guardado
	cambiar_volumen(ConfigManager.volumen_sfx)
	_escanear_escena_actual()

# === MÉTODOS PÚBLICOS ===

func reproducir(nombre_sonido: String) -> void:
	## Reproduce un sonido de UI por nombre
	if nombre_sonido not in SONIDOS:
		push_warning("SFXManager: Sonido desconocido: %s" % nombre_sonido)
		return
	_player.stream = SONIDOS[nombre_sonido]
	_player.play()

func cambiar_volumen(valor: float) -> void:
	## Cambia el volumen del bus SFX (0.0 a 1.0)
	valor = clampf(valor, 0.0, 1.0)
	var bus_idx := AudioServer.get_bus_index("SFX")
	if bus_idx >= 0:
		if valor <= 0.0:
			AudioServer.set_bus_volume_db(bus_idx, -80.0)
		else:
			AudioServer.set_bus_volume_db(bus_idx, linear_to_db(valor))

# === MÉTODOS PRIVADOS ===

func _escanear_escena_actual() -> void:
	## Escanea la escena actual y conecta todos los botones
	var escena := get_tree().current_scene
	if escena:
		_conectar_botones_recursivo(escena)

func _on_nodo_agregado(nodo: Node) -> void:
	## Cuando se agrega un nodo al árbol, si es un botón, conectar sonidos
	if nodo is BaseButton:
		# Defer para que el botón esté completamente inicializado
		_conectar_boton.call_deferred(nodo)

func _conectar_botones_recursivo(nodo: Node) -> void:
	## Conecta sonidos a todos los botones dentro de un nodo
	if nodo is BaseButton:
		_conectar_boton(nodo)
	for hijo in nodo.get_children():
		_conectar_botones_recursivo(hijo)

func _conectar_boton(boton: BaseButton) -> void:
	## Conecta hover y click a un botón individual (Button y TextureButton)
	if not is_instance_valid(boton):
		return
	# Evitar doble conexión
	if not boton.mouse_entered.is_connected(_on_boton_hover):
		boton.mouse_entered.connect(_on_boton_hover)
	if not boton.pressed.is_connected(_on_boton_pressed.bind(boton)):
		boton.pressed.connect(_on_boton_pressed.bind(boton))

func _on_boton_hover() -> void:
	reproducir("hover")

func _on_boton_pressed(boton: BaseButton) -> void:
	## Decide qué sonido reproducir según el tipo de botón
	if not is_instance_valid(boton):
		reproducir("click")
		return

	var nombre_boton := boton.name as String

	# Botones de flechas de reglas (vida/puntos)
	if nombre_boton in BOTONES_FLECHA_REGLAS:
		reproducir("flecha_reglas")
		return

	# Botones de cambiar personaje
	if nombre_boton in BOTONES_CAMBIAR_PERSONAJE:
		reproducir("cambiar_personaje")
		return

	# Botón de salir del juego
	if nombre_boton == "BtnSalir" and get_tree().current_scene and get_tree().current_scene.name == "MenuInicio":
		reproducir("cerrar_juego")
		return

	# Todos los demás botones → click genérico
	reproducir("click")
