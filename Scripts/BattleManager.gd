# res://Scripts/BattleManager.gd
extends Node2D # extends o Node raiz da cena de batalha

enum BattleState {
	WAITING_FOR_PLAYER_INPUT,
	PLAYER_SELECTING_TARGET,
	EXECUTING_TURN,
	ENEMY_TURN,
	BATTLE_END
}

@onready var action_panel: MarginContainer = $HUD/ActionPanel
@onready var attack_panel: MarginContainer = $HUD/AttackPanel
@onready var focus_painel: MarginContainer = $HUD/FocusPainel

# Adicionar ao BattleManager.gd (se já não estiver lá)
var BattleTalkScene = preload("res://Cenas/BattleTalk.tscn")

var current_state: BattleState = BattleState.WAITING_FOR_PLAYER_INPUT

var current_chta: CharacterBody2D = null

# Contadores Globais
var party_tension: int = 0
var enemy_corruption: int = 0

var current_party_index: int = 0 # Para iterar os turnos dos membros da party
var current_enemy_index: int = 0 # Para iterar os turnos dos inimigos da party
const ENEMY_TURN_DELAY = 1.0 # Breve delay entre os turnos dos inimigos para não ser instant

var current_character: CharacterBody2D = null

const VOLUME_MAX = 0.0     # Volume máximo (0 dB)
const VOLUME_SILENCE = -80.0 # Volume de silêncio (-80 dB)

# Rastreia o nó que está provocando a Party/Inimigos. Null se ninguém estiver provocando.
var current_agro_target: CharacterBody2D = null

# Referências para os personagens e inimigos (serão atribuídas no _ready)
var ema_node 
var ted_node 
var lucio_node 
var vera_node 
var inimigo_node 
var inimigo_node_2

@onready var party_tension_bar: ProgressBar = $HUD/FocusPainel/MarginContainer/HboxContainer/VBoxContainer_Data/TensionPartyBar/PartyTensionBar
@onready var enemy_corruption_bar: ProgressBar = $HUD/EnemyPainel/MarginContainer/Inimigos/Enemy/EnemyCorruptionBar
@onready var enemy_corruption_bar2: ProgressBar = $HUD/EnemyPainel/MarginContainer/Inimigos/Enemy2/EnemyCorruptionBar

@onready var ted_hp_bar: ProgressBar = $HUD/FocusPainel/MarginContainer/HboxContainer/VBoxContainer_Data/PartyHPbars/Ted/TedHp
@onready var ema_hp_bar: ProgressBar = $HUD/FocusPainel/MarginContainer/HboxContainer/VBoxContainer_Data/PartyHPbars/Global_data/VBoxContainer/Ema/EmaHp
@onready var vera_hp_bar: ProgressBar = $HUD/FocusPainel/MarginContainer/HboxContainer/VBoxContainer_Data/PartyHPbars/Global_data/VBoxContainer/Vera/VeraHp
@onready var lucio_hp_bar: ProgressBar = $HUD/FocusPainel/MarginContainer/HboxContainer/VBoxContainer_Data/PartyHPbars/Global_data/VBoxContainer/Lucio/LucioHp
@onready var inimigo_hp_bar: ProgressBar = $HUD/EnemyPainel/MarginContainer/Inimigos/Enemy/EnemyHP
@onready var inimigo_hp_bar2: ProgressBar = $HUD/EnemyPainel/MarginContainer/Inimigos/Enemy2/EnemyHP

@onready var slot_0_button: Button = $HUD/AttackPanel/MarginContainer/IntPanel/Botoes/HBoxContainer/Button
@onready var slot_1_button: Button = $HUD/AttackPanel/MarginContainer/IntPanel/Botoes/HBoxContainer/Button2
@onready var slot_2_button: Button = $HUD/AttackPanel/MarginContainer/IntPanel/Botoes/HBoxContainer2/Button3

@onready var animated_sprite_2d: AnimatedSprite2D = $HUD/FocusPainel/MarginContainer/HboxContainer/VBoxContainer_portrait2/MarginContainer/AnimatedSprite2D

@onready var layer_1: AudioStreamPlayer = $Layer1
@onready var layer_2: AudioStreamPlayer = $Layer2
@onready var layer_3: AudioStreamPlayer = $Layer3


