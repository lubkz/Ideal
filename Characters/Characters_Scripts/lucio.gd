extends PersonagemBase

# BATLE_ROOT JÁ EXISTE NO PERSONAGEMBASE 

func use_ability(ability_name: String, target_node: CharacterBody2D):
	super.use_ability(ability_name, target_node)
	
	if not cannot_use_ability:
		if ability_name == "Esmagamento Brutal":
			# Lógica para Lúcio (Seu ataque brutal aumenta a tensão geral por ser nojento)
			batle_root.aumentar_tensao(5) 
			play_sfx("res://Sound_Effects/sword-slash-with-a-designed-impact-185434.mp3", "SFX")
			batle_root.trigger_battle_talk(self, "Que coisa nojenta...")
		
		if ability_name == "Consciencia Macabra":
			batle_root.trigger_battle_talk(self, "Criaturas imundas miseráveis.")
			play_sfx("res://Sound_Effects/heavy-cineamtic-hit-166888.mp3", "SFX")
		
		if ability_name == "Contra-Ataque Brutal":
			batle_root.trigger_battle_talk(self, "Eu... tenho que aguentar...")
			play_sfx("res://Sound_Effects/084373_heal-36672.mp3", "SFX")
	else:
		batle_root.trigger_battle_talk(self, "Ainda não...")


# Esta função é o callback do sinal global 'damage_executed'
# Ele recebe quem foi atingido (damaged_node) e quem atacou (attacker_node)
func on_damage_taken_by_party(damaged_node: CharacterBody2D, attacker_node: CharacterBody2D):
	
	# 1. VERIFICAÇÃO DE ALVO: O Dano foi em Lúcio?
	# Usamos 'self' pois o Lúcio é o script que está rodando.
	if damaged_node != self:
		return # Se o dano não foi em Lúcio, ele não contra-ataca.

	# 2. VERIFICAÇÃO DE CONDIÇÃO: Lúcio está provocando E está vivo?
	if batle_root.current_agro_target != null:
		if batle_root.current_agro_target.data.nome == "Lcio" and self.current_hp > 0:

			print("PASSIVA LUCIO: CONTRA-ATAQUE ATIVADO contra ", attacker_node.data.nome)

			# 3. Execução da Ação (Usa a habilidade Contra-Ataque Brutal no atacante)
			self.use_ability("Contra-Ataque", attacker_node) 

			# 4. Feedback e Custo
			self.batle_root.trigger_battle_talk(self, "Não vai me derrubar fácil!", 1.5)

			# O custo (perder o próximo turno) deve ser aplicado aqui:
			self.turn_skipped = true
	else:
		print("Valor de batle_root.current_agro_target = ",batle_root.current_agro_target)
