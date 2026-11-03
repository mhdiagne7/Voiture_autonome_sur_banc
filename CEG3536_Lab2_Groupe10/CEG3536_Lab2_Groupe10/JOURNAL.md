# JOURNAL.md — Journal d'équipe, CEG 3536, laboratoire 2 (automne 2026)

Équipe : Groupe 10 — Idriss Toure, Mouhammad Habiballah Diagne, Mamadou Racine — Section : A01 — Dépôt Git : https://github.com/mhdiagne7/Voiture_autonome_sur_banc (projet `CEG3536_Lab2_Groupe10/CEG3536_Lab2_Groupe10`)

## Suivi du jalon J1

| Laboratoire | Échéancier prévu (J1) | Déroulement réel | Écart et cause | Ajustement pour les laboratoires 3 à 5 |
|---|---|---|---|---|
| 1 | Séances 15/18 sept., 22/25 sept., 2 oct. ; remise 9 oct. | J1 validé le 26 sept. ; démonstration le 2 oct. ; remise le 9 oct. | J1 un jour en retard ; énoncé v1.2 découvert le jour de la remise (T6 par DWT_CYCCNT ajouté le 9 oct.) | Vérifier la dernière version de l'énoncé sur Brightspace avant chaque séance |
| 2 | Semaine 5 (5–9 oct.) et suivantes | Séance 1 le 16 oct. ; séance 2 et démonstration le 23 oct. ; remise le 2 nov. | Calendrier décalé d'une semaine par l'énoncé v1.2 du lab 2 ; démonstration le jour de la mi-session | Préparer le code avant la séance 1 ; enregistrer les captures immédiatement dans un dossier sauvegardé (captures de la séance 1 perdues puis refaites) |

## Rôles et rotation

| Séance | Réalise | Valide (essais, mesures, relecture) | Périphérique configuré ou mesuré par chacun |
|---|---|---|---|
| Séance 1 (16 oct.) | Les trois membres, en alternance au poste (un membre à la carte et au débogueur) | Les deux autres membres (vérification des valeurs, relecture, relevés) | Idriss : SysTick, buzzer ; Mouhammad : moteur (PWM TIM1) ; Mamadou : encodeur (EXTI0) |
| Séance 2 (23 oct.) | Les trois membres, en alternance au poste | Les deux autres membres | Mêmes répartitions ; essais T5 à T10 menés à trois |

Les séances ont été réalisées à trois au même poste ; chacun a lu au débogueur des registres de TIM1, des compteurs de l'encodeur et `ticks_ms`.

## Calculs préalables (avant la séance 1)

| Grandeur | Formule | Valeur | Vérifiée par (essai) |
|---|---|---|---|
| `PWM_PSC`, `PWM_ARR` | f = 4 MHz / ((PSC + 1)(ARR + 1)) = 20 kHz | PSC = 0, ARR = 199 (0xC7) | T3 |
| `CCR1` pour 25 / 50 / 75 / 100 % | pct × (ARR + 1) / 100 | 50 / 100 / 150 / 200 | T3 |
| `SYSTICK_LOAD_1MS` | 4 MHz × 1 ms − 1 | 3999 (0xF9F) | T10 |
| Fronts par tour (arbre de sortie) | 2 × 11 × 34 | 748 | T5 |
| tr/min à partir de `vitesse_fronts` | fronts × 120 / 748 (fenêtre 500 ms) | × 0,1604 | T6 |
| Fronts attendus par fenêtre de 500 ms à 100 % | 350 tr/min (arbre de sortie) × 748 / 120 | ≈ 2 182 | T6 |

## Journal des séances

### Séance 1 — 16 octobre 2026 — réalise / valide : les trois membres, en alternance
- Objectifs : projet lab 2 (copie du lab 1 + complément), SysTick, buzzer, moteur (PWM, sens), raccordement à la machine à états (E1 à E4, E9, E10).
- Fait : projet `CEG3536_Lab2_Groupe10` ; `systick_init`, `delay_ms` sur `ticks_ms` ; `motor_init` (TIM1), `motor_set_dir` ; `buzzer_bip`, `buzzer_step` ; `encoder.s` ; ISR E-Stop étendue ; `fsm.s` (consigne, rampe, fenêtre de vitesse, sorties). Essais T1, T2, T3, T4, T10 (SysTick) sur la carte.
- Décisions (sens réel de rotation pour AI1 = 1, AI2 = 0 ; `ENC_SENS_INVERSE` ; variante buzzer) :
  - Marche avant (AI1 = 1, AI2 = 0) : rotation **antihoraire** de l'arbre de sortie.
  - Buzzer en commande GPIO sur PA0 (pas de variante PWM TIM2).
  - `led_set` : section critique PRIMASK du lab 1 retirée (CPSID/CPSIE réservés au lab 5), remplacée par une relecture de `estop_flag`.
  - Touch En sert désormais à la consigne ; la bascule `touch_enabled` du lab 1 est retirée (variable conservée à 0).
