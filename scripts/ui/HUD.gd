extends CanvasLayer

const BARRA_VIDA_TEXTURE: Texture2D = preload("res://assets/sprites/HUD/hud_barra_vida.png")
const ESTRELLA_TEXTURE: Texture2D = preload("res://assets/sprites/HUD/hud_estrella_pvictoria.png")

const MAX_BARRAS_VISIBLES: int = 10
const MAX_ESTRELLAS_VISIBLES: int = 20
const MAX_ESTRELLAS_POR_FILA: int = 10

@export_group("Paneles")
@export var panel_ancho: int = 300
@export var panel_alto: int = 80

@export_group("Márgenes (posición)")
@export var margen_superior: int = 8
@export var margen_lateral: int = 8

@export_group("Iconos")
@export var tamano_barra_vida: int = 18
@export var separacion_vida: int = -3
@export var tamano_estrella: int = 14
@export var tamano_zona_municion: int = 40
@export var fuente_municion: int = 13

@export_group("Munición (posición)")
@export var municion_offset_j1: Vector2 = Vector2(0.0, 0.0)
@export var municion_offset_j2: Vector2 = Vector2(0.0, 0.0)

@onready var _barras_j1: HBoxContainer = $MarginContainer/HBoxTop/PanelJ1/ContenidoJ1/DatosJ1/FilaPV_J1/BarrasVida_J1
@onready var _barras_j2: HBoxContainer = $MarginContainer/HBoxTop/PanelJ2/ContenidoJ2/DatosJ2/FilaPV_J2/BarrasVida_J2

@onready var _filas_ps_j1: VBoxContainer = $MarginContainer/HBoxTop/PanelJ1/ContenidoJ1/DatosJ1/FilaPS_J1/FilasPS_J1
@onready var _filas_ps_j2: VBoxContainer = $MarginContainer/HBoxTop/PanelJ2/ContenidoJ2/DatosJ2/FilaPS_J2/FilasPS_J2

@onready var _zona_j1: Control     = $MarginContainer/HBoxTop/PanelJ1/ZonaMunicion_J1
@onready var _zona_j2: Control     = $MarginContainer/HBoxTop/PanelJ2/ZonaMunicion_J2
@onready var _infinito_j1: TextureRect = $MarginContainer/HBoxTop/PanelJ1/ZonaMunicion_J1/InfinitoJ1
@onready var _infinito_j2: TextureRect = $MarginContainer/HBoxTop/PanelJ2/ZonaMunicion_J2/InfinitoJ2
@onready var _balas_j1: Label = $MarginContainer/HBoxTop/PanelJ1/ZonaMunicion_J1/LabelBalas_J1
@onready var _balas_j2: Label = $MarginContainer/HBoxTop/PanelJ2/ZonaMunicion_J2/LabelBalas_J2

var _arma_j1: Node2D = null
var _arma_j2: Node2D = null
var _pos_base_zona_j1: Vector2
var _pos_base_zona_j2: Vector2

# Inicializa el HUD con vida, puntos y municion
func _ready() -> void:
	_pos_base_zona_j1 = _zona_j1.position
	_pos_base_zona_j2 = _zona_j2.position

	_aplicar_configuracion()

	Global.puntuacion_cambiada.connect(_on_puntuacion_cambiada)

	_actualizar_estrellas_ps(1, Global.obtener_puntuacion(1))
	_actualizar_estrellas_ps(2, Global.obtener_puntuacion(2))

	_actualizar_barras_vida(1, Global.vida_maxima)
	_actualizar_barras_vida(2, Global.vida_maxima)

	_actualizar_municion(1, 0, 0)
	_actualizar_municion(2, 0, 0)

	call_deferred("_conectar_jugadores")

