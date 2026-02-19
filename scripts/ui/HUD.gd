extends CanvasLayer

## HUD del juego - Muestra vida (barras), puntos (estrellas) y munición de cada jugador
##
## PV (fila superior del panel): N copias de hud_barra_vida.png según vida actual
## PS (fila inferior del panel): N estrellas hud_estrella_pvictoria.png según puntos ganados
## Zona munición (posición libre dentro del panel):
##   - Sin arma      → vacío
##   - Arma infinita → hud_infinito.png
##   - Arma con balas→ número de balas restantes
##
## Todas las variables de tamaño y posición son @export:
## selecciona el nodo HUD en el Inspector para ajustarlas sin tocar código.

# === PRECARGAS ===
const BARRA_VIDA_TEXTURE: Texture2D = preload("res://assets/sprites/HUD/hud_barra_vida.png")
const ESTRELLA_TEXTURE: Texture2D = preload("res://assets/sprites/HUD/hud_estrella_pvictoria.png")

# === MÁXIMOS VISIBLES (fijos por diseño) ===
const MAX_BARRAS_VISIBLES: int = 10      # vida máxima es 10
const MAX_ESTRELLAS_VISIBLES: int = 20   # puntos máximos son 20
const MAX_ESTRELLAS_POR_FILA: int = 10   # a partir de 11 estrellas, nueva fila

# ============================================================
# VARIABLES EXPORTADAS — ajustables desde el Inspector
# ============================================================

@export_group("Paneles")
## Ancho de cada panel (J1 y J2) en píxeles
@export var panel_ancho: int = 300
## Alto de cada panel (J1 y J2) en píxeles
@export var panel_alto: int = 80

@export_group("Márgenes (posición)")
## Distancia desde el borde superior de la pantalla
@export var margen_superior: int = 8
## Distancia desde los bordes izquierdo y derecho de la pantalla
@export var margen_lateral: int = 8

@export_group("Iconos")
## Tamaño en píxeles de cada barra de vida (hud_barra_vida.png)
@export var tamano_barra_vida: int = 18
## Separación en px entre barras de vida. 0 = pegadas, negativo = se solapan
@export var separacion_vida: int = -3
## Tamaño en píxeles de cada estrella de puntos (hud_estrella_pvictoria.png)
@export var tamano_estrella: int = 14
## Tamaño de la zona de munición (donde aparece ∞ o el número de balas)
@export var tamano_zona_municion: int = 40
## Tamaño de fuente del número de balas
@export var fuente_municion: int = 13

@export_group("Munición (posición)")
## Desplazamiento X/Y de la zona de munición en J1.
## Posición base: esquina derecha del panel. Usa X negativo para ir a la izquierda.
@export var municion_offset_j1: Vector2 = Vector2(0.0, 0.0)
## Desplazamiento X/Y de la zona de munición en J2.
## Posición base: esquina derecha del panel. Usa X negativo para ir a la izquierda.
@export var municion_offset_j2: Vector2 = Vector2(0.0, 0.0)

# ============================================================
# NODOS — VIDA (PV)
# ============================================================
@onready var _barras_j1: HBoxContainer = $MarginContainer/HBoxTop/PanelJ1/ContenidoJ1/DatosJ1/FilaPV_J1/BarrasVida_J1
@onready var _barras_j2: HBoxContainer = $MarginContainer/HBoxTop/PanelJ2/ContenidoJ2/DatosJ2/FilaPV_J2/BarrasVida_J2

# ============================================================
# NODOS — PUNTOS (PS)
# ============================================================
@onready var _filas_ps_j1: VBoxContainer = $MarginContainer/HBoxTop/PanelJ1/ContenidoJ1/DatosJ1/FilaPS_J1/FilasPS_J1
@onready var _filas_ps_j2: VBoxContainer = $MarginContainer/HBoxTop/PanelJ2/ContenidoJ2/DatosJ2/FilaPS_J2/FilasPS_J2

# ============================================================
# NODOS — MUNICIÓN (ahora hijos directos de PanelJ1/J2)
# ============================================================
@onready var _zona_j1: Control     = $MarginContainer/HBoxTop/PanelJ1/ZonaMunicion_J1
@onready var _zona_j2: Control     = $MarginContainer/HBoxTop/PanelJ2/ZonaMunicion_J2
@onready var _infinito_j1: TextureRect = $MarginContainer/HBoxTop/PanelJ1/ZonaMunicion_J1/InfinitoJ1
@onready var _infinito_j2: TextureRect = $MarginContainer/HBoxTop/PanelJ2/ZonaMunicion_J2/InfinitoJ2
@onready var _balas_j1: Label = $MarginContainer/HBoxTop/PanelJ1/ZonaMunicion_J1/LabelBalas_J1
@onready var _balas_j2: Label = $MarginContainer/HBoxTop/PanelJ2/ZonaMunicion_J2/LabelBalas_J2

