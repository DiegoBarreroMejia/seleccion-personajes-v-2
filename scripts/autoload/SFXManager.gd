extends Node

const SONIDOS: Dictionary = {
	"click": preload("res://assets/sonidos/ui/sonido_cuando_pulsas_un_boton.ogg"),
	"hover": preload("res://assets/sonidos/ui/sonido_cuando_pasas_el_raton.ogg"),
	"flecha_reglas": preload("res://assets/sonidos/ui/sonido_cuando_pulsas_un_boton_flecha.ogg"),
	"cambiar_personaje": preload("res://assets/sonidos/ui/sonido_para_botones_cambiar_personaje.ogg"),
	"cerrar_juego": preload("res://assets/sonidos/ui/sonido_cuando_cierras_juego.ogg"),
}

const BOTONES_FLECHA_REGLAS: Array[String] = [
	"BtnVidaMas", "BtnVidaMenos", "BtnPuntosMas", "BtnPuntosMenos"
]

const BOTONES_CAMBIAR_PERSONAJE: Array[String] = [
	"anterior_p1", "siguiente_p1", "anterior_p2", "siguiente_p2"
]

var _player: AudioStreamPlayer

# Crea reproductor y conecta deteccion de nodos nuevos
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	_player = AudioStreamPlayer.new()
	_player.process_mode = Node.PROCESS_MODE_ALWAYS
	_player.bus = "SFX"
	add_child(_player)

	get_tree().node_added.connect(_on_nodo_agregado)

	await get_tree().process_frame
	await get_tree().process_frame

	cambiar_volumen(ConfigManager.volumen_sfx)
	_escanear_escena_actual()

# Reproduce un sonido de UI por nombre
func reproducir(nombre_sonido: String) -> void:
	if nombre_sonido not in SONIDOS:
		push_warning("SFXManager: Sonido desconocido: %s" % nombre_sonido)
		return
	_player.stream = SONIDOS[nombre_sonido]
	_player.play()

# Cambia el volumen del bus SFX
func cambiar_volumen(valor: float) -> void:
	valor = clampf(valor, 0.0, 1.0)
	var bus_idx := AudioServer.get_bus_index("SFX")
	if bus_idx >= 0:
		if valor <= 0.0:
			AudioServer.set_bus_volume_db(bus_idx, -80.0)
		else:
			AudioServer.set_bus_volume_db(bus_idx, linear_to_db(valor))

# Escanea la escena actual y conecta botones
func _escanear_escena_actual() -> void:
	var escena := get_tree().current_scene
	if escena:
		_conectar_botones_recursivo(escena)

# Conecta sonidos a botones nuevos en el arbol
func _on_nodo_agregado(nodo: Node) -> void:
	if nodo is BaseButton:
		_conectar_boton.call_deferred(nodo)

# Conecta sonidos recursivamente a todos los botones de un nodo
func _conectar_botones_recursivo(nodo: Node) -> void:
	if nodo is BaseButton:
		_conectar_boton(nodo)
	for hijo in nodo.get_children():
		_conectar_botones_recursivo(hijo)

# Conecta hover y click a un boton individual
func _conectar_boton(boton: BaseButton) -> void:
	if not is_instance_valid(boton):
		return
	if not boton.mouse_entered.is_connected(_on_boton_hover):
		boton.mouse_entered.connect(_on_boton_hover)
	if not boton.pressed.is_connected(_on_boton_pressed.bind(boton)):
		boton.pressed.connect(_on_boton_pressed.bind(boton))

# Reproduce sonido de hover
func _on_boton_hover() -> void:
	reproducir("hover")

# Decide que sonido reproducir segun el tipo de boton
func _on_boton_pressed(boton: BaseButton) -> void:
	if not is_instance_valid(boton):
		reproducir("click")
		return

	var nombre_boton := boton.name as String

	if nombre_boton in BOTONES_FLECHA_REGLAS:
		reproducir("flecha_reglas")
		return

	if nombre_boton in BOTONES_CAMBIAR_PERSONAJE:
		reproducir("cambiar_personaje")
		return

	if nombre_boton == "BtnSalir" and get_tree().current_scene and get_tree().current_scene.name == "MenuInicio":
		reproducir("cerrar_juego")
		return

	reproducir("click")