# FLAG: Indica que o ataque foi BLOCKED (ex: por cooldown ou falta de munição)
var last_action_was_blocked: bool = false
# NOVO: Flag para dizer ao sistema que a ação atual é um Override forçado.
var is_currently_executing_override: bool = false

# Sinal pra verificar o node que recebeu dano e o atacante desse node // Especifico para passiva de Ted e Ema
signal damage_executed(damaged_node, attacker_node) 
# NOVO SINAL: Avisa a todos que uma rodada completa terminou
signal round_finished 

# Lista de personagens da party
var party_members: Array[CharacterBody2D] = []

# Lista de Inimigos na batalha
var all_enemies: Array[CharacterBody2D] = []
# Armazena o índice da habilidade que o jogador escolheu ANTES de escolher o alvo
var current_ability_index: int = -1 

func _ready():
	# Layers da música // Baseada na lógica de tensão
	layer_1.play()
	layer_2.play()
	layer_3.play()
	
	# Atribuição do sprite base
	animated_sprite_2d.play("normal")
	
	# 1. ATRIBUIÇÃO EXPLÍCITA E BUSCA DOS NÓS NA CENA
	ema_node = get_node_or_null("Ema")
	ted_node = get_node_or_null("Ted")
	lucio_node = get_node_or_null("Lucio")
	vera_node = get_node_or_null("Vera")
	
	# Busca pelo inimigo (apenas para atribuição)
	inimigo_node = get_node_or_null("Inimigo")
	inimigo_node_2 = get_node_or_null("Inimigo2")

	# 2. CONSTRUÇÃO E LIMPEZA DO ARRAY DA PARTY (USANDO AS VARIÁVEIS GLOBAIS)
	party_members.clear()

	# Adiciona os MEMBROS DA EQUIPE ao array SOMENTE se o nó for válido (aqui está a ordem de ação):
	if is_instance_valid(ema_node): party_members.append(ema_node)
	if is_instance_valid(ted_node): party_members.append(ted_node)
	if is_instance_valid(lucio_node): party_members.append(lucio_node)
	if is_instance_valid(vera_node): party_members.append(vera_node)

	# Adiciona a lista dos INIMIGOS ao array SOMENTE se o nó for válido (aqui está a ordem de ação):
	if is_instance_valid(inimigo_node): all_enemies.append(inimigo_node)
	if is_instance_valid(inimigo_node_2): all_enemies.append(inimigo_node_2)

	# 3. VERIFICAÇÃO CRÍTICA DOS MEMBROS
	if party_members.is_empty():
		print("ERRO CRÍTICO: NENHUM PERSONAGEM ENCONTRADO. Cheque os nomes dos nodes (Ema, Ted, etc.) na cena.")
		return

	# 3. VERIFICAÇÃO CRÍTICA DOS INIMIGOS
	if all_enemies.is_empty():
		print("ERRO CRÍTICO: NENHUM INIMIGO ENCONTRADO. Cheque os nomes dos nodes (Inimigo, Inimigo2, etc.) na cena.")
		return

	# CONECTA OS SINAIS A CADA MEMBRO RESPECTIVAMENTE DA PARTY PRA CHECAR STATUS ESSENCIAIS E VISUAIS!
	for member in party_members:
		# Conecta o sinal do personagem à função _on_hp_changed do BattleManager
		member.hp_changed.connect(_on_hp_changed)
		# Conecta o sinal para detectar MORTE
		member.defeated.connect(_on_character_defeated) # <--- CONEXÃO NOVA
		# Inicializa a barra de HP na abertura da cena
		member.emit_signal("hp_changed", member.current_hp, member.data.hp_max, member)

		# Sistema base inicial para FORMATAR o COOLDOWN das HABILIDADES DOS MEMBROS
		print("INICIALIZANDO COOLDOWNS PARA O INÍCIO DA BATALHA...")
		# Pega a lista de recursos de habilidades do PersonagemData
		var abilities_array = member.data.habilidades
		# 2. Itera sobre cada habilidade
		for ability_data in abilities_array:
			var cooldown_cost = ability_data.custo_recarca
			
			 # 3. Se o custo for maior que zero, coloca a habilidade em cooldown
			if cooldown_cost > 0:
				# current_cooldowns é um dicionário no PersonagemBase (member)
				member.current_cooldowns[ability_data.nome] = cooldown_cost
				print(member.data.nome, " - Habilidade '", ability_data.nome, "' em recarga inicial: ", cooldown_cost, " turnos.")

	# CONECTA OS SINAIS A CADA INIMIGO RESPECTIVAMENTE DA PARTY PRA CHECAR STATUS ESSENCIAIS E VISUAIS!
	for enemy in all_enemies:
		# Conecta o sinal do personagem à função _on_hp_changed do BattleManager
		enemy.hp_changed.connect(_on_hp_changed)
		
		enemy.status_effect_applied.connect(_on_effect_applied)
		
		enemy.defeated.connect(_on_character_defeated) # <--- CONEXÃO NOVA

		# Inicializa a barra de HP na abertura da cena
		enemy.emit_signal("hp_changed", enemy.current_hp, enemy.data.hp_max, enemy)

	# Sinal para verificar quem tomou dano para a função do Ted Com Ema
	if is_instance_valid(ted_node):
		print("SINAL CONECTADO: Ted está ouvindo o dano.")
		self.damage_executed.connect(ted_node.on_damage_taken_by_party)

	# 🌟 NOVO: Conexão de Lúcio (Contra-Ataque) 🌟
	if is_instance_valid(lucio_node):
		self.damage_executed.connect(lucio_node.on_damage_taken_by_party)

	# 4. INICIALIZAÇÃO DE VARIÁVEIS E HUD
	# Configura as barras de progresso
	party_tension_bar.max_value = 100 
	enemy_corruption_bar.max_value = 100 
	update_ui()
	
	# 5. INÍCIO DO FLUXO
	current_party_index = 0
	current_character = party_members[current_party_index]
	start_player_turn()


