extends PersonagemBase


# CRUCIAL: Habilita a detecção de input para este nó
func _ready():
	# Certifique-se de que a detecção de clique esteja ativada na sua CollisionShape2D ou Area2D
	set_process_input(true) # Pode ser necessário dependendo da sua configuração

	# Chama a inicialização de HP/Dados da classe pai
	super._ready()


func use_ability(ability_name: String, target_node: CharacterBody2D):
	super.use_ability(ability_name, target_node)

	if not cannot_use_ability:
		if ability_name == "Esmagamento Brutal":
			# Lógica para Lúcio (Seu ataque brutal aumenta a tensão geral por ser nojento)
			batle_root.aumentar_tensao(5) 
			batle_root.trigger_battle_talk(self, "Que nojo! Mas funcionou.")
