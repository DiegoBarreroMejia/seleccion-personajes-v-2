extends Control

const RUTA_MENU_INICIO: String = "res://scenes/ui/MenuInicio.tscn"
const FUENTE_PRINCIPAL: Font = preload("res://assets/fonts/PressStart2P-Regular.ttf")

static var escena_origen: String = "res://scenes/ui/MenuInicio.tscn"
static var es_overlay: bool = false

var _esperando_tecla: bool = false
var _accion_a_reasignar: String = ""
var _boton_esperando: Button = null
var _tab_actual: String = "video"

@onready var _btn_tab_video: TextureButton = $ContenedorPrincipal/Pestanas/BtnVideo
@onready var _btn_tab_controles: TextureButton = $ContenedorPrincipal/Pestanas/BtnControles
@onready var _btn_tab_sonido: TextureButton = $ContenedorPrincipal/Pestanas/BtnSonido
@onready var _contenedor_video: VBoxContainer = $ContenedorPrincipal/ContenedorVideo
@onready var _contenedor_controles: HBoxContainer = $ContenedorPrincipal/ContenedorControles
@onready var _contenedor_sonido: VBoxContainer = $ContenedorPrincipal/ContenedorSonido

@onready var _option_resolucion: OptionButton = $ContenedorPrincipal/ContenedorVideo/FilaResolucion/OptionResolucion
@onready var _check_pantalla_completa: CheckButton = $ContenedorPrincipal/ContenedorVideo/FilaPantalla/CheckPantallaCompleta

@onready var _grid_j1: GridContainer = $ContenedorPrincipal/ContenedorControles/PanelJ1/GridJ1
@onready var _grid_j2: GridContainer = $ContenedorPrincipal/ContenedorControles/PanelJ2/GridJ2

@onready var _option_musica: OptionButton = $ContenedorPrincipal/ContenedorSonido/FilaMusica/OptionMusica
@onready var _slider_volumen: HSlider = $ContenedorPrincipal/ContenedorSonido/FilaVolumen/SliderVolumen
@onready var _slider_volumen_sfx: HSlider = $ContenedorPrincipal/ContenedorSonido/FilaVolumenSFX/SliderVolumenSFX

# Inicializa pendientes y configura todas las pestanas
func _ready() -> void:
	ConfigManager.inicializar_pendientes()
	_configurar_pestanas()
	_configurar_opciones_video()
	_configurar_controles()
	_configurar_opciones_sonido()
	_mostrar_tab_video()

# Captura tecla cuando se esta reasignando un control
func _input(event: InputEvent) -> void:
	if not _esperando_tecla:
		return

	if event is InputEventKey and event.pressed:
		_procesar_nueva_tecla(event)
		get_viewport().set_input_as_handled()

# Conecta botones de pestanas
func _configurar_pestanas() -> void:
	_btn_tab_video.pressed.connect(_mostrar_tab_video)
	_btn_tab_controles.pressed.connect(_mostrar_tab_controles)
	_btn_tab_sonido.pressed.connect(_mostrar_tab_sonido)

# Configura opciones de resolucion y pantalla completa
func _configurar_opciones_video() -> void:
	_option_resolucion.clear()
	for res in ConfigManager.RESOLUCIONES:
		_option_resolucion.add_item("%dx%d" % [res.x, res.y])

	_option_resolucion.selected = ConfigManager.obtener_indice_resolucion_pendiente()
	_check_pantalla_completa.button_pressed = ConfigManager.obtener_pantalla_completa_pendiente()

	_option_resolucion.item_selected.connect(_on_resolucion_seleccionada)
	_check_pantalla_completa.toggled.connect(_on_pantalla_completa_cambiada)

# Crea botones de reasignacion para ambos jugadores
func _configurar_controles() -> void:
	_crear_botones_control(_grid_j1, ConfigManager.ACCIONES_J1)
	_crear_botones_control(_grid_j2, ConfigManager.ACCIONES_J2)

