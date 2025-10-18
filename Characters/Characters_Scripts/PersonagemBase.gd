class_name PersonagemBase
extends CharacterBody2D

@export var data: PersonagemData # Atribuir o .tres correspondente no editor

@onready var batle_root: Node2D = $".."

@onready var sfx_player: AudioStreamPlayer = $"../Sfx_player"

var current_hp: int
var current_cooldowns: Dictionary = {} # Key: nome da habilidade, Value: turnos restantes
var current_effects: Dictionary = {} # Key: nome da habilidade, Value: turnos restantes

# FLAG: Indica se o personagem pulou o turno devido a uma reação impulsiva ou atordoamento.
var turn_skipped: bool = false 

# O sinal envia 3 informações: HP Atual, HP Máximo e o Node que mudou (self)
signal hp_changed(current_hp_value, max_hp_value, changed_node)

# Sinal pra indicar que o Node (Persoangem) morreu
signal defeated(defeated_node)

# NOVO SINAL: Para avisar o BattleManager sobre mudanças de agro/status globais
signal status_effect_applied(effect_name: String, target: CharacterBody2D)

#VARIÁVEIS ADICIONADAS PARA O FUNCIONAMENTO DO OVERRIDE E 
# NOTAa: O inimigo vai usar estas variáveis, mesmo que a Party não as use.

# 1. Alvo Atual (Quem o inimigo está atacando/focado. Necessário para o Override do Ted)
var current_target: CharacterBody2D = null 

# 2. Status de Corrupção (Necessário para a lógica do inimigo no BattleManager) teste
var is_human_corrupted: bool = true # Assume que o inimigo é sempre uma ameaça corrompida

var ted_ammo: int = 1
var ted_reload_ammo: int = 0

var cannot_use_ability: bool = false

func _ready():
	# Conecta o sinal global do BattleManager à nossa função local
	var battle_manager = get_parent() # Assumindo que o BattleManager é o pai

	if data:
		data = data.duplicate()
		current_hp = data.hp_max
		# Inicializa barras de HP individuais no HUD
		# Ou o BattleManager vai gerenciar isso.
	
	if battle_manager.has_signal("round_finished"):
		battle_manager.round_finished.connect(self.on_round_finished)


# NOVO MÉTODO: Função que será chamada pelo sinal
func on_round_finished():
	# Reduz os contadores de cooldown
	self.end_turn_cooldown() 
	self.end_turn_effects()


func end_turn_cooldown():
	# DEBUG: Checa o estado inicial dos cooldowns
	if not current_cooldowns.is_empty():
		pass
		#print("DEBUG CD: Iniciando recarga para:", current_cooldowns.keys())
		
	var keys_to_remove = []

	# Itera sobre todas as habilidades no dicionário de cooldowns
	for ability_name in current_cooldowns:
		# Reduz o contador de recarga em 1
		current_cooldowns[ability_name] -= 1
		
		# DEBUG: Mostra o valor atual após o desconto
		#print("DEBUG CD: ", ability_name, " - Novo valor:", current_cooldowns[ability_name])
	
		# Se o contador atingiu zero ou menos, marca para remoção
		if current_cooldowns[ability_name] <= 0:
			keys_to_remove.append(ability_name)

	# Se houver chaves para remover, exibe a informação antes de limpar
	#if not keys_to_remove.is_empty():
		#print("DEBUG CD: Recarga FINALIZADA para:", keys_to_remove)

	# Limpa o dicionário das entradas finalizadas
	for key in keys_to_remove:
		current_cooldowns.erase(key)

	# Limpa o dicionário das habilidades que terminaram a recarga
	for key in keys_to_remove:
		current_cooldowns.erase(key)

	# Opcional: print("Cooldowns ativos:", current_cooldowns.keys())


func end_turn_effects():
	# DEBUG: Checa o estado inicial dos cooldowns
	if not current_effects.is_empty():
		print("DEBUG CD: Iniciando recarga para:", current_effects.keys())
		
	var keys_to_remove = []

	# Itera sobre todas as habilidades no dicionário de cooldowns
	for effect_name in current_effects:
		# Reduz o contador de recarga em 1
		current_effects[effect_name] -= 1
		
		# DEBUG: Mostra o valor atual após o desconto
		#print("DEBUG CD: ", ability_name, " - Novo valor:", current_effects[ability_name])
	
		# Se o contador atingiu zero ou menos, marca para remoção
		if current_effects[effect_name] <= 0:
			keys_to_remove.append(effect_name)


	# Remove os efeitos finalizados
	for key in keys_to_remove:
		current_effects.erase(key)
		print(data.nome, " - Efeito ", key, " REMOVIDO.")


	# Limpa o dicionário das habilidades que terminaram a recarga
	for key in keys_to_remove:
		current_effects.erase(key)

	print("Efeitos ativos:", current_effects.keys())



func take_damage(amount: int):
	current_hp -= maxi(amount - data.defesa, 0)
	if current_hp <= 0:
		current_hp = 0
		die()
	
	emit_signal("hp_changed", current_hp, data.hp_max, self)
	# Atualizar a barra de HP do personagem no HUD
	# Ex: get_node("../HUD/PartyHPBars/EmaHP/ProgressBar").value = current_hp
	var damage_message: String = "-" + str(amount)
	batle_root.trigger_battle_talk(self, damage_message, 1.0)
	print(data.nome, " tomou dano. HP restante: ", current_hp)


func heal(amount: int):
	current_hp = mini(current_hp + amount, data.hp_max)
	
	# ATUALIZAÇÃO: Emitir o sinal após a cura
	emit_signal("hp_changed", current_hp, data.hp_max, self)

	# Atualizar a barra de HP
	print(data.nome, " curou:", "HP restante: ", current_hp)


