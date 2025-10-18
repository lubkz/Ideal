extends PersonagemBase

# BATLE_ROOT JÁ EXISTE NO PERSONAGEMBASE 

var can_use_bullet: bool = true
@onready var ema: CharacterBody2D = $"../Ema"

# Você pode opcionalmente sobrescrever use_ability para lógica específica do Tiro de Precisão
# (Como o custo de recarga de 1 turno) ou deixar a base fazer o trabalho.
func use_ability(ability_name: String, target_node: CharacterBody2D):
	# Lógica de recarga do Tiro de Precisão será cuidada pela PersonagemBase
	super.use_ability(ability_name, target_node)

	if not cannot_use_ability:
		if ability_name == "Corte Rapido":
			batle_root.aumentar_tensao(5)
			batle_root.trigger_battle_talk(self, "Vamos te fatiar um pouco.")
			play_sfx("res://Sound_Effects/sword-slash-01-266296.mp3", "SFX")
		
		if ability_name == "Tiro De Precisão" and ted_ammo == 1 and not batle_root.is_currently_executing_override:
			# Feedback visual que o ataque foi bem-sucedido
			batle_root.aumentar_tensao(40)
			batle_root.trigger_battle_talk(self, "Vai ser um prazer te matar.")
			play_sfx("res://Sound_Effects/cataplax-109580.mp3", "SFX")
			await get_tree().create_timer(0.52).timeout
			play_sfx("res://Sound_Effects/9mm-pistol-shoot-short-reverb-7152.wav", "SFX")
			ted_ammo = 0
			ted_reload_ammo = 2 # Dois rounds para recarregar

		if ability_name == "Atirar" and ted_ammo == 1:
			# Feedback visual que o ataque foi bem-sucedido
			batle_root.aumentar_tensao(20)
			batle_root.trigger_battle_talk(self, "Olha! Sem mirar!")
			play_sfx("res://Sound_Effects/9mm-pistol-shoot-short-reverb-7152.wav", "SFX")
			ted_ammo = 0
			ted_reload_ammo = 2 # Dois rounds para recarregar
	else:
		batle_root.trigger_battle_talk(self, "Nah... agora não.")

# Função conectada ao sinal 'round_finished' no BattleManager.gd (no _ready do PERSONAGEMBASE)
func on_round_finished():
	# Esta linha garante que a lógica de PersonagemBase (que contém end_turn_cooldown())
	# seja executada para descontar o tempo das habilidades normais.
	super.on_round_finished() 
	if ted_ammo <= 0:
		ted_reload_ammo -= 1
		if ted_reload_ammo <= 0:
			ted_ammo = 1
			batle_root.trigger_battle_talk(self, "Munição pronta.", 1.0)
		else:
			batle_root.trigger_battle_talk(self, "Recarregando...", 0.3)


# CRÍTICO: Variável para verificar se Ted já usou sua reação nesta rodada
var skip_next_turn: bool = false
# Você precisará da referência à Ema e ao Inimigo, que podem ser passadas pelo BattleManager
# Nova função chamada pelo BattleManager quando alguém sofre dano
func on_damage_taken_by_party(damaged_node: CharacterBody2D, attacker_node: CharacterBody2D):
	print("DEBUG TED: Função de reação chamada. Alvo:", damaged_node.data.nome)
	# 1. Checa as condições do Impulso:

	# Condição A: O nó atingido é a Ema.
	if damaged_node.data.nome == "Ema" and damaged_node == batle_root.ema_node: 
		# Condição B: Ted tem um turno para gastar (não reagiu ainda)
		if not skip_next_turn and ted_ammo == 1: 
			print("PASSIVA TED: Reação Imediata Acionada!")

			# 2. Executa a Ação Forçada de Ted (Tiro de Precisão)
			self.use_ability("Tiro De Precisão", attacker_node) 
			await get_tree().create_timer(1.0).timeout  
			batle_root.trigger_battle_talk(ema, "Ted, Não!", 1.0)
			await get_tree().create_timer(1.0).timeout
			batle_root.trigger_battle_talk(self, "Oops!", 1.0)
			await get_tree().create_timer(1.0).timeout
			batle_root.trigger_battle_talk(self, "Dedo escorregou no gatilho.", 2.0)
			# Garantir que o tiro seja usado, mesmo em cooldown, mas não sem balas
			batle_root.is_currently_executing_override = true
			ted_ammo = 0
			ted_reload_ammo = 2

			# 3. Custo: Consumir o próximo turno de Ted
			self.skip_next_turn = true 
			batle_root.aumentar_tensao(10) # Custo emocional
