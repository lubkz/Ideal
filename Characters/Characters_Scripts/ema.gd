extends PersonagemBase

# BATLE_ROOT JÁ EXISTE NO PERSONAGEMBASE 

# Função sobrescrita para adicionar a lógica de Contenção/Diálogo da Ema
func use_ability(ability_name: String, target_node: CharacterBody2D):
	# 1. Executa a lógica da classe base primeiro (checa recarga, aplica dano, etc.)
	# Note: Você pode precisar ajustar como use_ability() é chamada no BattleManager
	super.use_ability(ability_name, target_node) 

	if not cannot_use_ability:
		# 2. Adiciona a lógica específica APENAS SE a habilidade usada for "Diálogo"
		if ability_name == "Diálogo":
			# Chamada ao BattleManager para redução de Crise
			
			# Diminuir Corrupção (Ação primária do Diálogo)
			batle_root.diminuir_corrupcao(10) 
			batle_root.diminuir_tensao(30)

			# Lógica para reduzir a Tensão (a parte que pode falhar)
			if randf() < 0.7: 
				batle_root.aumentar_tensao(-10) # Reduzir Tensão
				batle_root.trigger_battle_talk(self, "Ouvindo seus medos...")
			else:
				batle_root.trigger_battle_talk(self, "Não está funcionando...")

		if ability_name == "Chute Desajeitado":
			batle_root.trigger_battle_talk(self, "Ow! Não chega tão perto!")
			play_sfx("res://Sound_Effects/punch-03-352040.mp3", "SFX")
		
		if ability_name == "Cura Açucarada":
			target_node.heal(35)
			batle_root.trigger_battle_talk(self, "Não é muito... mas espero ajudar.")
			play_sfx("res://Sound_Effects/084373_heal-36672.mp3", "SFX")
	else:
		batle_root.trigger_battle_talk(self, "Não consigo...")

	# Se ela usar outra habilidade (ex: um ataque físico), a lógica base (super.) cuida disso.