- Difficultés et solutions : variables invisibles dans Live Expressions sans le type → `*(unsigned int*)&variable` ; mesure de la rampe trop imprécise avec une pause manuelle à la fin → mesure de la pente (pause pendant la rampe, départ fixé par un point d'arrêt).
- Mesures (PWM, SysTick, bips) : voir les tableaux ci-dessous.
- Validations Git (auteur, message) : `8d930cb`, `86294e3`, `9ece044` (Idriss Toure, 16 oct.).

### Séance 2 — 23 octobre 2026 — réalise / valide : les trois membres, en alternance
- Objectifs : encodeur (T5, T6), E-Stop (T7), urgence (T8), bips (T9), robustesse (T10), démonstration.
- Fait : tous les essais T5 à T10 sur la carte, puis démonstration.
- Décisions : `ENC_SENS_INVERSE` = 0 (`enc_count` croît en marche avant).
- Difficultés et solutions : « No ST-LINK detected » après réimportation du projet → nouvelle configuration de débogage et reconnexion USB ; captures de la séance 1 perdues, refaites le 23 oct.
- Mesures (encodeurs, vitesse, délai E-Stop) : voir les tableaux ci-dessous.
- Validations Git : journal du laboratoire 2 (Mouhammad Habiballah Diagne).

## Tableau des mesures (composante L2-A)

| Mesure | Exigence | Valeur mesurée | Incertitude / méthode | Écart | Cause | Preuve (fichier) |
|---|---|---|---|---|---|---|
| Fréquence PWM | 20 kHz ± 5 % | 20,0 kHz (PSC = 0, ARR = 199) | Calcul d'après les registres (vue SFR), horloge MSI 4 MHz | 0 % (à la précision du MSI) | — | T1_tim1.png, T3_*.png |
| Rapport cyclique à 25 / 50 / 75 / 100 % | ± 2 points | CCR1 = 50 / 100 / 150 / 200 → 25 / 50 / 75 / 100 % | CCR1 / (ARR + 1), vue SFR | 0 point | — | T3_25/50/75/100.png |
| Rampe 0 → 100 % | 1 s ± 10 % | Montée : 0 → 73 en 737 ms (10,1 ms/point → 1,01 s). Descente : 100 → 56 en 439 ms (9,98 ms/point → 0,75 s pour 100 → 25) | `ticks_ms` et `pwm_pct`, départ par point d'arrêt, arrivée par pause pendant la rampe | + 1 % / − 0,2 % | Pause tombant au milieu d'un pas de 10 ms | relevé |
| Période SysTick | 1 ms ± 1 % | 31 165 → 41 550 en 10,33 s chronométrées : 1 005 ticks/s → 0,995 ms | Chronomètre, réaction ≈ ± 0,2 s (≈ ± 2 %) | − 0,5 % | Dans l'incertitude de réaction | relevé |
| Vitesse à 25 / 50 / 75 / 100 % (avant) | croissante, stable ± 10 % | 544 / 1 108 / 1 670 / 2 223 fronts par 500 ms → 87,3 / 177,7 / 267,9 / 356,6 tr/min | 3 fenêtres par palier (Live Expressions) | Dispersion < 0,3 % ; 100 % : + 2 % / 350 tr/min | Moteur à vide | relevé |
| Vitesse à 25 / 50 / 75 / 100 % (arrière) | idem | 547 / 1 120 / 1 694 / 2 295 fronts par 500 ms → 87,7 / 179,7 / 271,8 / 368,2 tr/min | idem | Dispersion < 0,3 % ; 100 % : + 5 % / 350 tr/min | Asymétrie du moteur (≈ 3 %) | relevé |
| Déphasage E_A / E_B (avant, arrière) | quadrature, inversé selon le sens | Avant : `enc_count` +4 978 en 1 108 ms (4 493 fronts/s) ; arrière : −4 354 en 960 ms (4 535 fronts/s) ; `sens_mesure` = 1 / 2 | `enc_count` et `ticks_ms` à deux pauses | Sens correct ; ≈ +3 % / 4 400 fronts/s attendus | Vitesse à vide un peu supérieure au nominal | T5_arriere.png (avant : relevé) |
| Délai E-Stop → PWM nulle | < 1 ms | CCR1 = 0 écrit ≈ 21 cycles après l'entrée (≈ 5 µs) ; STB = 0 ≈ 25 cycles (≈ 6 µs) ; sortie PWM nulle au plus tard au débordement suivant (≤ 50 µs) | Estimation : latence d'entrée 12 cycles + push, bl, ldr, movs, str ; vérifié par point d'arrêt après `bl motor_stop_now` (CCR1 = 0, STB = 0) | ≈ 20 fois sous la limite | — | T7_isr_tim1.png, T7_isr_gpioe.png |
| Durée d'un bip | 100 ms ± 10 % | 1 443 293 → 1 443 392 : 99 ms | `ticks_ms` aux points d'arrêt `buzzer_bip` et `buzzer_step_repos` | − 1 % | Dernier pas sonore et passage au repos dans le même appel | T9_debut.png, T9_fin.png |

## Tableau des essais (T1 à T10)

| Essai | Date | Résultat observé | Verdict | Preuve (fichier) |
|---|---|---|---|---|
| T1 Réinitialisation | 16 oct. | Rouge seule, moteur immobile, buzzer silencieux ; TIM1 : PSC = 0, ARR = 0xC7, CCR1 = 0, CR1 = 0x81, CCMR1 = 0x68, CCER = 0x1, BDTR = 0x8000 ; STB = 0 | ✅ Conforme | T1_tim1.png, T1_gpioe.png, T1_variables.png |
| T2 Cycle User et sens | 16 oct. | Rouge → verte → rouge → bleue → rouge ; GPIOB ODR = 0x400 (avant), 0x0 (arrêt), 0x880 (arrière) ; GPIOE ODR = 0x8000 en marche, 0x0 à l'arrêt ; avant = antihoraire ; `sens_mesure` cohérent | ✅ Conforme | T2_arriere_gpiob.png, T2_arriere_gpioe.png |
| T3 PWM | 16 oct. | 20 kHz ; CCR1 = 50 / 100 / 150 / 200 aux 4 paliers | ✅ Conforme | T3_25/50/75/100.png |
| T4 Rampe | 16 oct. | 10,1 ms/point à la montée, 9,98 ms/point à la descente | ✅ Conforme | relevé |
| T5 Encodeur | 23 oct. | `enc_count` croît en avant (4 493 fronts/s), décroît en arrière (4 535 fronts/s) ; aucun front perdu | ✅ Conforme | T5_arriere.png (avant : relevé) |
| T6 Vitesse | 23 oct. | Valeurs stables (< 0,3 %) et croissantes ; 357 / 368 tr/min à 100 % ; `sens_mesure` 1 / 2 | ✅ Conforme | relevé (tableau des mesures) |
| T7 E-Stop | 23 oct. | Au point d'arrêt après `bl motor_stop_now` : CCR1 = 0, STB = 0, AI1 = AI2 = 0 ; son continu ; aussi pendant une rampe en arrière | ✅ Conforme | T7_isr_tim1.png, T7_isr_gpioe.png |
| T8 Urgence et acquittement | 23 oct. | User ignoré ; Touch En refusé avec E-Stop maintenu (consigne inchangée) ; pas de reprise automatique ; acquittement → ARRÊT, son coupé, STB = 0 ; moteur seulement au User suivant | ✅ Conforme | relevé |
| T9 Buzzer | 23 oct. | Bip court 99 ms ; double bip en arrière | ✅ Conforme | T9_debut.png, T9_fin.png |
| T10 SysTick et robustesse | 16 et 23 oct. | SysTick 0,995 ms ; E-Stop, Touch En et User pendant une rampe, appuis simultanés, E-Stop à 100 % : jamais deux DEL, jamais de changement de sens sous PWM, jamais de sortie d'urgence sans acquittement, `enc_count` intact | ✅ Conforme | relevé |

## Routine conservée pour L3-A
- Routine (`button_pressed`, `led_set`, `motor_set_pwm` ou `encoder_read`) : `button_pressed` (inchangée depuis le laboratoire 1).
- Interface : `uint32_t button_pressed(uint32_t id);` — r0 = identifiant (0 User, 1 E-Stop, 2 Touch En) → r0 = 1 si un appui vient d'être validé ; appelée toutes les 1 ms (désormais cadencée par SysTick) ; fenêtre de 30 échantillons.
- Cas d'essai et résultats : les 8 cas du laboratoire 1 (journal du lab 1) restent valables ; T2, T3 et T8 du lab 2 confirment le fonctionnement avec la nouvelle base de temps.

## Déclaration des sources et de l'usage d'outils d'IA générative
- Sources (dont le complément de démarrage et, le cas échéant, le corrigé du laboratoire 1) : projet du laboratoire 1 de l'équipe ; complément de démarrage CEG3536_Lab2_Complement (Brightspace) ; énoncé v1.3 ; RM0438, PM0264 ; guide de la plateforme Leafy.
- Outils d'IA (outil, version, usage) ou « aucun usage » : Claude (Anthropic), via Claude Code — aide à la comprehension des concepts.
