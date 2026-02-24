extends Node

const RUTA_CONFIG: String = "user://config.cfg"

const RESOLUCIONES: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080)
]

const RESOLUCION_DEFECTO: Vector2i = Vector2i(1280, 720)

const ACCIONES_J1: Array[String] = [
	"j1_arriba", "j1_abajo", "j1_izquierda", "j1_derecha",
	"j1_salto", "j1_disparo", "j1_accion"
]

const ACCIONES_J2: Array[String] = [
	"j2_arriba", "j2_abajo", "j2_izquierda", "j2_derecha",
	"j2_salto", "j2_disparo", "j2_accion"
]

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

signal configuracion_cambiada()
signal control_reasignado(accion: String, tecla: String)

var resolucion_actual: Vector2i = RESOLUCION_DEFECTO
var pantalla_completa: bool = false

var volumen_musica: float = 0.8
var volumen_sfx: float = 0.8
var soundtrack_seleccionado: int = 0

var _resolucion_pendiente: Vector2i = RESOLUCION_DEFECTO
var _pantalla_completa_pendiente: bool = false
var _hay_cambios_pendientes: bool = false

var _volumen_musica_previo: float = 0.8
var _volumen_sfx_previo: float = 0.8
var _soundtrack_previo: int = 0

var _controles_previos: Dictionary = {}

var _config: ConfigFile
var _controles_defecto: Dictionary = {}

# Carga configuracion y aplica video
func _ready() -> void:
	_config = ConfigFile.new()
	_guardar_controles_defecto()
	cargar_config()
	_aplicar_configuracion_video()

# Guarda los controles originales de project.godot
func _guardar_controles_defecto() -> void:
	for accion in ACCIONES_J1 + ACCIONES_J2:
		var eventos := InputMap.action_get_events(accion)
		if eventos.size() > 0:
			var evento := eventos[0] as InputEventKey
			if evento:
				_controles_defecto[accion] = evento.physical_keycode

# Aplica resolucion y modo pantalla
func _aplicar_configuracion_video() -> void:
	if pantalla_completa:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(resolucion_actual)
		_centrar_ventana()

# Centra la ventana en la pantalla
func _centrar_ventana() -> void:
	var pantalla_size := DisplayServer.screen_get_size()
	var ventana_size := DisplayServer.window_get_size()
	var pos := (pantalla_size - ventana_size) / 2
	DisplayServer.window_set_position(pos)

# Cambia la resolucion de la ventana
func cambiar_resolucion(nueva_res: Vector2i) -> void:
	if nueva_res not in RESOLUCIONES:
		push_warning("ConfigManager: Resolución no válida: %s" % str(nueva_res))
		return

	resolucion_actual = nueva_res

	if not pantalla_completa:
		DisplayServer.window_set_size(resolucion_actual)
		_centrar_ventana()

	guardar_config()
	configuracion_cambiada.emit()

# Cambia entre pantalla completa y ventana
func cambiar_modo_pantalla(completa: bool) -> void:
	pantalla_completa = completa

	if pantalla_completa:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(resolucion_actual)
		_centrar_ventana()

	guardar_config()
	configuracion_cambiada.emit()

# Devuelve el indice de la resolucion actual
func obtener_indice_resolucion() -> int:
	for i in range(RESOLUCIONES.size()):
		if RESOLUCIONES[i] == resolucion_actual:
			return i
	return 0

# Establece resolucion pendiente sin aplicar
func establecer_resolucion_pendiente(nueva_res: Vector2i) -> void:
	if nueva_res not in RESOLUCIONES:
		push_warning("ConfigManager: Resolución no válida: %s" % str(nueva_res))
		return
	_resolucion_pendiente = nueva_res
	_hay_cambios_pendientes = true

# Establece modo pantalla pendiente sin aplicar
func establecer_pantalla_completa_pendiente(completa: bool) -> void:
	_pantalla_completa_pendiente = completa
	_hay_cambios_pendientes = true

# Aplica los cambios de video pendientes
func aplicar_cambios_video() -> void:
	if not _hay_cambios_pendientes:
		return

	resolucion_actual = _resolucion_pendiente
	pantalla_completa = _pantalla_completa_pendiente

	_aplicar_configuracion_video()
	_hay_cambios_pendientes = false

# Descarta cambios pendientes de video
func descartar_cambios_video() -> void:
	_resolucion_pendiente = resolucion_actual
	_pantalla_completa_pendiente = pantalla_completa
	_hay_cambios_pendientes = false

# Inicializa valores pendientes y previos al abrir ajustes
func inicializar_pendientes() -> void:
	_resolucion_pendiente = resolucion_actual
	_pantalla_completa_pendiente = pantalla_completa
	_hay_cambios_pendientes = false
	_volumen_musica_previo = volumen_musica
	_volumen_sfx_previo = volumen_sfx
	_soundtrack_previo = soundtrack_seleccionado
	_guardar_snapshot_controles()

# Devuelve si hay cambios sin aplicar
func hay_cambios_pendientes() -> bool:
	return _hay_cambios_pendientes

# Aplica y guarda todos los cambios pendientes
func aplicar_todos_los_cambios() -> void:
	aplicar_cambios_video()
	guardar_config()
	_volumen_musica_previo = volumen_musica
	_volumen_sfx_previo = volumen_sfx
	_soundtrack_previo = soundtrack_seleccionado
	_guardar_snapshot_controles()
	configuracion_cambiada.emit()

