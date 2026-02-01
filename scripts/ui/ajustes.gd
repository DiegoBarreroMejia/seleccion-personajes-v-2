extends Control

## Pantalla de ajustes del juego
##
## Permite configurar:
## - Video: resolución y modo de pantalla
## - Controles: reasignación de teclas para ambos jugadores

# === CONSTANTES ===
const RUTA_MENU_INICIO: String = "res://scenes/ui/MenuInicio.tscn"

# === VARIABLES ===
var _esperando_tecla: bool = false
var _accion_a_reasignar: String = ""
var _boton_esperando: Button = null

# === NODOS - PESTAÑAS ===
@onready var _btn_tab_video: Button = $ContenedorPrincipal/Pestanas/BtnVideo
@onready var _btn_tab_controles: Button = $ContenedorPrincipal/Pestanas/BtnControles
@onready var _contenedor_video: VBoxContainer = $ContenedorPrincipal/ContenedorVideo
@onready var _contenedor_controles: HBoxContainer = $ContenedorPrincipal/ContenedorControles

# === NODOS - VIDEO ===
@onready var _option_resolucion: OptionButton = $ContenedorPrincipal/ContenedorVideo/FilaResolucion/OptionResolucion
@onready var _check_pantalla_completa: CheckButton = $ContenedorPrincipal/ContenedorVideo/FilaPantalla/CheckPantallaCompleta

# === NODOS - CONTROLES ===
@onready var _grid_j1: GridContainer = $ContenedorPrincipal/ContenedorControles/PanelJ1/GridJ1
@onready var _grid_j2: GridContainer = $ContenedorPrincipal/ContenedorControles/PanelJ2/GridJ2

# === MÉTODOS DE CICLO DE VIDA ===

func _ready() -> void:
	ConfigManager.inicializar_pendientes()
	_configurar_pestanas()
	_configurar_opciones_video()
	_configurar_controles()
	_mostrar_tab_video()

func _input(event: InputEvent) -> void:
	if not _esperando_tecla:
		return

	if event is InputEventKey and event.pressed:
		_procesar_nueva_tecla(event)
		get_viewport().set_input_as_handled()

# === CONFIGURACIÓN INICIAL ===

func _configurar_pestanas() -> void:
	_btn_tab_video.pressed.connect(_mostrar_tab_video)
	_btn_tab_controles.pressed.connect(_mostrar_tab_controles)

func _configurar_opciones_video() -> void:
	# Llenar opciones de resolución
	_option_resolucion.clear()
	for res in ConfigManager.RESOLUCIONES:
		_option_resolucion.add_item("%dx%d" % [res.x, res.y])

	# Seleccionar resolución pendiente (igual a actual al iniciar)
	_option_resolucion.selected = ConfigManager.obtener_indice_resolucion_pendiente()

	# Configurar checkbox de pantalla completa con valor pendiente
	_check_pantalla_completa.button_pressed = ConfigManager.obtener_pantalla_completa_pendiente()

	# Conectar señales
	_option_resolucion.item_selected.connect(_on_resolucion_seleccionada)
	_check_pantalla_completa.toggled.connect(_on_pantalla_completa_cambiada)

func _configurar_controles() -> void:
	_crear_botones_control(_grid_j1, ConfigManager.ACCIONES_J1)
	_crear_botones_control(_grid_j2, ConfigManager.ACCIONES_J2)

func _crear_botones_control(grid: GridContainer, acciones: Array[String]) -> void:
	# Limpiar grid (excepto headers si los hay)
	for child in grid.get_children():
		child.queue_free()

	# Esperar un frame para que se limpien
	await get_tree().process_frame

	for accion in acciones:
		# Label con nombre de la acción
		var label := Label.new()
		label.text = ConfigManager.obtener_nombre_accion(accion) + ":"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		label.custom_minimum_size = Vector2(80, 0)
		grid.add_child(label)

		# Botón para reasignar
		var boton := Button.new()
		boton.text = ConfigManager.obtener_tecla_accion(accion)
		boton.custom_minimum_size = Vector2(100, 35)
		boton.pressed.connect(_on_boton_control_presionado.bind(accion, boton))
		grid.add_child(boton)