# Aplica las variables export a los nodos de la escena
func _aplicar_configuracion() -> void:
	var panel_j1 := $MarginContainer/HBoxTop/PanelJ1 as Control
	var panel_j2 := $MarginContainer/HBoxTop/PanelJ2 as Control
	if panel_j1:
		panel_j1.custom_minimum_size = Vector2(panel_ancho, panel_alto)
	if panel_j2:
		panel_j2.custom_minimum_size = Vector2(panel_ancho, panel_alto)

	var margin := $MarginContainer as MarginContainer
	if margin:
		margin.add_theme_constant_override("margin_top",    margen_superior)
		margin.add_theme_constant_override("margin_left",   margen_lateral)
		margin.add_theme_constant_override("margin_right",  margen_lateral)
		margin.add_theme_constant_override("margin_bottom", 0)

	if _barras_j1:
		_barras_j1.add_theme_constant_override("separation", 0)
	if _barras_j2:
		_barras_j2.add_theme_constant_override("separation", 0)

	if _zona_j1:
		_zona_j1.position = _pos_base_zona_j1 + municion_offset_j1
		_zona_j1.size = Vector2(tamano_zona_municion, tamano_zona_municion)
	if _zona_j2:
		_zona_j2.position = _pos_base_zona_j2 + municion_offset_j2
		_zona_j2.size = Vector2(tamano_zona_municion, tamano_zona_municion)

	if _balas_j1:
		_balas_j1.add_theme_font_size_override("font_size", fuente_municion)
	if _balas_j2:
		_balas_j2.add_theme_font_size_override("font_size", fuente_municion)

# Busca y conecta senales de los jugadores en el arbol
func _conectar_jugadores() -> void:
	for nodo in get_tree().get_nodes_in_group("jugadores"):
		if nodo is CharacterBody2D and "player_id" in nodo:
			_conectar_senales_jugador(nodo)

# Conecta senales de vida y arma de un jugador
func _conectar_senales_jugador(personaje: CharacterBody2D) -> void:
	var pid: int = personaje.player_id

	if personaje.has_signal("vida_cambiada"):
		if not personaje.vida_cambiada.is_connected(_on_vida_cambiada.bind(pid)):
			personaje.vida_cambiada.connect(_on_vida_cambiada.bind(pid))
		_actualizar_barras_vida(pid, personaje.obtener_vida())

	if personaje.has_signal("arma_equipada"):
		if not personaje.arma_equipada.is_connected(_on_arma_equipada.bind(pid)):
			personaje.arma_equipada.connect(_on_arma_equipada.bind(pid))

	if personaje.has_signal("arma_desequipada"):
		if not personaje.arma_desequipada.is_connected(_on_arma_desequipada.bind(pid)):
			personaje.arma_desequipada.connect(_on_arma_desequipada.bind(pid))

# Callback de cambio de puntuacion
func _on_puntuacion_cambiada(id_jugador: int, nueva_puntuacion: int) -> void:
	_actualizar_estrellas_ps(id_jugador, nueva_puntuacion)

# Actualiza las estrellas de puntos de un jugador
func _actualizar_estrellas_ps(id_jugador: int, puntos: int) -> void:
	var contenedor: VBoxContainer = _filas_ps_j1 if id_jugador == 1 else _filas_ps_j2
	_rellenar_iconos_multifila(contenedor, puntos, Global.puntos_ganar,
		ESTRELLA_TEXTURE, tamano_estrella, MAX_ESTRELLAS_VISIBLES, MAX_ESTRELLAS_POR_FILA)

# Callback de cambio de vida
func _on_vida_cambiada(nueva_vida: int, id_jugador: int) -> void:
	_actualizar_barras_vida(id_jugador, nueva_vida)

# Actualiza las barras de vida de un jugador
func _actualizar_barras_vida(id_jugador: int, vida: int) -> void:
	var contenedor: HBoxContainer = _barras_j1 if id_jugador == 1 else _barras_j2
	_rellenar_iconos(contenedor, vida, Global.vida_maxima, BARRA_VIDA_TEXTURE, tamano_barra_vida, MAX_BARRAS_VISIBLES, separacion_vida)

# Conecta senal de municion al equipar un arma
func _on_arma_equipada(arma: Node2D, id_jugador: int) -> void:
	_desconectar_arma(id_jugador)

	if id_jugador == 1:
		_arma_j1 = arma
	else:
		_arma_j2 = arma

	if arma is ArmaBase:
		if not arma.municion_cambiada.is_connected(_on_municion_cambiada.bind(id_jugador)):
			arma.municion_cambiada.connect(_on_municion_cambiada.bind(id_jugador))
		arma.emitir_estado_municion()
	else:
		_actualizar_municion(id_jugador, -1, -1)