func start_player_turn():
	current_character = party_members[current_party_index]

	# 1. Checa se o Personagem existe
	#print("CHECK 1 (Character): ", is_instance_valid(current_character))

	# 2. Checa se o Resource de dados está anexado
	#print("CHECK 2 (Data): ", current_character.data != null) # Se isso for FALSE, o erro é no Inspector
	
	# 1. Define quem é o personagem ativo (Ema, Ted, etc.)
	#current_character = party_members[current_party_index]

	# 🌟 CRÍTICO: CHECAGEM DE VALIDADE 🌟
	if not is_instance_valid(current_character):
		print(current_character.data.nome, " (Inimigo) foi removido. Pulando turno.")
		_advance_enemy_turn() # Pula para o próximo inimigo/fase
		return

	print("\n--- Turno de: ", current_character.data.nome, " ---")
	action_panel.show()

	# 2. Muda o estado para que o input seja aceito
	_set_battle_state(BattleState.WAITING_FOR_PLAYER_INPUT)

	# 3. Lógica para REALÇAR O PERSONAGEM ATIVO (Opcional, mas útil)
	emit_signal("personagem_ativo_mudou", current_character)

	# 4. Lógica para HABILITAR OS BOTÕES AQUI (Se o HUD for filho direto do BattleManager)
	# Se o seu painel de ações for filho, você o habilita aqui:
	# $HUD/PainelDeAcoes.show() 


# Função que será chamada para personalizar o menu de ataques
func _prepare_attack_menu():
	# O current_character já está definido pelo start_player_turn()
	var char_abilities = current_character.data.habilidades # Array de HabilidadeData

	# Mapeamento dos botões para seus respectivos índices
	var button_map = {
		slot_0_button: 0,
		slot_1_button: 1,
		slot_2_button: 2
	}

	# Itera sobre os botões para atualizar texto e visibilidade
	for button in button_map:
		var index = button_map[button]
		# 1. Checa se o índice é válido para o array de habilidades do personagem
		if index < char_abilities.size():
			var ability_data = char_abilities[index]
			# 2. Define o texto do botão com o nome da habilidade (ex: "Tiro De Precisão")
			button.text = ability_data.nome 
			button.show()
		else:
			# 3. Se não houver habilidade (array menor), esconde o botão
			button.text = ""
			button.hide()

	print("UI de ataque atualizada para: ", current_character.data.nome)


func _set_battle_state(new_state: BattleState):
	current_state = new_state
	match current_state:
		BattleState.WAITING_FOR_PLAYER_INPUT:
			print("Esperando input do jogador...")
			# Lógica para habilitar botões de ação e indicar qual personagem está ativo
			# AQUI é onde você habilita o painel de ações para o jogador.
			# Ex: $HUD/PainelDeAcoes.enable_input()
			pass
		BattleState.PLAYER_SELECTING_TARGET:
			print("Jogador selecionando alvo...")
			pass
		BattleState.EXECUTING_TURN:
			print("Executando turno...")
			# Ações da party
			pass
		BattleState.ENEMY_TURN:
			print("Turno do inimigo...")
			# Lógica de IA do inimigo
			pass
		BattleState.BATTLE_END:
			print("Batalha finalizada.")
			# Lógica de fim de batalha
			pass