# Configura sliders de volumen y selector de soundtrack
func _configurar_opciones_sonido() -> void:
	_option_musica.clear()
	var nombres := MusicManager.obtener_nombres_soundtracks()
	for nombre in nombres:
		_option_musica.add_item(nombre)

	_option_musica.selected = ConfigManager.soundtrack_seleccionado

	_slider_volumen.min_value = 0
	_slider_volumen.max_value = 100
	_slider_volumen.step = 1
	_slider_volumen.value = ConfigManager.volumen_musica * 100.0

	_slider_volumen_sfx.min_value = 0
	_slider_volumen_sfx.max_value = 100
	_slider_volumen_sfx.step = 1
	_slider_volumen_sfx.value = ConfigManager.volumen_sfx * 100.0

	_option_musica.item_selected.connect(_on_musica_seleccionada)
	_slider_volumen.value_changed.connect(_on_volumen_cambiado)
	_slider_volumen_sfx.value_changed.connect(_on_volumen_sfx_cambiado)

# Crea label y boton de reasignacion para cada accion
func _crear_botones_control(grid: GridContainer, acciones: Array[String]) -> void:
	for child in grid.get_children():
		child.queue_free()

	await get_tree().process_frame

	if not is_inside_tree():
		return

	for accion in acciones:
		var label := Label.new()
		label.text = ConfigManager.obtener_nombre_accion(accion) + ":"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		label.custom_minimum_size = Vector2(80, 0)
		label.add_theme_font_override("font", FUENTE_PRINCIPAL)
		grid.add_child(label)

		var boton := Button.new()
		boton.text = ConfigManager.obtener_tecla_accion(accion)
		boton.custom_minimum_size = Vector2(100, 35)
		boton.add_theme_font_override("font", FUENTE_PRINCIPAL)
		boton.pressed.connect(_on_boton_control_presionado.bind(accion, boton))
		grid.add_child(boton)

# Muestra la pestana de video
func _mostrar_tab_video() -> void:
	_tab_actual = "video"
	_contenedor_video.visible = true
	_contenedor_controles.visible = false
	_contenedor_sonido.visible = false
	_btn_tab_video.disabled = true
	_btn_tab_controles.disabled = false
	_btn_tab_sonido.disabled = false

# Muestra la pestana de controles
func _mostrar_tab_controles() -> void:
	_tab_actual = "controles"
	_contenedor_video.visible = false
	_contenedor_controles.visible = true
	_contenedor_sonido.visible = false
	_btn_tab_video.disabled = false
	_btn_tab_controles.disabled = true
	_btn_tab_sonido.disabled = false

# Muestra la pestana de sonido
func _mostrar_tab_sonido() -> void:
	_tab_actual = "sonido"
	_contenedor_video.visible = false
	_contenedor_controles.visible = false
	_contenedor_sonido.visible = true
	_btn_tab_video.disabled = false
	_btn_tab_controles.disabled = false
	_btn_tab_sonido.disabled = true

# Establece resolucion pendiente
func _on_resolucion_seleccionada(indice: int) -> void:
	var nueva_res := ConfigManager.RESOLUCIONES[indice]
	ConfigManager.establecer_resolucion_pendiente(nueva_res)

# Establece pantalla completa pendiente
func _on_pantalla_completa_cambiada(activada: bool) -> void:
	ConfigManager.establecer_pantalla_completa_pendiente(activada)

# Cambia el soundtrack en preview
func _on_musica_seleccionada(indice: int) -> void:
	MusicManager.reproducir(indice)
	ConfigManager.cambiar_soundtrack(indice)

# Cambia el volumen de musica en preview
func _on_volumen_cambiado(valor: float) -> void:
	var volumen_normalizado := valor / 100.0
	MusicManager.cambiar_volumen(volumen_normalizado)
	ConfigManager.cambiar_volumen_musica(volumen_normalizado)

# Cambia el volumen de sfx en preview
func _on_volumen_sfx_cambiado(valor: float) -> void:
	var volumen_normalizado := valor / 100.0
	SFXManager.cambiar_volumen(volumen_normalizado)
	ConfigManager.cambiar_volumen_sfx(volumen_normalizado)

# Inicia espera de tecla para reasignar un control
func _on_boton_control_presionado(accion: String, boton: Button) -> void:
	if _esperando_tecla:
		_cancelar_espera_tecla()

	_esperando_tecla = true
	_accion_a_reasignar = accion
	_boton_esperando = boton
	boton.text = "..."

# Procesa la tecla presionada para reasignar
func _procesar_nueva_tecla(evento: InputEventKey) -> void:
	if evento.physical_keycode == KEY_ESCAPE:
		_cancelar_espera_tecla()
		return

	var exito := ConfigManager.reasignar_control(_accion_a_reasignar, evento)

	if exito:
		_boton_esperando.text = ConfigManager.obtener_tecla_accion(_accion_a_reasignar)
	else:
		_boton_esperando.text = ConfigManager.obtener_tecla_accion(_accion_a_reasignar)
		_mostrar_error_boton(_boton_esperando)

	_esperando_tecla = false
	_accion_a_reasignar = ""
	_boton_esperando = null