# Limpia la municion al desequipar un arma
func _on_arma_desequipada(id_jugador: int) -> void:
	_desconectar_arma(id_jugador)
	_actualizar_municion(id_jugador, 0, 0)

# Desconecta la senal de municion del arma anterior
func _desconectar_arma(id_jugador: int) -> void:
	var arma_ref: Node2D = _arma_j1 if id_jugador == 1 else _arma_j2

	if is_instance_valid(arma_ref) and arma_ref is ArmaBase:
		if arma_ref.municion_cambiada.is_connected(_on_municion_cambiada.bind(id_jugador)):
			arma_ref.municion_cambiada.disconnect(_on_municion_cambiada.bind(id_jugador))

	if id_jugador == 1:
		_arma_j1 = null
	else:
		_arma_j2 = null

# Callback de cambio de municion
func _on_municion_cambiada(actual: int, maxima: int, id_jugador: int) -> void:
	_actualizar_municion(id_jugador, actual, maxima)

# Actualiza la zona de municion segun el estado del arma
func _actualizar_municion(id_jugador: int, actual: int, maxima: int) -> void:
	var inf_node: TextureRect = _infinito_j1 if id_jugador == 1 else _infinito_j2
	var label_node: Label = _balas_j1 if id_jugador == 1 else _balas_j2

	if actual == -1:
		inf_node.visible = true
		label_node.visible = false
	elif actual == 0 and maxima == 0:
		inf_node.visible = false
		label_node.visible = false
	else:
		inf_node.visible = false
		label_node.visible = true
		label_node.text = str(actual)

# Rellena iconos en multiples filas para estrellas de puntos
func _rellenar_iconos_multifila(
		contenedor: VBoxContainer,
		cantidad: int,
		maximo: int,
		textura: Texture2D,
		tamano: int,
		limite_maximo: int,
		por_fila: int
) -> void:
	if not contenedor:
		return

	for hijo in contenedor.get_children():
		hijo.queue_free()

	var total_visible: int = mini(maximo, limite_maximo)
	var activos: int = clampi(cantidad, 0, total_visible)

	var fila_actual: HBoxContainer = null
	var iconos_en_fila: int = 0

	for i in total_visible:
		if fila_actual == null or iconos_en_fila >= por_fila:
			fila_actual = HBoxContainer.new()
			fila_actual.add_theme_constant_override("separation", 1)
			fila_actual.mouse_filter = Control.MOUSE_FILTER_IGNORE
			contenedor.add_child(fila_actual)
			iconos_en_fila = 0

		var rect := TextureRect.new()
		rect.texture = textura
		rect.custom_minimum_size = Vector2(tamano, tamano)
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.modulate = Color(1.0, 1.0, 1.0, 1.0) if i < activos else Color(0.25, 0.25, 0.25, 0.45)

		fila_actual.add_child(rect)
		iconos_en_fila += 1

# Rellena iconos en una fila para barras de vida
func _rellenar_iconos(
		contenedor: HBoxContainer,
		cantidad: int,
		maximo: int,
		textura: Texture2D,
		tamano: int,
		limite_maximo: int,
		separacion: int = 0
) -> void:
	if not contenedor:
		return

	for hijo in contenedor.get_children():
		hijo.queue_free()

	var total_visible: int = mini(maximo, limite_maximo)
	var activos: int = clampi(cantidad, 0, total_visible)

	for i in total_visible:
		var rect := TextureRect.new()
		rect.texture = textura
		rect.custom_minimum_size = Vector2(tamano, tamano)
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

		if i < activos:
			rect.modulate = Color(1.0, 0.55, 0.05, 1.0)
		else:
			rect.modulate = Color(0.25, 0.25, 0.25, 0.45)

		if separacion != 0 and i > 0:
			var contenedor_margen := MarginContainer.new()
			contenedor_margen.mouse_filter = Control.MOUSE_FILTER_IGNORE
			contenedor_margen.add_theme_constant_override("margin_left", separacion)
			contenedor_margen.add_theme_constant_override("margin_right", 0)
			contenedor_margen.add_theme_constant_override("margin_top", 0)
			contenedor_margen.add_theme_constant_override("margin_bottom", 0)
			contenedor_margen.add_child(rect)
			contenedor.add_child(contenedor_margen)
		else:
			contenedor.add_child(rect)