func choose_random_enemy() -> CharacterBody2D:
	# Filtra apenas inimigos que estão vivos
	var live_enemies: Array[CharacterBody2D] = []

	for enemy in all_enemies:
		if enemy.current_hp > 0:
			live_enemies.append(enemy)

	if live_enemies.is_empty():
		return null # Não há alvos vivos
 
	# Retorna um alvo aleatório
	return live_enemies.pick_random()


# --- Funções de Modificação ---

func aumentar_tensao(valor: int):
	# Cálculo de tensão
	party_tension = mini(party_tension + valor, party_tension_bar.max_value)

	# Garante que a party tension não fique negativa
	party_tension = maxi(0, party_tension) # Garante que não fica negativo

	update_ui()
	
	handle_layers()
	
	print("Tensão da Party: ", party_tension, "%")
	# Verifique se a tensão atingiu limites para eventos de crise
	if party_tension <= 32:
		animated_sprite_2d.play("normal")
	if party_tension >= 33:
		animated_sprite_2d.play("ted")
	if party_tension >= 70: # Exemplo: 75% da tensão máxima
		animated_sprite_2d.play("tensao")
		print("Tensão alta! Overrides podem acontecer!")


func handle_layers():
	# Criar um tween para aumentar o volume
	var volume_tween = create_tween()
	volume_tween.set_parallel(true)

	# --- NIVEL 3: CRISE CRÍTICA (Tensão > 54) ---
	if party_tension >= 70:
		volume_tween.tween_property($Layer3, "volume_db", VOLUME_MAX, 1.5)
		volume_tween.tween_property($Layer2, "volume_db", VOLUME_MAX, 1.5)
		print("TENSÃO MAXIMA")

	# --- NIVEL 2: ALERTA (Tensão >= 33 e < 55) ---
	elif party_tension >= 33:
		# Diminuir o volume da Layer 2 antes de estabelecer a Layer 1, em caso de diminuição da tensão
		volume_tween.tween_property($Layer3, "volume_db", VOLUME_SILENCE, 1.5)
		volume_tween.tween_property($Layer2, "volume_db", VOLUME_MAX, 1.5)
		print("TENSÃO MEDIA")

	# --- NIVEL 1: BASE (Tensão < 33) ---
	else:
		volume_tween.tween_property($Layer3, "volume_db", VOLUME_SILENCE, 1.5) # Layer 3 SAI
		volume_tween.tween_property($Layer2, "volume_db", VOLUME_SILENCE, 1.5) # Layer 2 SAI
		print("MÚSICA: ESTADO BASE (Layer 1) ATIVADO.")



func diminuir_corrupcao(valor: int):
	enemy_corruption = maxi(enemy_corruption - valor, 0)
	update_ui()
	print("Corrupção do Inimigo diminuída para: ", enemy_corruption)


func diminuir_tensao(valor: int):
	party_tension = maxi(party_tension - valor, 0)
	update_ui()
	print("Tensão da party diminuída para: ", party_tension)


func aumentar_corrupcao_inimigo(valor: int): # Renomeei para evitar conflito com 'diminuir_corrupcao'
	# Calcular corrupção
	enemy_corruption = mini(enemy_corruption + valor, enemy_corruption_bar.max_value)

	update_ui()
	print("Corrupção do Inimigo: ", enemy_corruption, "%")
	# Verifique se a corrupção do inimigo atingiu limites para transições
	if enemy_corruption >= 100:
		print("Inimigo totalmente corrupto! Forma final?")


func update_ui():
	party_tension_bar.value = party_tension
	enemy_corruption_bar.value = enemy_corruption
	# Atualizar barras de HP dos personagens individuais no HUD
	# (Isso será feito nos scripts dos próprios personagens ou diretamente aqui, dependendo da sua arquitetura)