# === ESTADO INTERNO ===
var _arma_j1: Node2D = null
var _arma_j2: Node2D = null
var _pos_base_zona_j1: Vector2  # posición del nodo tal como está en el editor (.tscn)
var _pos_base_zona_j2: Vector2

# ============================================================
# CICLO DE VIDA
# ============================================================

func _ready() -> void:
	# Guardar la posición que tiene cada zona en el editor ANTES de que _aplicar_configuracion() la modifique
	_pos_base_zona_j1 = _zona_j1.position
	_pos_base_zona_j2 = _zona_j2.position

	# Aplicar valores exportados a los nodos de la escena
	_aplicar_configuracion()

	Global.puntuacion_cambiada.connect(_on_puntuacion_cambiada)

	# PS: mostrar puntos actuales (normalmente 0 al empezar)
	_actualizar_estrellas_ps(1, Global.obtener_puntuacion(1))
	_actualizar_estrellas_ps(2, Global.obtener_puntuacion(2))

	# PV: mostrar vida máxima (los personajes aún no existen, se actualizará al conectarlos)
	_actualizar_barras_vida(1, Global.vida_maxima)
	_actualizar_barras_vida(2, Global.vida_maxima)

	# Munición: vacío al inicio
	_actualizar_municion(1, 0, 0)
	_actualizar_municion(2, 0, 0)

	# Conectar señales de los personajes cuando estén en el árbol
	call_deferred("_conectar_jugadores")

## Aplica las variables @export a los nodos de la escena.
## Se llama al inicio de _ready() para que los valores del Inspector
## tengan efecto en tiempo de ejecución.
func _aplicar_configuracion() -> void:
	# --- Tamaño de los paneles ---
	var panel_j1 := $MarginContainer/HBoxTop/PanelJ1 as Control
	var panel_j2 := $MarginContainer/HBoxTop/PanelJ2 as Control
	if panel_j1:
		panel_j1.custom_minimum_size = Vector2(panel_ancho, panel_alto)
	if panel_j2:
		panel_j2.custom_minimum_size = Vector2(panel_ancho, panel_alto)

	# --- Márgenes (posición desde los bordes) ---
	var margin := $MarginContainer as MarginContainer
	if margin:
		margin.add_theme_constant_override("margin_top",    margen_superior)
		margin.add_theme_constant_override("margin_left",   margen_lateral)
		margin.add_theme_constant_override("margin_right",  margen_lateral)
		margin.add_theme_constant_override("margin_bottom", 0)

	# --- Separación entre barras de vida ---
	# HBoxContainer.separation no acepta negativos, así que se aplica
	# margin_left a cada icono en _rellenar_iconos() usando separacion_vida directamente.
	# Forzamos separation=0 para que no sume espacio extra.
	if _barras_j1:
		_barras_j1.add_theme_constant_override("separation", 0)
	if _barras_j2:
		_barras_j2.add_theme_constant_override("separation", 0)

	# --- Posición y tamaño de la zona de munición ---
	# Se usa la posición guardada del editor (offset del .tscn) + el offset del Inspector.
	# Así mover el nodo en el editor tiene efecto real en runtime.
	if _zona_j1:
		_zona_j1.position = _pos_base_zona_j1 + municion_offset_j1
		_zona_j1.size = Vector2(tamano_zona_municion, tamano_zona_municion)
	if _zona_j2:
		_zona_j2.position = _pos_base_zona_j2 + municion_offset_j2
		_zona_j2.size = Vector2(tamano_zona_municion, tamano_zona_municion)

	# --- Fuente del número de balas ---
	if _balas_j1:
		_balas_j1.add_theme_font_size_override("font_size", fuente_municion)
	if _balas_j2:
		_balas_j2.add_theme_font_size_override("font_size", fuente_municion)

func _conectar_jugadores() -> void:
	for nodo in get_tree().get_nodes_in_group("jugadores"):
		if nodo is CharacterBody2D and "player_id" in nodo:
			_conectar_senales_jugador(nodo)