# Descarta todos los cambios no aplicados
func descartar_todos_los_cambios() -> void:
	descartar_cambios_video()
	volumen_musica = _volumen_musica_previo
	volumen_sfx = _volumen_sfx_previo
	soundtrack_seleccionado = _soundtrack_previo
	_restaurar_snapshot_controles()

# Guarda estado actual del InputMap
func _guardar_snapshot_controles() -> void:
	_controles_previos.clear()
	for accion in ACCIONES_J1 + ACCIONES_J2:
		var eventos := InputMap.action_get_events(accion)
		if eventos.size() > 0:
			var evento := eventos[0] as InputEventKey
			if evento:
				_controles_previos[accion] = evento.physical_keycode

# Restaura el InputMap al snapshot previo
func _restaurar_snapshot_controles() -> void:
	for accion in _controles_previos:
		InputMap.action_erase_events(accion)
		var evento := InputEventKey.new()
		evento.physical_keycode = _controles_previos[accion] as Key
		InputMap.action_add_event(accion, evento)

# Devuelve el indice de la resolucion pendiente
func obtener_indice_resolucion_pendiente() -> int:
	for i in range(RESOLUCIONES.size()):
		if RESOLUCIONES[i] == _resolucion_pendiente:
			return i
	return 0

# Devuelve el estado pendiente de pantalla completa
func obtener_pantalla_completa_pendiente() -> bool:
	return _pantalla_completa_pendiente

# Reasigna una accion a una nueva tecla
func reasignar_control(accion: String, nuevo_evento: InputEventKey) -> bool:
	if accion not in ACCIONES_J1 + ACCIONES_J2:
		push_warning("ConfigManager: Acción no válida: %s" % accion)
		return false

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

	InputMap.action_erase_events(accion)
	InputMap.action_add_event(accion, nuevo_evento)

	var nombre_tecla := OS.get_keycode_string(nuevo_evento.physical_keycode)
	control_reasignado.emit(accion, nombre_tecla)

	return true

# Restaura controles a valores por defecto
func restablecer_controles() -> void:
	for accion in _controles_defecto:
		InputMap.action_erase_events(accion)

		var evento := InputEventKey.new()
		evento.physical_keycode = _controles_defecto[accion] as Key
		InputMap.action_add_event(accion, evento)

	configuracion_cambiada.emit()

# Devuelve el nombre de la tecla asignada a una accion
func obtener_tecla_accion(accion: String) -> String:
	var eventos := InputMap.action_get_events(accion)
	for evento in eventos:
		if evento is InputEventKey:
			var evento_tecla := evento as InputEventKey
			var keycode: int = evento_tecla.physical_keycode
			if keycode == 0:
				keycode = evento_tecla.keycode
			return OS.get_keycode_string(keycode)
	return "?"

# Devuelve el nombre legible de una accion
func obtener_nombre_accion(accion: String) -> String:
	return NOMBRES_ACCIONES.get(accion, accion)

# Cambia el volumen de musica (preview)
func cambiar_volumen_musica(valor: float) -> void:
	volumen_musica = clampf(valor, 0.0, 1.0)

# Cambia el volumen de sfx (preview)
func cambiar_volumen_sfx(valor: float) -> void:
	volumen_sfx = clampf(valor, 0.0, 1.0)

# Cambia el soundtrack seleccionado (preview)
func cambiar_soundtrack(indice: int) -> void:
	soundtrack_seleccionado = indice

# Guarda la configuracion en archivo
func guardar_config() -> void:
	_config.set_value("video", "resolucion_x", resolucion_actual.x)
	_config.set_value("video", "resolucion_y", resolucion_actual.y)
	_config.set_value("video", "pantalla_completa", pantalla_completa)

	_config.set_value("audio", "volumen_musica", volumen_musica)
	_config.set_value("audio", "volumen_sfx", volumen_sfx)
	_config.set_value("audio", "soundtrack_seleccionado", soundtrack_seleccionado)

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
		pass

# Carga la configuracion desde archivo
func cargar_config() -> void:
	var error := _config.load(RUTA_CONFIG)

	if error != OK:
		return

	resolucion_actual.x = _config.get_value("video", "resolucion_x", RESOLUCION_DEFECTO.x)
	resolucion_actual.y = _config.get_value("video", "resolucion_y", RESOLUCION_DEFECTO.y)
	pantalla_completa = _config.get_value("video", "pantalla_completa", false)

	if resolucion_actual not in RESOLUCIONES:
		resolucion_actual = RESOLUCION_DEFECTO

	volumen_musica = _config.get_value("audio", "volumen_musica", 0.8)
	volumen_sfx = _config.get_value("audio", "volumen_sfx", 0.8)
	soundtrack_seleccionado = _config.get_value("audio", "soundtrack_seleccionado", 0)
	volumen_musica = clampf(volumen_musica, 0.0, 1.0)
	volumen_sfx = clampf(volumen_sfx, 0.0, 1.0)
	if soundtrack_seleccionado < 0:
		soundtrack_seleccionado = 0

	for accion in ACCIONES_J1 + ACCIONES_J2:
		if _config.has_section_key("controles", accion):
			var keycode_valor = _config.get_value("controles", accion)
			if keycode_valor is int and keycode_valor > 0:
				InputMap.action_erase_events(accion)
				var evento := InputEventKey.new()
				evento.physical_keycode = keycode_valor as Key
				InputMap.action_add_event(accion, evento)
			else:
				push_warning("ConfigManager: Keycode inválido para '%s', usando valor por defecto" % accion)