func trigger_battle_talk(personagem_node: Node, dialogo: String, duration: float = 3.0):
	var talk_instance = BattleTalkScene.instantiate()

	# 1. Encontra o ponto de ancoragem do diálogo no personagem
	# O Godot precisa saber onde 'nascer' o texto.
	var anchor_node = personagem_node.get_node_or_null("TalkPosition") # Ou o nome que você usou

	if anchor_node:
		# Pega a posição global do Marker2D
		talk_instance.global_position = anchor_node.global_position
	else:
		# Se não encontrar o Marker2D, usa a posição global do próprio personagem como fallback
		talk_instance.global_position = personagem_node.global_position + Vector2(0, -100)

	# 2. Adiciona a cena à árvore principal
	get_tree().root.add_child(talk_instance) 

	# 3. Inicia o diálogo e a animação
	talk_instance.start_talk(dialogo, duration)


# Supondo que 'chosen_ability_name' é a string do nome da habilidade que o jogador escolheu
func process_player_action(character_node: CharacterBody2D, chosen_ability_name: String, target_node: CharacterBody2D):
	# 1. Checar Overrides
	var override_happened: bool = _check_override(character_node, chosen_ability_name, target_node)

	if not override_happened:
		# 2. Se nenhum override, execute a ação escolhida pelo jogador
		character_node.use_ability(chosen_ability_name, target_node)


# (NOVA FUNÇÃO)
# Esta função é chamada pelo Node do Inimigo quando o jogador clica nele
func handle_target_selected(target_node: CharacterBody2D):
	if current_state != BattleState.PLAYER_SELECTING_TARGET:
		print("Ainda não é hora de escolher um alvo!")
		return

	var char_abilities = current_character.data.habilidades
	var is_ally_target = party_members.has(target_node)

	# 1. Pega o nome da habilidade pelo índice salvo
	if current_ability_index >= 0 and current_ability_index < char_abilities.size():
		var chosen_ability_name = char_abilities[current_ability_index].nome

		# 2. Executa a ação principal
		# Você pode esconder o AttackPanel aqui, se quiser que ele volte ao ActionPanel
		attack_panel.hide()

		# Checar se é uma habilidade de cura e se é usada em um aliado
		if chosen_ability_name == "Cura Açucarada": # Habilidades de cura ou Buff em aliados
			if is_ally_target: # Se o alvo for um aliado
				process_player_action(current_character, chosen_ability_name, target_node)
			else:
				# Por hora, não é possível curar inimigos, mas será usado mais pra frente com novas
				# ideias, como dano em inimigos ao cura-los, ou dar debuffs
				return
				
		# Se não for uma habilidade de cura, não tem distinção e o ataque é executado
		else:
			process_player_action(current_character, chosen_ability_name, target_node)

		if last_action_was_blocked:
			# Limpar a Flag para o Próximo turno
			last_action_was_blocked = 0
			# Voltando para o Menu
			current_ability_index = -1
			_set_battle_state(BattleState.WAITING_FOR_PLAYER_INPUT) 
			# 3. Faz a transição veia peba
			attack_panel.hide()
			action_panel.show()
		else:
			# 3. Limpa o índice e avança o turno
			current_ability_index = -1
			_advance_party_member()
	else:
		print("ERRO: Índice de habilidade inválido.")
		_set_battle_state(BattleState.WAITING_FOR_PLAYER_INPUT) # Retorna ao menu


