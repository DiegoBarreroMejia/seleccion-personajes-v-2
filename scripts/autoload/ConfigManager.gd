extends Node

## Gestor de configuración del juego
##
## Maneja:
## - Configuración de video (resolución, modo pantalla)
## - Configuración de controles (reasignación de teclas)
## - Persistencia con ConfigFile

# === CONSTANTES ===
const RUTA_CONFIG: String = "user://config.cfg"

const RESOLUCIONES: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080)
]

const RESOLUCION_DEFECTO: Vector2i = Vector2i(1280, 720)

## Acciones de cada jugador que se pueden reasignar
const ACCIONES_J1: Array[String] = [
	"j1_arriba", "j1_abajo", "j1_izquierda", "j1_derecha",
	"j1_salto", "j1_disparo", "j1_accion"
]

const ACCIONES_J2: Array[String] = [
	"j2_arriba", "j2_abajo", "j2_izquierda", "j2_derecha",
	"j2_salto", "j2_disparo", "j2_accion"
]

## Nombres legibles para mostrar en UI
const NOMBRES_ACCIONES: Dictionary = {
	"j1_arriba": "Arriba",
	"j1_abajo": "Abajo",
	"j1_izquierda": "Izquierda",
	"j1_derecha": "Derecha",
	"j1_salto": "Salto",
	"j1_disparo": "Disparo",
	"j1_accion": "Acción",
	"j2_arriba": "Arriba",
	"j2_abajo": "Abajo",
	"j2_izquierda": "Izquierda",
	"j2_derecha": "Derecha",
	"j2_salto": "Salto",
	"j2_disparo": "Disparo",
	"j2_accion": "Acción"
}

# === SEÑALES ===
signal configuracion_cambiada()
signal control_reasignado(accion: String, tecla: String)

# === VARIABLES DE CONFIGURACIÓN ===
var resolucion_actual: Vector2i = RESOLUCION_DEFECTO
var pantalla_completa: bool = false

# === VARIABLES DE CAMBIOS PENDIENTES (VIDEO) ===
var _resolucion_pendiente: Vector2i = RESOLUCION_DEFECTO
var _pantalla_completa_pendiente: bool = false
var _hay_cambios_pendientes: bool = false

# === VARIABLES PRIVADAS ===
var _config: ConfigFile
var _controles_defecto: Dictionary = {}  # Guarda los controles originales

# === MÉTODOS DE CICLO DE VIDA ===

func _ready() -> void:
	_config = ConfigFile.new()
	_guardar_controles_defecto()
	cargar_config()
	_aplicar_configuracion_video()

# === MÉTODOS PRIVADOS ===

func _guardar_controles_defecto() -> void:
	## Guarda los controles definidos en project.godot como referencia
	for accion in ACCIONES_J1 + ACCIONES_J2:
		var eventos := InputMap.action_get_events(accion)
		if eventos.size() > 0:
			var evento := eventos[0] as InputEventKey
			if evento:
				_controles_defecto[accion] = evento.physical_keycode

func _aplicar_configuracion_video() -> void:
	## Aplica la configuración de video actual
	if pantalla_completa:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(resolucion_actual)
		_centrar_ventana()

func _centrar_ventana() -> void:
	## Centra la ventana en la pantalla
	var pantalla_size := DisplayServer.screen_get_size()
	var ventana_size := DisplayServer.window_get_size()
	var pos := (pantalla_size - ventana_size) / 2
	DisplayServer.window_set_position(pos)

# === MÉTODOS PÚBLICOS - VIDEO ===

func cambiar_resolucion(nueva_res: Vector2i) -> void:
	## Cambia la resolución de la ventana
	if nueva_res not in RESOLUCIONES:
		push_warning("ConfigManager: Resolución no válida: %s" % str(nueva_res))
		return

	resolucion_actual = nueva_res

	if not pantalla_completa:
		DisplayServer.window_set_size(resolucion_actual)
		_centrar_ventana()

	guardar_config()
	configuracion_cambiada.emit()
	print("Resolución cambiada a: %dx%d" % [nueva_res.x, nueva_res.y])

func cambiar_modo_pantalla(completa: bool) -> void:
	## Cambia entre pantalla completa y ventana
	pantalla_completa = completa

	if pantalla_completa:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(resolucion_actual)
		_centrar_ventana()

	guardar_config()
	configuracion_cambiada.emit()
	print("Modo pantalla: %s" % ("Completa" if completa else "Ventana"))

func obtener_indice_resolucion() -> int:
	## Devuelve el índice de la resolución actual en RESOLUCIONES
	for i in range(RESOLUCIONES.size()):
		if RESOLUCIONES[i] == resolucion_actual:
			return i
	return 0

# === MÉTODOS PÚBLICOS - CAMBIOS PENDIENTES VIDEO ===

func establecer_resolucion_pendiente(nueva_res: Vector2i) -> void:
	## Establece una resolución pendiente (no se aplica hasta llamar aplicar_cambios_video)
	if nueva_res not in RESOLUCIONES:
		push_warning("ConfigManager: Resolución no válida: %s" % str(nueva_res))
		return
	_resolucion_pendiente = nueva_res
	_hay_cambios_pendientes = true

func establecer_pantalla_completa_pendiente(completa: bool) -> void:
	## Establece modo pantalla pendiente (no se aplica hasta llamar aplicar_cambios_video)
	_pantalla_completa_pendiente = completa
	_hay_cambios_pendientes = true

func aplicar_cambios_video() -> void:
	## Aplica todos los cambios de video pendientes
	if not _hay_cambios_pendientes:
		return

	resolucion_actual = _resolucion_pendiente
	pantalla_completa = _pantalla_completa_pendiente

	_aplicar_configuracion_video()
	guardar_config()
	_hay_cambios_pendientes = false
	configuracion_cambiada.emit()
	print("Cambios de video aplicados")

