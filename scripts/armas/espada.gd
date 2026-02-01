extends ArmaMeleeBase

## Espada - Arma cuerpo a cuerpo básica
##
## Hereda de ArmaMeleeBase y añade comportamiento específico de espada.
## Perfecta como plantilla para otras armas melee.

# === CONFIGURACIÓN ESPECÍFICA DE ESPADA ===

func _ready() -> void:
	# Configurar valores específicos de la espada
	dano = 1
	velocidad_ataque = 0.5
	knockback = Vector2(250, -80)
	nombre_animacion_ataque = "atacar"
	
	# Llamar al _ready del padre
	super._ready()

## Sobrescribir para añadir efectos específicos de espada
func _al_equipar() -> void:
	super._al_equipar()
	# Aquí puedes añadir efectos de sonido, partículas, etc.

## Sobrescribir para añadir efectos al soltar
func _al_soltar() -> void:
	super._al_soltar()
	# Aquí puedes añadir efectos de sonido al soltar

## Sobrescribir para personalizar el ataque si es necesario
func atacar() -> void:
	super.atacar()
	# Aquí puedes añadir efectos adicionales al atacar
	# Por ejemplo: sonido de espada, partículas de swing, etc.