func _conectar_senales_jugador(personaje: CharacterBody2D) -> void:
	var pid: int = personaje.player_id

	if personaje.has_signal("vida_cambiada"):
		if not personaje.vida_cambiada.is_connected(_on_vida_cambiada.bind(pid)):
			personaje.vida_cambiada.connect(_on_vida_cambiada.bind(pid))
		# Actualizar inmediatamente con la vida actual del personaje
		_actualizar_barras_vida(pid, personaje.obtener_vida())

	if personaje.has_signal("arma_equipada"):
		if not personaje.arma_equipada.is_connected(_on_arma_equipada.bind(pid)):
			personaje.arma_equipada.connect(_on_arma_equipada.bind(pid))

	if personaje.has_signal("arma_desequipada"):
		if not personaje.arma_desequipada.is_connected(_on_arma_desequipada.bind(pid)):
			personaje.arma_desequipada.connect(_on_arma_desequipada.bind(pid))

# ============================================================
# PUNTUACIÓN (PS)
# ============================================================

func _on_puntuacion_cambiada(id_jugador: int, nueva_puntuacion: int) -> void:
	_actualizar_estrellas_ps(id_jugador, nueva_puntuacion)

func _actualizar_estrellas_ps(id_jugador: int, puntos: int) -> void:
	var contenedor: VBoxContainer = _filas_ps_j1 if id_jugador == 1 else _filas_ps_j2
	_rellenar_iconos_multifila(contenedor, puntos, Global.puntos_ganar,
		ESTRELLA_TEXTURE, tamano_estrella, MAX_ESTRELLAS_VISIBLES, MAX_ESTRELLAS_POR_FILA)

# ============================================================
# VIDA (PV)
# ============================================================

func _on_vida_cambiada(nueva_vida: int, id_jugador: int) -> void:
	_actualizar_barras_vida(id_jugador, nueva_vida)

func _actualizar_barras_vida(id_jugador: int, vida: int) -> void:
	var contenedor: HBoxContainer = _barras_j1 if id_jugador == 1 else _barras_j2
	_rellenar_iconos(contenedor, vida, Global.vida_maxima, BARRA_VIDA_TEXTURE, tamano_barra_vida, MAX_BARRAS_VISIBLES, separacion_vida)

# ============================================================
# MUNICIÓN
# ============================================================

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
		# Arma melee: munición infinita → mostrar ∞
		_actualizar_municion(id_jugador, -1, -1)

func _on_arma_desequipada(id_jugador: int) -> void:
	_desconectar_arma(id_jugador)
	_actualizar_municion(id_jugador, 0, 0)

func _desconectar_arma(id_jugador: int) -> void:
	var arma_ref: Node2D = _arma_j1 if id_jugador == 1 else _arma_j2

	if is_instance_valid(arma_ref) and arma_ref is ArmaBase:
		if arma_ref.municion_cambiada.is_connected(_on_municion_cambiada.bind(id_jugador)):
			arma_ref.municion_cambiada.disconnect(_on_municion_cambiada.bind(id_jugador))

	if id_jugador == 1:
		_arma_j1 = null
	else:
		_arma_j2 = null

func _on_municion_cambiada(actual: int, maxima: int, id_jugador: int) -> void:
	_actualizar_municion(id_jugador, actual, maxima)

func _actualizar_municion(id_jugador: int, actual: int, maxima: int) -> void:
	var inf_node: TextureRect = _infinito_j1 if id_jugador == 1 else _infinito_j2
	var label_node: Label = _balas_j1 if id_jugador == 1 else _balas_j2

	if actual == -1:
		# Munición infinita → mostrar icono ∞
		inf_node.visible = true
		label_node.visible = false
	elif actual == 0 and maxima == 0:
		# Sin arma equipada → zona vacía
		inf_node.visible = false
		label_node.visible = false
	else:
		# Balas finitas → mostrar número de balas restantes
		inf_node.visible = false
		label_node.visible = true
		label_node.text = str(actual)

# ============================================================
# HELPER: rellenar iconos en múltiples filas (PS)
# ============================================================

## Vacía el VBoxContainer y lo rellena con filas de HBoxContainer,
## poniendo hasta 'por_fila' iconos por fila.
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
		# Activas: color original del sprite. Inactivas: gris semitransparente.
		rect.modulate = Color(1.0, 1.0, 1.0, 1.0) if i < activos else Color(0.25, 0.25, 0.25, 0.45)

		fila_actual.add_child(rect)
		iconos_en_fila += 1

# ============================================================
# HELPER: rellenar iconos en una sola fila (PV)
# ============================================================

## Vacía el contenedor y lo rellena con iconos del sprite dado.
## Los primeros 'cantidad' se muestran en naranja (activos),
## el resto en gris oscuro (inactivos).
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

		# Para separación distinta de 0, envolver en MarginContainer con margin_left.
		# Funciona tanto para valores positivos (más espacio) como negativos (solapado).
		# El primer icono (i==0) no lleva margen extra.
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