func descartar_cambios_video() -> void:
	## Descarta los cambios pendientes y restaura los valores actuales
	_resolucion_pendiente = resolucion_actual
	_pantalla_completa_pendiente = pantalla_completa
	_hay_cambios_pendientes = false

func inicializar_pendientes() -> void:
	## Inicializa los valores pendientes con los valores actuales
	_resolucion_pendiente = resolucion_actual
	_pantalla_completa_pendiente = pantalla_completa
	_hay_cambios_pendientes = false

func hay_cambios_pendientes() -> bool:
	## Devuelve true si hay cambios sin aplicar
	return _hay_cambios_pendientes

func obtener_indice_resolucion_pendiente() -> int:
	## Devuelve el índice de la resolución pendiente en RESOLUCIONES
	for i in range(RESOLUCIONES.size()):
		if RESOLUCIONES[i] == _resolucion_pendiente:
			return i
	return 0

func obtener_pantalla_completa_pendiente() -> bool:
	## Devuelve el estado pendiente de pantalla completa
	return _pantalla_completa_pendiente

# === MÉTODOS PÚBLICOS - CONTROLES ===

func reasignar_control(accion: String, nuevo_evento: InputEventKey) -> bool:
	## Reasigna una acción a una nueva tecla
	## Devuelve true si se reasignó correctamente

	if accion not in ACCIONES_J1 + ACCIONES_J2:
		push_warning("ConfigManager: Acción no válida: %s" % accion)
		return false

	# Verificar si la tecla ya está asignada a otra acción del mismo jugador
	var es_j1 := accion in ACCIONES_J1
	var acciones_jugador := ACCIONES_J1 if es_j1 else ACCIONES_J2

	for otra_accion in acciones_jugador:
		if otra_accion == accion:
			continue
		var eventos := InputMap.action_get_events(otra_accion)
		for evento in eventos:
			if evento is InputEventKey:
				if evento.physical_keycode == nuevo_evento.physical_keycode:
					push_warning("ConfigManager: Tecla ya asignada a %s" % otra_accion)
					return false

	# Limpiar eventos anteriores y añadir el nuevo
	InputMap.action_erase_events(accion)
	InputMap.action_add_event(accion, nuevo_evento)

	guardar_config()

	var nombre_tecla := OS.get_keycode_string(nuevo_evento.physical_keycode)
	control_reasignado.emit(accion, nombre_tecla)
	print("Control reasignado: %s -> %s" % [accion, nombre_tecla])

	return true

func restablecer_controles() -> void:
	## Restaura todos los controles a sus valores por defecto
	for accion in _controles_defecto:
		InputMap.action_erase_events(accion)

		var evento := InputEventKey.new()
		evento.physical_keycode = _controles_defecto[accion]
		InputMap.action_add_event(accion, evento)

	guardar_config()
	configuracion_cambiada.emit()
	print("Controles restablecidos a valores por defecto")

func obtener_tecla_accion(accion: String) -> String:
	## Devuelve el nombre de la tecla asignada a una acción
	var eventos := InputMap.action_get_events(accion)
	for evento in eventos:
		if evento is InputEventKey:
			var evento_tecla := evento as InputEventKey
			var keycode: int = evento_tecla.physical_keycode
			if keycode == 0:
				keycode = evento_tecla.keycode
			return OS.get_keycode_string(keycode)
	return "?"

func obtener_nombre_accion(accion: String) -> String:
	## Devuelve el nombre legible de una acción
	return NOMBRES_ACCIONES.get(accion, accion)

# === PERSISTENCIA ===

func guardar_config() -> void:
	## Guarda la configuración actual en archivo
	# Video
	_config.set_value("video", "resolucion_x", resolucion_actual.x)
	_config.set_value("video", "resolucion_y", resolucion_actual.y)
	_config.set_value("video", "pantalla_completa", pantalla_completa)

	# Controles
	for accion in ACCIONES_J1 + ACCIONES_J2:
		var eventos := InputMap.action_get_events(accion)
		if eventos.size() > 0:
			var evento := eventos[0] as InputEventKey
			if evento:
				var keycode: int = evento.physical_keycode
				if keycode == 0:
					keycode = evento.keycode
				_config.set_value("controles", accion, keycode)

	var error := _config.save(RUTA_CONFIG)
	if error != OK:
		push_error("ConfigManager: Error al guardar config: %d" % error)
	else:
		print("Configuración guardada en %s" % RUTA_CONFIG)

func cargar_config() -> void:
	## Carga la configuración desde archivo
	var error := _config.load(RUTA_CONFIG)

	if error != OK:
		print("ConfigManager: No existe config, usando valores por defecto")
		return

	# Video
	resolucion_actual.x = _config.get_value("video", "resolucion_x", RESOLUCION_DEFECTO.x)
	resolucion_actual.y = _config.get_value("video", "resolucion_y", RESOLUCION_DEFECTO.y)
	pantalla_completa = _config.get_value("video", "pantalla_completa", false)

	# Validar resolución
	if resolucion_actual not in RESOLUCIONES:
		resolucion_actual = RESOLUCION_DEFECTO

	# Controles
	for accion in ACCIONES_J1 + ACCIONES_J2:
		if _config.has_section_key("controles", accion):
			var keycode: int = _config.get_value("controles", accion)
			InputMap.action_erase_events(accion)
			var evento := InputEventKey.new()
			evento.physical_keycode = keycode
			InputMap.action_add_event(accion, evento)

	print("Configuración cargada desde %s" % RUTA_CONFIG)