# === NAVEGACIÓN DE PESTAÑAS ===

func _mostrar_tab_video() -> void:
	_contenedor_video.visible = true
	_contenedor_controles.visible = false
	_btn_tab_video.disabled = true
	_btn_tab_controles.disabled = false

func _mostrar_tab_controles() -> void:
	_contenedor_video.visible = false
	_contenedor_controles.visible = true
	_btn_tab_video.disabled = false
	_btn_tab_controles.disabled = true

# === CALLBACKS VIDEO ===

func _on_resolucion_seleccionada(indice: int) -> void:
	var nueva_res := ConfigManager.RESOLUCIONES[indice]
	ConfigManager.establecer_resolucion_pendiente(nueva_res)

func _on_pantalla_completa_cambiada(activada: bool) -> void:
	ConfigManager.establecer_pantalla_completa_pendiente(activada)

# === CALLBACKS CONTROLES ===

func _on_boton_control_presionado(accion: String, boton: Button) -> void:
	if _esperando_tecla:
		_cancelar_espera_tecla()

	_esperando_tecla = true
	_accion_a_reasignar = accion
	_boton_esperando = boton
	boton.text = "..."

func _procesar_nueva_tecla(evento: InputEventKey) -> void:
	# Cancelar con Escape
	if evento.physical_keycode == KEY_ESCAPE:
		_cancelar_espera_tecla()
		return

	# Intentar reasignar
	var exito := ConfigManager.reasignar_control(_accion_a_reasignar, evento)

	if exito:
		_boton_esperando.text = ConfigManager.obtener_tecla_accion(_accion_a_reasignar)
	else:
		# Mostrar tecla actual si falló (tecla ya en uso)
		_boton_esperando.text = ConfigManager.obtener_tecla_accion(_accion_a_reasignar)
		# Feedback visual de error (parpadeo rojo)
		_mostrar_error_boton(_boton_esperando)

	_esperando_tecla = false
	_accion_a_reasignar = ""
	_boton_esperando = null

func _cancelar_espera_tecla() -> void:
	if _boton_esperando:
		_boton_esperando.text = ConfigManager.obtener_tecla_accion(_accion_a_reasignar)

	_esperando_tecla = false
	_accion_a_reasignar = ""
	_boton_esperando = null

func _mostrar_error_boton(boton: Button) -> void:
	var color_original := boton.modulate
	boton.modulate = Color.RED
	await get_tree().create_timer(0.3).timeout
	if is_instance_valid(boton):
		boton.modulate = color_original

# === CALLBACKS BOTONES PRINCIPALES ===

func _on_btn_restablecer_pressed() -> void:
	ConfigManager.restablecer_controles()
	# Actualizar UI
	_actualizar_botones_controles()

func _on_btn_aplicar_pressed() -> void:
	ConfigManager.aplicar_cambios_video()

func _on_btn_volver_pressed() -> void:
	if _esperando_tecla:
		_cancelar_espera_tecla()
	# Descartar cambios de video no aplicados
	ConfigManager.descartar_cambios_video()
	get_tree().change_scene_to_file(RUTA_MENU_INICIO)

# === UTILIDADES ===

func _actualizar_botones_controles() -> void:
	_actualizar_grid_controles(_grid_j1, ConfigManager.ACCIONES_J1)
	_actualizar_grid_controles(_grid_j2, ConfigManager.ACCIONES_J2)

func _actualizar_grid_controles(grid: GridContainer, acciones: Array[String]) -> void:
	var botones := grid.get_children().filter(func(n): return n is Button)
	for i in range(min(botones.size(), acciones.size())):
		var boton := botones[i] as Button
		boton.text = ConfigManager.obtener_tecla_accion(acciones[i])
