extends ArmaMeleeBase

# Configura valores de la daga
func _ready() -> void:
	dano = 1
	velocidad_ataque = 0.35
	knockback = Vector2(180, -60)
	nombre_animacion_ataque = "atacar"
	super._ready()

# Ejecuta logica al equipar
func _al_equipar() -> void:
	super._al_equipar()

# Ejecuta logica al soltar
func _al_soltar() -> void:
	super._al_soltar()

# Ejecuta el ataque
func atacar() -> void:
	super.atacar()