func _check_override(character_node: CharacterBody2D, chosen_ability_name: String, target_node: CharacterBody2D) -> bool:
	# 🌟 PASSO 1: CHECAGEM CRÍTICA DE SOBREVIVÊNCIA PROS INIMIGOS🌟
	if all_enemies.is_empty():
		# Não há inimigos vivos, não há crise de corrupção.
		return false 
	
	# 🌟 CORREÇÃO CRÍTICA: Use o índice [0] para a checagem de status 🌟
	# Se o array não estiver vazio, o primeiro inimigo vivo está sempre no índice [0].
	var current_enemy = all_enemies[0] 
	
	if not is_instance_valid(current_enemy):
		return false

	var character_data: PersonagemData = character_node.data
	var enemy_data: InimigoData = current_enemy.data # Assumindo inimigo_node já foi carregado

	# --- Override da Vera (Caos) ---
	if character_node == vera_node and character_data.nome == "Vera":
		# Condição: BattleManager.tensão > 75 E randf() < 0.25 (25% de chance)
		if party_tension > 45 and randf() < 0.75:
			# 1. ATIVA A BANDEIRA DE OVERRIDE
			is_currently_executing_override = true
			
			print("OVERRIDE: Vera (Caos) ativado!")
			trigger_battle_talk(vera_node, "Eu me sinto... OTIMA!")
			vera_node.use_ability("Override de Fúria", target_node) # Assume que "Override de Fúria" é uma habilidade em VeraData.tres
			vera_node.apply_status_effect("Vergonha", vera_node) # Debuff
			vera_node.turn_skipped = true # <<<<< NOVO: O CUSTO É PAGO AQUI
			aumentar_tensao(-25)
			return true
		else:
			print("OVERRIDE: Vera (Caos) não ATIVADO")


   	# -----------------------------------------------------------------
	
	# --- NOVO: Override do Lúcio (Ceticismo) ---
	# -----------------------------------------------------------------
	# Condição de Disparo: Ema agindo E habilidade é "Diálogo" E Crise alta (> 50)
	# Assumindo que lucio_node e ema_node são variáveis acessíveis no BattleManager.
	if character_node == ema_node and chosen_ability_name == "Diálogo":
		# Se você está usando uma variável global para a corrupção (enemy_corruption):
		if enemy_corruption >= 90:
			print("OVERRIDE: Lúcio (Ceticismo) ativado!")
			trigger_battle_talk(lucio_node, "Bobagens. Não vai funcionar.")
			is_currently_executing_override = true

			# 1. Ação do Lúcio (usando o alvo escolhido pela Ema)
			lucio_node.use_ability("Contra-Ataque Brutal", target_node) 

			# 2. Custo do Turno (Perde o próximo turno do Lúcio)
			lucio_node.turn_skipped = true 

			# 3. CRUCIAL: Retorna TRUE. Isso fará com que process_player_action pule a ação da Ema.
			return true 

	return false # Nenhum override ocorreu


func _process_next_party_member():
	# 1. Certifica-se que o personagem atual é válido
	if current_character == null:
		_advance_party_member() # Se for nulo, tenta avançar
		return

	# 🌟 CRÍTICO: CHECAGEM DE VALIDADE 🌟
	if not is_instance_valid(current_character):
		print("Combatente inválido encontrado. Pulando turno.")
		_advance_party_member() # Pula para o próximo
		return

	# 2. CHECAGEM DO CUSTO (Ted ou Vera)
	if current_character.turn_skipped:
		print(current_character.data.nome, " (Override) PULOU O TURNO.")
		current_character.turn_skipped = false # Reseta o custo
		_advance_party_member() # Pula para o próximo
		return

	await get_tree().create_timer(1.5).timeout
	# 3. 🌟 NOVO: CHECAGEM DE OVERRIDE AUTOMÁTICO (VERA) 🌟
	# Verifica se há uma ação forçada (como a de Vera)
	var random_enemy = choose_random_enemy()
	var override_happened: bool = _check_override(current_character, "", random_enemy)

	if override_happened:
		# Se o Override da Vera (ou Lúcio) for acionado,
		# A ação já foi executada no _check_override.
		# Então, pulamos o input do jogador e avançamos o turno.
		_advance_party_member()
		return

	# 3. Se não pulou, o turno começa normalmente
	start_player_turn() # Sua função original de setup de UI (Waiting for input)


# Avançar os turnos
func _advance_party_member():
	# 1. Avança o índice
	current_party_index += 1

	# 2. Checa se a party terminou sua rodada
	if current_party_index >= party_members.size():
		current_party_index = 0 
		start_enemy_turn() # Passa para o inimigo
	else:
		# Passa para o próximo membro da party
		current_character = party_members[current_party_index]
		_process_next_party_member()


func start_enemy_turn():
	_set_battle_state(BattleState.ENEMY_TURN)
	current_enemy_index = 0
	# Adicione uma função para a IA que simula o pensamento
	_process_enemy_action()