# Cancela la reasignacion y restaura el texto del boton
func _cancelar_espera_tecla() -> void:
	if _boton_esperando:
		_boton_esperando.text = ConfigManager.obtener_tecla_accion(_accion_a_reasignar)

	_esperando_tecla = false
	_accion_a_reasignar = ""
	_boton_esperando = null

# Parpadeo rojo en el boton cuando la tecla ya esta en uso
func _mostrar_error_boton(boton: Button) -> void:
	if not is_instance_valid(boton):
		return
	var color_original := boton.modulate
	boton.modulate = Color.RED
	await get_tree().create_timer(0.3).timeout
	if is_instance_valid(boton) and is_inside_tree():
		boton.modulate = color_original

# Restablece valores segun la pestana activa
func _on_btn_restablecer_pressed() -> void:
	match _tab_actual:
		"controles":
			ConfigManager.restablecer_controles()
			_actualizar_botones_controles()
		"sonido":
			_restablecer_sonido()
		"video":
			_option_resolucion.selected = 0
			_check_pantalla_completa.button_pressed = false
			ConfigManager.establecer_resolucion_pendiente(ConfigManager.RESOLUCIONES[0])
			ConfigManager.establecer_pantalla_completa_pendiente(false)

# Aplica todos los cambios pendientes
func _on_btn_aplicar_pressed() -> void:
	ConfigManager.aplicar_todos_los_cambios()

# Descarta cambios no aplicados y vuelve a la escena anterior
func _on_btn_volver_pressed() -> void:
	if _esperando_tecla:
		_cancelar_espera_tecla()
	var vol_musica_preview := ConfigManager.volumen_musica
	var vol_sfx_preview := ConfigManager.volumen_sfx
	var soundtrack_preview := ConfigManager.soundtrack_seleccionado
	ConfigManager.descartar_todos_los_cambios()
	if vol_musica_preview != ConfigManager.volumen_musica:
		MusicManager.cambiar_volumen(ConfigManager.volumen_musica)
	if vol_sfx_preview != ConfigManager.volumen_sfx:
		SFXManager.cambiar_volumen(ConfigManager.volumen_sfx)
	if soundtrack_preview != ConfigManager.soundtrack_seleccionado:
		MusicManager.reproducir(ConfigManager.soundtrack_seleccionado)

	if es_overlay:
		es_overlay = false
		var canvas_padre := get_parent()
		if canvas_padre:
			canvas_padre.queue_free()
	else:
		get_tree().change_scene_to_file(escena_origen)

# Restablece sonido a valores por defecto
func _restablecer_sonido() -> void:
	_option_musica.item_selected.disconnect(_on_musica_seleccionada)
	_slider_volumen.value_changed.disconnect(_on_volumen_cambiado)
	_slider_volumen_sfx.value_changed.disconnect(_on_volumen_sfx_cambiado)

	_option_musica.selected = 0
	_slider_volumen.value = 80.0
	_slider_volumen_sfx.value = 80.0

	_option_musica.item_selected.connect(_on_musica_seleccionada)
	_slider_volumen.value_changed.connect(_on_volumen_cambiado)
	_slider_volumen_sfx.value_changed.connect(_on_volumen_sfx_cambiado)

	MusicManager.reproducir(0)
	MusicManager.cambiar_volumen(0.8)
	SFXManager.cambiar_volumen(0.8)
	ConfigManager.cambiar_soundtrack(0)
	ConfigManager.cambiar_volumen_musica(0.8)
	ConfigManager.cambiar_volumen_sfx(0.8)

# Actualiza el texto de todos los botones de controles
func _actualizar_botones_controles() -> void:
	_actualizar_grid_controles(_grid_j1, ConfigManager.ACCIONES_J1)
	_actualizar_grid_controles(_grid_j2, ConfigManager.ACCIONES_J2)

# Actualiza los botones de un grid de controles
func _actualizar_grid_controles(grid: GridContainer, acciones: Array[String]) -> void:
	var botones := grid.get_children().filter(func(n): return n is Button)
	for i in range(min(botones.size(), acciones.size())):
		var boton := botones[i] as Button
		boton.text = ConfigManager.obtener_tecla_accion(acciones[i])
