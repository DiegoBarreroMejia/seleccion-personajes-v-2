extends Control

## Pantalla de ajustes del juego
##
## Permite configurar:
## - Video: resolución y modo de pantalla
## - Controles: reasignación de teclas para ambos jugadores

# === CONSTANTES ===
const RUTA_MENU_INICIO: String = "res://scenes/ui/MenuInicio.tscn"
const FUENTE_PRINCIPAL: Font = preload("res://assets/fonts/PressStart2P-Regular.ttf")

# === VARIABLES ESTÁTICAS (se asignan ANTES de instanciar/navegar a Ajustes) ===
## Ruta de la escena a la que volver. Se ignora si es_overlay es true.
static var escena_origen: String = "res://scenes/ui/MenuInicio.tscn"
## Si true, Ajustes fue instanciado como overlay (ej: desde pausa). Al volver se destruye.
static var es_overlay: bool = false

# === VARIABLES ===
var _esperando_tecla: bool = false
var _accion_a_reasignar: String = ""
var _boton_esperando: Button = null
var _tab_actual: String = "video"  ## Pestaña activa: "video", "controles", "sonido"

# === NODOS - PESTAÑAS ===
@onready var _btn_tab_video: Button = $ContenedorPrincipal/Pestanas/BtnVideo
@onready var _btn_tab_controles: Button = $ContenedorPrincipal/Pestanas/BtnControles
@onready var _btn_tab_sonido: Button = $ContenedorPrincipal/Pestanas/BtnSonido
@onready var _contenedor_video: VBoxContainer = $ContenedorPrincipal/ContenedorVideo
@onready var _contenedor_controles: HBoxContainer = $ContenedorPrincipal/ContenedorControles
@onready var _contenedor_sonido: VBoxContainer = $ContenedorPrincipal/ContenedorSonido

# === NODOS - VIDEO ===
@onready var _option_resolucion: OptionButton = $ContenedorPrincipal/ContenedorVideo/FilaResolucion/OptionResolucion
@onready var _check_pantalla_completa: CheckButton = $ContenedorPrincipal/ContenedorVideo/FilaPantalla/CheckPantallaCompleta

# === NODOS - CONTROLES ===
@onready var _grid_j1: GridContainer = $ContenedorPrincipal/ContenedorControles/PanelJ1/GridJ1
@onready var _grid_j2: GridContainer = $ContenedorPrincipal/ContenedorControles/PanelJ2/GridJ2

# === NODOS - SONIDO ===
@onready var _option_musica: OptionButton = $ContenedorPrincipal/ContenedorSonido/FilaMusica/OptionMusica
@onready var _slider_volumen: HSlider = $ContenedorPrincipal/ContenedorSonido/FilaVolumen/SliderVolumen
@onready var _slider_volumen_sfx: HSlider = $ContenedorPrincipal/ContenedorSonido/FilaVolumenSFX/SliderVolumenSFX

# === MÉTODOS DE CICLO DE VIDA ===

func _ready() -> void:
	ConfigManager.inicializar_pendientes()
	_configurar_pestanas()
	_configurar_opciones_video()
	_configurar_controles()
	_configurar_opciones_sonido()
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
	_btn_tab_sonido.pressed.connect(_mostrar_tab_sonido)

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

func _configurar_opciones_sonido() -> void:
	# Llenar opciones de soundtrack
	_option_musica.clear()
	var nombres := MusicManager.obtener_nombres_soundtracks()
	for nombre in nombres:
		_option_musica.add_item(nombre)

	# Seleccionar el soundtrack actual
	_option_musica.selected = ConfigManager.soundtrack_seleccionado

	# Configurar slider de volumen música (0 a 100)
	_slider_volumen.min_value = 0
	_slider_volumen.max_value = 100
	_slider_volumen.step = 1
	_slider_volumen.value = ConfigManager.volumen_musica * 100.0

	# Configurar slider de volumen SFX (0 a 100)
	_slider_volumen_sfx.min_value = 0
	_slider_volumen_sfx.max_value = 100
	_slider_volumen_sfx.step = 1
	_slider_volumen_sfx.value = ConfigManager.volumen_sfx * 100.0

	# Conectar señales
	_option_musica.item_selected.connect(_on_musica_seleccionada)
	_slider_volumen.value_changed.connect(_on_volumen_cambiado)
	_slider_volumen_sfx.value_changed.connect(_on_volumen_sfx_cambiado)

func _crear_botones_control(grid: GridContainer, acciones: Array[String]) -> void:
	# Limpiar grid (excepto headers si los hay)
	for child in grid.get_children():
		child.queue_free()

	# Esperar un frame para que se limpien
	await get_tree().process_frame

	# Verificar que seguimos en el árbol después del await
	if not is_inside_tree():
		return

	for accion in acciones:
		# Label con nombre de la acción
		var label := Label.new()
		label.text = ConfigManager.obtener_nombre_accion(accion) + ":"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		label.custom_minimum_size = Vector2(80, 0)
		label.add_theme_font_override("font", FUENTE_PRINCIPAL)
		grid.add_child(label)

		# Botón para reasignar
		var boton := Button.new()
		boton.text = ConfigManager.obtener_tecla_accion(accion)
		boton.custom_minimum_size = Vector2(100, 35)
		boton.add_theme_font_override("font", FUENTE_PRINCIPAL)
		boton.pressed.connect(_on_boton_control_presionado.bind(accion, boton))
		grid.add_child(boton)