func _process_enemy_action():
	if current_enemy_index >= all_enemies.size():
		# 1. A Fase do Inimigo acabou. Volta para o início da Party.
		current_party_index = 0
		# 2. CRUCIAL: EMITIR O SINAL GLOBAL DE FIM DE ROUND
		emit_signal("round_finished")
		start_player_turn()
		return

	current_character = all_enemies[current_enemy_index]
	
	print("\n--- Turno de:", current_character.data.nome, "---")

	# O personagem ativo É o inimigo agora
	var inimigo_ativo = current_character
	var habilidade_nome: String = ""

	if inimigo_ativo.data.habilidades.size() > 0:
		# Acessa o PRIMEIRO objeto HabilidadeData no Array
		var primeira_habilidade_data: HabilidadeData = inimigo_ativo.data.habilidades[0]
		habilidade_nome = primeira_habilidade_data.nome
	else:
		print("ERRO: Inimigo Sem Habilidade")
		return


	# 4. Escolha de Alvo (Alvo Aleatório na Party Viva) e Checa a validade
	var live_targets = []
	for member in party_members:
		if member.current_hp > 0:
			live_targets.append(member) 

	if live_targets.is_empty():
		print("Fim de Jogo ou Party Imune")
		# Fim de Jogo ou Party Imune
		_advance_enemy_turn() # Avança, pois este inimigo não pode agir
		return

	# Checagem necessária para verificar se tem alguém usando provocar na Party Members
	var alvo_node 
	if is_instance_valid(current_agro_target) and current_agro_target.current_hp > 0:
		print("instancia válida para o agro target")
		if randf() <= 0.75: # 75% de chance de atacar o alvo que está provocando 
			alvo_node = current_agro_target
			print("Habilidade de agro funcionou para: ", current_agro_target)
		else:
			print("Inimigo resistiu a provocação de ", current_agro_target.data.nome)
			alvo_node = live_targets.pick_random()
			print("Alvo aleatório escolhido: ", alvo_node) 
	else:
		print("sem provocações, atacando normalmente")
		alvo_node = live_targets.pick_random()
		print("Alvo aleatório escolhido: ", alvo_node)

	# 5. Execução da Ação (Com atraso para visualização)
	await get_tree().create_timer(ENEMY_TURN_DELAY).timeout

# 🌟 NOVO: CHECAGEM CRÍTICA DE VALIDADE 🌟
	if not is_instance_valid(inimigo_ativo) or not is_instance_valid(alvo_node):
		print("AVISO: Atacante ou Alvo foi removido antes da execução. Pulando ação.")
		_advance_enemy_turn()
		return

	# 3. Executa a ação do inimigo
	process_player_action(inimigo_ativo, habilidade_nome, alvo_node)

	emit_signal("damage_executed", alvo_node, inimigo_ativo) 

	# 🌟 CRUCIAL: Adicionar a espera para o Godot limpar o nó
	await get_tree().process_frame

	# 4 Aumentar a tensão por ataque
	#aumentar_tensao(10)

	# 5. Finaliza o turno do inimigo e volta para a party
	_advance_enemy_turn()


func _advance_enemy_turn():
	# Incrementa o índice para o próximo inimigo
	current_enemy_index += 1
	current_character = party_members[current_enemy_index]

	# Chama a função para processar o próximo inimigo na lista
	# A função irá verificar se o turno de inimigos acabou.
	_process_enemy_action()


# Função de Retorno (Callback) para receber o sinal HP_CHANGED
# Recebe os parâmetros que o PersonagemBase envia (HP, HP_Max, e o Node que mudou)
func _on_hp_changed(current_hp_value: int, max_hp_value: int, changed_node: CharacterBody2D):
	# O código aqui precisa identificar qual barra (Ema, Ted, Inimigo) deve ser atualizada.
	var hp_bar: ProgressBar = null
	
	# Lógica de identificação e atribuição da barra de HP (você deve ter @onready vars para cada barra)
	if changed_node == ema_node:
		hp_bar = ema_hp_bar # Assumindo @onready var ema_hp_bar existe
	elif changed_node == ted_node:
		hp_bar = ted_hp_bar
	elif changed_node == vera_node:
		hp_bar = vera_hp_bar
	elif changed_node == lucio_node:
		hp_bar = lucio_hp_bar
	elif changed_node == inimigo_node:
		hp_bar = inimigo_hp_bar
	elif changed_node == inimigo_node_2:
		hp_bar = inimigo_hp_bar2

	# 2. Atualizar o valor da barra (se a barra for encontrada)
	if is_instance_valid(hp_bar):
		hp_bar.max_value = max_hp_value
		hp_bar.value = current_hp_value
		print("HP VISUALMENTE ATUALIZADO para ", changed_node.data.nome, ": ", current_hp_value)
	else:
		# Se você vir este print, o caminho do @onready da barra de HP está errado
		print("AVISO: Barra de HP não encontrada ou inválida para ", changed_node.data.nome)