# Função para encontrar a habilidade pelo nome no Array
func get_ability_by_name(name: String) -> HabilidadeData:
	for ability in data.habilidades:
		if ability.nome == name:
			return ability
	return null # Retorna null se não encontrar


func can_use_ability(ability_name: String) -> bool:
	# 1. Tenta encontrar a habilidade no Array usando a função de busca
	var ability_data: HabilidadeData = get_ability_by_name(ability_name)
	print("HABILIDADE: ", ability_name)

	# 2. Se a busca retornar null, a habilidade não existe (Funciona como o antigo '.has()')
	if ability_data == null:
		return false

	# 3. Verifica o Cooldown (A sintaxe do dicionário de cooldowns está correta, pois current_cooldowns DEVE ser um Dictionary)
	return not current_cooldowns.has(ability_name) or current_cooldowns[ability_name] <= 0


func use_ability(ability_name: String, target_node: CharacterBody2D):
	# --- 1. BLOQUEIO DE MUNIÇÃO (CRÍTICO) ---
	if ability_name == "Tiro De Precisão" or ability_name == "Atirar":
		if ted_ammo <= 0:
			# 🌟 O BLOQUEIO É ACIONADO AQUI 🌟
			batle_root.last_action_was_blocked = true 
			batle_root.trigger_battle_talk(self, "Eu até atiraria.. mas estou recarregando", 1.5)
			return # Sai imediatamente, impedindo o SUPER de rodar.

	# --- 2. BLOQUEIO DE HABILIDADES OU OVERRIDES (CRÍTICO) ---
	if batle_root.is_currently_executing_override:
		# Desativa a variavel de controle pra não afetar outros overrides
		batle_root.is_currently_executing_override = false
		# Se a habilidade atual for um OverRRide, passa e ignora o can use ability
		pass
	else:
		if not can_use_ability(ability_name):
			batle_root.last_action_was_blocked = true
			print(data.nome, " não pode usar ", ability_name, " agora.")
			cannot_use_ability = true
			return
		else:
			cannot_use_ability = false


	var target_name: String
	if not is_instance_valid(target_node):
		target_name = "ALVO INVÁLIDO/NÃO ENCONTRADO"
	elif target_node.has_method("get_node_or_null"): # Checa se é um nó
		# Se o alvo é um PersonagemBase e tem o 'data', use o nome:
		target_name = target_node.data.nome
	else:
		# Caso contrário, é um alvo genérico
		target_name = "inimigo" 


	var ability_data: HabilidadeData = get_ability_by_name(ability_name)
	print(data.nome, " usa ", ability_name, " em ", target_name)

	# Lógica de dano
	if ability_data.dano_base > 0:
		target_node.take_damage(ability_data.dano_base)

	# Lógica de efeito de status
	if ability_data.efeito_status != "Nenhum":
		target_node.apply_status_effect(ability_data.efeito_status, self)

	# Lógica de recarga
	if ability_data.custo_recarca > 0:
		current_cooldowns[ability_name] = ability_data.custo_recarca

	if ability_data.custo_recarca > 0:
		current_cooldowns[ability_name] = ability_data.custo_recarca

	# Lógica específica de cada personagem ou habilidade pode ir aqui
	# ou ser chamada por sinais.


func apply_status_effect(effect: String, source_node: CharacterBody2D):
	# 1. Determinar a Duração do Efeito (Exemplo Simples)
	var duration: int = 0
	match effect:
		"Sangramento":
			duration = 3  # Dura 3 turnos
		"Cegueira":
			duration = 2
		"Vergonha":
			duration = 2  # Vera só se envergonha por 2 turno
		"Provocar":
			duration = 2 
		# Adicione outros efeitos aqui

	if duration > 0:
		# Adiciona ou reinicia o efeito no dicionário
		current_effects[effect] = duration
		print(data.nome, " FOI AFETADO por ", effect, " (Duração: ", duration, ")")

		# [Lógica visual de Status Effect deve ser implementada aqui]

	# Implementar lógica de aplicação de status (cegueira, atordoamento, vergonha)
	if effect == "Provocar":
		emit_signal("status_effect_applied", effect, self)


func _on_area_2d_input_event(viewport: Node, event: InputEvent, shape_idx: int):
	# Condição A: A batalha está no estado de espera por alvo (PLAYER_SELECTING_TARGET)
	if batle_root.current_state == batle_root.BattleState.PLAYER_SELECTING_TARGET:
		# 1. Checa se é um clique do mouse (botão esquerdo)
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			# Passamos 'self' para identificar qual instância de inimigo foi clicada.
				batle_root.handle_target_selected(self)
				print("clicado")


# res://Scripts/Characters/Ted.gd (Adicione esta função auxiliar)

# Esta função será chamada quando o Tiro de Precisão/Atirar for executado
func play_sfx(path: String, bus_name: String = "SFX"):
	# 1. Carrega o recurso de áudio (assumindo que o arquivo está na pasta 'res://Assets/Audio/')
	var sound_stream = load(path) 

	if sound_stream:
		# 2. Atribui o stream e define o Bus
		sfx_player.stream = sound_stream
		sfx_player.bus = bus_name
		
		# 3. Executa o som
		sfx_player.play()
		print("OK: Arquivo de áudio encontrado no caminho:", path)
	else:
		print("ERRO: Arquivo de áudio não encontrado no caminho:", path)


func die():
	print(data.nome, " foi derrotado.")
	# CRUCIAL: Emite o sinal para que o BattleManager comece a limpeza
	emit_signal("defeated", self) 