# === NAVEGACIÓN DE PESTAÑAS ===

func _mostrar_tab_video() -> void:
	_tab_actual = "video"
	_contenedor_video.visible = true
	_contenedor_controles.visible = false
	_contenedor_sonido.visible = false
	_btn_tab_video.disabled = true
	_btn_tab_controles.disabled = false
	_btn_tab_sonido.disabled = false

func _mostrar_tab_controles() -> void:
	_tab_actual = "controles"
	_contenedor_video.visible = false
	_contenedor_controles.visible = true
	_contenedor_sonido.visible = false
	_btn_tab_video.disabled = false
	_btn_tab_controles.disabled = true
	_btn_tab_sonido.disabled = false

func _mostrar_tab_sonido() -> void:
	_tab_actual = "sonido"
	_contenedor_video.visible = false
	_contenedor_controles.visible = false
	_contenedor_sonido.visible = true
	_btn_tab_video.disabled = false
	_btn_tab_controles.disabled = false
	_btn_tab_sonido.disabled = true

# === CALLBACKS VIDEO ===

func _on_resolucion_seleccionada(indice: int) -> void:
	var nueva_res := ConfigManager.RESOLUCIONES[indice]
	ConfigManager.establecer_resolucion_pendiente(nueva_res)

func _on_pantalla_completa_cambiada(activada: bool) -> void:
	ConfigManager.establecer_pantalla_completa_pendiente(activada)

# === CALLBACKS SONIDO ===

func _on_musica_seleccionada(indice: int) -> void:
	MusicManager.reproducir(indice)
	ConfigManager.cambiar_soundtrack(indice)

func _on_volumen_cambiado(valor: float) -> void:
	var volumen_normalizado := valor / 100.0
	MusicManager.cambiar_volumen(volumen_normalizado)
	ConfigManager.cambiar_volumen_musica(volumen_normalizado)

func _on_volumen_sfx_cambiado(valor: float) -> void:
	var volumen_normalizado := valor / 100.0
	SFXManager.cambiar_volumen(volumen_normalizado)
	ConfigManager.cambiar_volumen_sfx(volumen_normalizado)

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
	if not is_instance_valid(boton):
		return
	var color_original := boton.modulate
	boton.modulate = Color.RED
	await get_tree().create_timer(0.3).timeout
	if is_instance_valid(boton) and is_inside_tree():
		boton.modulate = color_original

# === CALLBACKS BOTONES PRINCIPALES ===

func _on_btn_restablecer_pressed() -> void:
	match _tab_actual:
		"controles":
			ConfigManager.restablecer_controles()
			_actualizar_botones_controles()
		"sonido":
			_restablecer_sonido()
		"video":
			# Restablecer video a valores por defecto
			_option_resolucion.selected = 0  # 1280x720
			_check_pantalla_completa.button_pressed = false
			ConfigManager.establecer_resolucion_pendiente(ConfigManager.RESOLUCIONES[0])
			ConfigManager.establecer_pantalla_completa_pendiente(false)

func _on_btn_aplicar_pressed() -> void:
	ConfigManager.aplicar_cambios_video()

func _on_btn_volver_pressed() -> void:
	if _esperando_tecla:
		_cancelar_espera_tecla()
	# Descartar cambios de video no aplicados
	ConfigManager.descartar_cambios_video()

	if es_overlay:
		# Fue instanciado como overlay (desde pausa): destruirse a sí mismo
		es_overlay = false
		var canvas_padre := get_parent()
		if canvas_padre:
			canvas_padre.queue_free()
	else:
		# Fue abierto como escena: volver a la escena de origen
		get_tree().change_scene_to_file(escena_origen)

# === UTILIDADES ===

func _restablecer_sonido() -> void:
	## Restablece sonido a valores por defecto (Soundtrack 1, volúmenes 80%)
	# Desconectar señales temporalmente para no disparar callbacks
	_option_musica.item_selected.disconnect(_on_musica_seleccionada)
	_slider_volumen.value_changed.disconnect(_on_volumen_cambiado)
	_slider_volumen_sfx.value_changed.disconnect(_on_volumen_sfx_cambiado)

	_option_musica.selected = 0
	_slider_volumen.value = 80.0
	_slider_volumen_sfx.value = 80.0

	_option_musica.item_selected.connect(_on_musica_seleccionada)
	_slider_volumen.value_changed.connect(_on_volumen_cambiado)
	_slider_volumen_sfx.value_changed.connect(_on_volumen_sfx_cambiado)

	# Aplicar cambios
	MusicManager.reproducir(0)
	MusicManager.cambiar_volumen(0.8)
	SFXManager.cambiar_volumen(0.8)
	ConfigManager.cambiar_soundtrack(0)
	ConfigManager.cambiar_volumen_musica(0.8)
	ConfigManager.cambiar_volumen_sfx(0.8)

func _actualizar_botones_controles() -> void:
	_actualizar_grid_controles(_grid_j1, ConfigManager.ACCIONES_J1)
	_actualizar_grid_controles(_grid_j2, ConfigManager.ACCIONES_J2)

func _actualizar_grid_controles(grid: GridContainer, acciones: Array[String]) -> void:
	var botones := grid.get_children().filter(func(n): return n is Button)
	for i in range(min(botones.size(), acciones.size())):
		var boton := botones[i] as Button
		boton.text = ConfigManager.obtener_tecla_accion(acciones[i])