func _on_character_defeated(defeated_node: CharacterBody2D):
	# 1. REMOÇÃO DOS ARRAYS CRUCIAL para parar o loop de turnos	
	if party_members.has(defeated_node):
		party_members.erase(defeated_node)
		print("MEMBRO DE PARTIDA REMOVIDO: ", defeated_node.data.nome)
		# Se for um membro da Party, checar Game Over
		_check_battle_status() 
		
	elif all_enemies.has(defeated_node):
		all_enemies.erase(defeated_node)
		print("INIMIGO REMOVIDO: ", defeated_node.data.nome)
		# Se for um inimigo, checar Vitória
		_check_battle_status() 

	# 2. REMOÇÃO VISUAL DA CENA
	# O nó é removido da cena para liberar memória.
	defeated_node.queue_free() 


func _on_effect_applied(effect_name: String, target: CharacterBody2D):
	if effect_name == "Provocar":
		current_agro_target = lucio_node
		print(target, "Está provocado")


# 3. Lógica de Fim de Batalha (Você precisa desta função)
func _check_battle_status():
	if party_members.is_empty():
		print("FIM DE JOGO: TODOS PERDERAM!")
		_set_battle_state(BattleState.BATTLE_END)
		# Lógica de tela de Game Over
		return

	if all_enemies.is_empty():
		print("VITÓRIA!")
		_set_battle_state(BattleState.BATTLE_END)
		# Lógica de tela de Vitória
		return



func _on_attack_button_pressed() -> void:
	# 1. PREPARA O MENU ANTES DE MOSTRAR
	_prepare_attack_menu()
	action_panel.hide()
	attack_panel.show()


func _on_Attack_button_pressed() -> void:
	attack_panel.hide()

		# 1. Verifica se é o estado de input
	if current_state != BattleState.WAITING_FOR_PLAYER_INPUT:
		trigger_battle_talk(current_character, "Não escolhi quem atacar ainda...", 1.0)
		return
		
	# --- NOVO: Declaração da variável FORA do bloco IF ---
	var habilidade_nome: String = ""
	# --- FIM DA NOVA DECLARAÇÃO ---

	# 1. Salva o índice da habilidade escolhida
	current_ability_index = 0 

	# 2. Entra no novo estado de espera (o menu AttackPanel deve permanecer visível)
	_set_battle_state(BattleState.PLAYER_SELECTING_TARGET)

	print("Habilidade [0] selecionada. Clique no alvo.")

	#aumentar_corrupcao_inimigo(35)
	#aumentar_tensao(10)


func _on_Attack2_button_pressed() -> void:
	attack_panel.hide()

		# 1. Verifica se é o estado de input
	if current_state != BattleState.WAITING_FOR_PLAYER_INPUT:
		trigger_battle_talk(current_character, "Não escolhi quem atacar ainda...", 1.0)
		return
		
	# --- NOVO: Declaração da variável FORA do bloco IF ---
	var habilidade_nome: String = ""
	# --- FIM DA NOVA DECLARAÇÃO ---

	# 1. Salva o índice da habilidade escolhida
	current_ability_index = 1

	# 2. Entra no novo estado de espera (o menu AttackPanel deve permanecer visível)
	_set_battle_state(BattleState.PLAYER_SELECTING_TARGET)

	print("Habilidade [1] selecionada. Clique no alvo.")

	#aumentar_corrupcao_inimigo(35)
	#aumentar_tensao(10)


func _on_Attack3_button_pressed() -> void:
	attack_panel.hide()

		# 1. Verifica se é o estado de input
	if current_state != BattleState.WAITING_FOR_PLAYER_INPUT:
		trigger_battle_talk(current_character, "Não escolhi quem atacar ainda...", 1.0)
		return
		
	# --- NOVO: Declaração da variável FORA do bloco IF ---
	var habilidade_nome: String = ""
	# --- FIM DA NOVA DECLARAÇÃO ---

	# 1. Salva o índice da habilidade escolhida
	current_ability_index = 2

	# 2. Entra no novo estado de espera (o menu AttackPanel deve permanecer visível)
	_set_battle_state(BattleState.PLAYER_SELECTING_TARGET)

	print("Habilidade [2] selecionada. Clique no alvo.")

	#aumentar_corrupcao_inimigo(35)
	#aumentar_tensao(10)
