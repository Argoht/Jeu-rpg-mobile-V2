@tool
extends EditorScript

const RANK_DIRS: Array[String] = ["F", "E", "D", "C", "B", "A", "S"]

func _run():
	print("--- Début de la génération des NOUVELLES missions ---")
	
	var missions_data = [
		# --- RANG F ---
		{ "id": "f_marche", "title": "Marche", "desc": "Parcourir 2 km.", "rank": 0, "type": 0, "xp": 100 },
		{ "id": "f_hygiene", "title": "Hygiène", "desc": "Se brosser les dents (matin et soir).", "rank": 0, "type": 0, "xp": 75 },
		{ "id": "f_discipline", "title": "Discipline", "desc": "Aller en cours ou au travail.", "rank": 0, "type": 0, "xp": 120 },
		{ "id": "f_reveil", "title": "Réveil", "desc": "5 minutes d'étirements ou de réveil musculaire.", "rank": 0, "type": 0, "xp": 80 },

		# --- RANG E ---
		{ "id": "e_endurance", "title": "Endurance", "desc": "Marcher 5 km.", "rank": 1, "type": 0, "xp": 250, "req_end": 3 },
		{ "id": "e_apparence", "title": "Apparence", "desc": "Douche et soin du visage / tenue propre.", "rank": 1, "type": 0, "xp": 150 },
		{ "id": "e_apprentissage", "title": "Apprentissage", "desc": "Lire 10 pages ou visionner un contenu éducatif.", "rank": 1, "type": 0, "xp": 250, "req_int": 4 },
		{ "id": "e_sport", "title": "Sport", "desc": "Une séance d'entraînement.", "rank": 1, "type": 0, "xp": 300, "req_str": 4 },
		# Hebdomadaire
		{ "id": "e_hebdo_discipline", "title": "Discipline Hebdomadaire", "desc": "Tenir sa routine toute la semaine.", "rank": 1, "type": 1, "xp": 500, "stat": 5, "stat_amount": 1, "req_wis": 4 }, # +1 WIS

		# --- RANG D ---
		{ "id": "d_mouvement", "title": "Mouvement", "desc": "Marcher 7 km.", "rank": 2, "type": 0, "xp": 600, "req_end": 8 },
		{ "id": "d_soin", "title": "Soin de soi", "desc": "Entretien de la barbe/pilosité et style général.", "rank": 2, "type": 0, "xp": 250 },
		{ "id": "d_etude", "title": "Étude", "desc": "Lire 20 pages ou 2 vidéos éducatives.", "rank": 2, "type": 0, "xp": 700, "req_int": 10 },
		{ "id": "d_force", "title": "Force", "desc": "Une séance de sport complète.", "rank": 2, "type": 0, "xp": 800, "req_str": 10 },
		# Hebdomadaire
		{ "id": "d_hebdo_resistance", "title": "Résistance", "desc": "Accomplir un effort physique intense inhabituel.", "rank": 2, "type": 1, "xp": 1200, "stat": 1, "stat_amount": 2, "req_str": 12 }, # +2 STR

		# --- RANG C ---
		{ "id": "c_activite", "title": "Activité", "desc": "Marcher 10 km.", "rank": 3, "type": 0, "xp": 1400, "req_end": 16 },
		{ "id": "c_lecture", "title": "Lecture", "desc": "Lire 30 pages ou 3 vidéos éducatives.", "rank": 3, "type": 0, "xp": 1500, "req_int": 18 },
		{ "id": "c_entrainement", "title": "Entraînement", "desc": "Séance de sport intense.", "rank": 3, "type": 0, "xp": 1600, "req_str": 18 },
		{ "id": "c_souplesse", "title": "Souplesse", "desc": "Travail de mobilité ou étirements.", "rank": 3, "type": 0, "xp": 1200, "req_dex": 15 },
		# Hebdomadaire
		{ "id": "c_hebdo_savoir", "title": "Assimilation", "desc": "Terminer un livre complexe ou un cours en ligne.", "rank": 3, "type": 1, "xp": 2500, "stat": 4, "stat_amount": 2, "req_int": 20 }, # +2 INT

		# --- RANG B ---
		{ "id": "b_course", "title": "Course", "desc": "Courir 5 km.", "rank": 4, "type": 0, "xp": 3200, "req_end": 28 },
		{ "id": "b_mental", "title": "Mental", "desc": "Douche froide intégrale.", "rank": 4, "type": 0, "xp": 2200, "req_wil": 25 },
		{ "id": "b_volume", "title": "Volume", "desc": "Séance de musculation ou sport lourd.", "rank": 4, "type": 0, "xp": 3500, "req_str": 30 },
		{ "id": "b_agilite", "title": "Agilité", "desc": "Séance complète de mobilité.", "rank": 4, "type": 0, "xp": 2600, "req_dex": 28 },
		# Hebdomadaire
		{ "id": "b_hebdo_depassement", "title": "Dépassement", "desc": "Battre un record personnel en course.", "rank": 4, "type": 1, "xp": 5000, "stat": 3, "stat_amount": 3, "req_end": 35 }, # +3 END (mapped to vit later)

		# --- RANG A ---
		{ "id": "a_cardio", "title": "Cardio", "desc": "1 heure d'effort continu.", "rank": 5, "type": 0, "xp": 7000, "req_end": 45 },
		{ "id": "a_rigueur", "title": "Rigueur", "desc": "Debout avant 7h30.", "rank": 5, "type": 0, "xp": 4200, "req_wil": 40 },
		{ "id": "a_controle", "title": "Contrôle", "desc": "Séance avancée de mobilité / équilibre.", "rank": 5, "type": 0, "xp": 4800, "req_dex": 40 },
		{ "id": "a_puissance", "title": "Puissance", "desc": "Séance de sport à haute intensité.", "rank": 5, "type": 0, "xp": 7200, "req_str": 45 },
		{ "id": "a_souffle", "title": "Souffle", "desc": "3 sessions de cohérence cardiaque.", "rank": 5, "type": 0, "xp": 3500, "req_wis": 35 },
		# Hebdomadaire
		{ "id": "a_hebdo_maitrise", "title": "Maîtrise Corporelle", "desc": "Tenir une posture d'équilibre complexe (ex: handstand).", "rank": 5, "type": 1, "xp": 10000, "stat": 2, "stat_amount": 3, "req_dex": 50 }, # +3 DEX

		# --- RANG S ---
		{ "id": "s_performance", "title": "Performance", "desc": "1 heure de cardio intense.", "rank": 6, "type": 0, "xp": 14000, "req_end": 65 },
		{ "id": "s_maitrise", "title": "Maîtrise", "desc": "Se lever avant 7h30 pendant 7 jours.", "rank": 6, "type": 0, "xp": 8000, "stat": 8, "stat_amount": 1, "req_wil": 60 },
		{ "id": "s_corps", "title": "Corps", "desc": "Mobilité et contrôle corporel total.", "rank": 6, "type": 0, "xp": 9000, "req_dex": 60 },
		{ "id": "s_explosivite", "title": "Explosivité", "desc": "Séance sportive de niveau athlète.", "rank": 6, "type": 0, "xp": 15000, "req_str": 65 },
		{ "id": "s_calme", "title": "Calme", "desc": "Méditer 15 minutes.", "rank": 6, "type": 0, "xp": 6000, "req_wis": 55 },
		{ "id": "s_focus", "title": "Focus", "desc": "3 sessions de cohérence cardiaque.", "rank": 6, "type": 0, "xp": 5000, "req_wis": 60 },
		# Hebdomadaire
		{ "id": "s_hebdo_eveil", "title": "Éveil Total", "desc": "Semaine parfaite sur tous les fronts.", "rank": 6, "type": 1, "xp": 25000, "stat": 0, "stat_amount": 5, "req_wil": 80 } # +5 Points libres
	]
	
	var count = 0
	
	for data in missions_data:
		var mission = MissionData.new()
		
		mission.id = data.get("id", "")
		mission.title = data.get("title", "")
		mission.description = data.get("desc", "")
		mission.rank = data.get("rank", 0)
		mission.type = data.get("type", 0)
		mission.base_xp = data.get("xp", 0)
		mission.reward_stat = data.get("stat", 0)
		mission.reward_stat_amount = data.get("stat_amount", 0)
		
		var req_stats = ["req_str", "req_dex", "req_end", "req_int", "req_wis", "req_cha", "req_per", "req_wil"]
		for req in req_stats:
			mission.set(req, data.get(req, 0))
		
		var rank_dir := RANK_DIRS[clampi(mission.rank, 0, RANK_DIRS.size() - 1)]
		var save_path := "res://Data/Missions/%s/" % rank_dir
		DirAccess.make_dir_recursive_absolute(save_path)

		var file_name = save_path + mission.id + ".tres"
		if ResourceSaver.save(mission, file_name) == OK:
			count += 1
			
	print("--- SUCCÈS : ", count, " NOUVELLES missions générées ! ---")
