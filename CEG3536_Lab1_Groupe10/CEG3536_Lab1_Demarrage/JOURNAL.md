# JOURNAL.md — Journal d'équipe, CEG 3536, laboratoire 1 (automne 2026)

Équipe : Groupe 10 — Idriss Toure, Mouhammad Habiballah Diagne, Mamadou Racine — Section : `A01 / A02 (à préciser)` — Dépôt Git : https://github.com/mhdiagne7/Voiture_autonome_sur_banc

## Jalon J1 (au plus tard le vendredi 25 septembre 2026, validé dans Git)

> Note : J1 validé dans Git le 26 septembre 2026, soit un jour après l'échéance du 25 septembre.

### Exigences de l'équipe
| Id | Exigence (reformulée par l'équipe) | Critère d'acceptation | Hypothèses |
|---|---|---|---|
| E1 | Au démarrage (mise sous tension ou NRST), le véhicule est en ARRÊT : DEL rouge seule. | Rouge seule allumée en moins de 100 ms, sur 5 réinitialisations consécutives (T1). | `gpio_init` éteint les 3 DEL avant `fsm_init`; horloge MSI 4 MHz. |
| E2 | Chaque appui validé sur User fait défiler ARRÊT → AVANT → ARRÊT → ARRIÈRE → ARRÊT. | Séquence rouge → verte → rouge → bleue → rouge exacte; une seule DEL à la fois (T2). | Variable `prochain_sens` (.bss) pour alterner avant/arrière; tout changement de sens passe par ARRÊT. |
| E3 | Anti-rebond logiciel et détection de front : un appui = un événement. | Fenêtre de 30 ms (dans 20–50 ms); 20 appuis = 20 transitions (`compteur_transitions`); appui maintenu 2 s = 1 transition (T3). | `fsm_step` appelée environ toutes les 1 ms; 30 échantillons consécutifs identiques. |
| E4 | E-Stop (PB2) déclenche EXTI2 de priorité maximale; l'ISR met les sorties en état sûr et positionne `estop_flag`. | Verte/bleue éteinte moins de 10 ms après le front sur PB2, même pendant `delay_ms` (T5). | Priorité NVIC 0; front choisi selon le niveau actif mesuré en T4. |
| E5 | En ARRÊT_URGENCE, la rouge clignote à 2 Hz et User est ignoré. | Période 500 ms ± 10 % mesurée sur PA9 (T6); aucun changement d'état sur appui User (T8). | Clignotement compté en pas de `fsm_step` (250 pas par demi-période). |
| E6 | Seul Touch En, avec E-Stop relâché, acquitte l'urgence et ramène en ARRÊT. | Retour en ARRÊT si E-Stop relâché; refus si maintenu (T7). Aucune reprise automatique. | Lecture de E-Stop par `button_raw(BTN_ESTOP)`. |
| E7 | Hors urgence, Touch En bascule `touch_enabled` (0/1) avec une extinction brève de la DEL active. | `touch_enabled` 0 → 1 → 0 en deux appuis, extinction de 100 ms visible (T9). | Même anti-rebond que User. |
| E8 | Toutes les durées proviennent d'une routine `delay_ms` documentée. | `DELAY_BOUCLES_PAR_MS` calibrée à l'oscilloscope; période de clignotement mesurée et rapportée. | Boucle calibrée au lab 1; SysTick au lab 2. |
| E9 | Le système reste cohérent pour des appuis simultanés et un E-Stop pendant une transition ou un clignotement. | Jamais deux DEL allumées; jamais de sortie d'urgence sans acquittement (T10). | `led_set` est le seul point d'écriture des DEL, hors ISR E-Stop. |

### Rôles et rotation
Chaque séance a un membre qui **réalise**, un qui **valide** (essais, mesures, relecture) et un qui **documente** (journal, preuves, rapport). Les rôles tournent à chaque séance pour que chacun touche au code, aux essais et au rapport, et que chacun puisse expliquer tout le code à la démonstration.

| Séance | Réalise | Valide (essais, mesures, relecture) | Documente (journal, preuves) |
|---|---|---|---|
| Séance 0 (prise en main, dépôt Git) | Mouhammad Diagne | Idriss Toure | Mamadou Racine |
| Séance 1 (E1–E3 : GPIO, `button_pressed`, FSM) | Idriss Toure | Mamadou Racine | Mouhammad Diagne |
| Séance 2 (E4–E9 : `estop_init`, ISR, urgence, Touch En, mesures, démo) | Mamadou Racine | Mouhammad Diagne | Idriss Toure |
| Hors séance (rapport, fiche périphérique) | Tous : rédaction répartie par section, relecture croisée | | |

Responsabilités par module (lab 1) :
- `gpio.s`, `buttons.s` (anti-rebond E3), `fsm.s` (E1–E2) : Idriss Toure
- `estop.s` (`estop_init`, `EXTI2_IRQHandler`, E4) : Mouhammad Diagne
- `fsm.s` (E5–E7), essais T1–T10 et mesures à l'oscilloscope : Mamadou Racine
- Rapport, JOURNAL.md, fiche périphérique « DEL et boutons » : tous (coordination : rôle « Documente » de la séance)

### Échéancier des laboratoires 1 à 5
| Laboratoire | Séances | Démonstration | Remise | Responsable du suivi |
|---|---|---|---|---|
| 1 — Commandes et signalisation (assembleur) | 15/18 sept., 22/25 sept., 29 sept./2 oct. | Séance 2 : 29 sept. (A02) / 2 oct. (A01) | 9 octobre 2026, 23 h 59 | Idriss Toure |
| 2 — Propulsion et mesure de vitesse (assembleur) | Semaine 5 (5–9 oct.) et suivantes, selon l'énoncé | Selon l'énoncé du lab 2 | Selon l'énoncé du lab 2 | Mouhammad Diagne |
| 3 — Accélérateur, acquisition et télémétrie (C) | Semaine 8 (2–6 nov.) | Selon l'énoncé du lab 3 | Selon l'énoncé du lab 3 | Mamadou Racine |
| 4 — Tableau de bord et perception simulée (C) | Semaine 10 (16–20 nov.) | Selon l'énoncé du lab 4 | Selon l'énoncé du lab 4 | Idriss Toure |
| 5 — Voiture autonome sur banc (C, projet intégré) | Semaine 12 (30 nov.–4 déc.) | Semaine 13 (7–9 déc.) | Selon l'énoncé du lab 5 | Mouhammad Diagne |

Jalons internes du lab 1 :

| Jalon | Échéance prévue | État | Date réelle |
|---|---|---|---|
| J1 : exigences, rôles, échéancier dans Git | 25 sept. | ✅ fait (un jour de retard) | 26 sept. |
| E1–E3 fonctionnels (GPIO, anti-rebond, défilement User) | 25 sept. | ✅ fait | 26 sept. |
| E4 codé (`estop_init`, `EXTI2_IRQHandler`) | avant la séance 2 | ✅ fait | 26 sept. |
| E5–E9 codés, compilation sans avertissement | avant la séance 2 | ✅ fait | 2 oct. |
| Essais T1–T10 sur la carte | séance 2 | ✅ tous conformes (T6 : voir tableau des essais) | 2 oct. |
| Démonstration devant l'assistant | séance 2 | ⏳ | |
| Fiche périphérique « DEL et boutons » | 7 oct. | ⏳ | |
| Brouillon du rapport | 7 oct. | ⏳ | |
| Relecture croisée du rapport | 8 oct. | ⏳ | |
| Remise sur Brightspace | 9 oct., 23 h 59 | ⏳ | |

## Journal des séances

### Séance 0 — 15/18 septembre 2026 — réalise : Mouhammad Diagne / valide : Idriss Toure
- Objectifs : prise en main de Leafy et de la Nucleo, projet STM32CubeIDE, dépôt Git.
- Fait :
- Décisions :
- Difficultés et solutions :
- Essais et mesures :
- Validations Git (auteur, message) :

### Séance 1 — 22/25 septembre 2026 — réalise : Idriss Toure / valide : Mamadou Racine
- Objectifs : E1, E2, E3; mesure des niveaux logiques et du rebond; J1.
- Fait : `button_pressed` (anti-rebond 30 échantillons, détection de front); `fsm_step` avec défilement User (variable `prochain_sens`) et `compteur_transitions`; `estop_init` et `EXTI2_IRQHandler` codés (Mouhammad).
- Décisions : fenêtre d'anti-rebond de 30 ms (milieu de 20–50 ms); alternance avant/arrière par une variable en .bss plutôt que par des états ARRÊT distincts.
- Difficultés et solutions :
- Essais et mesures :
- Validations Git : `b0dad15` (Mouhammad Diagne, 26 sept., dépôt du projet avec `estop.s`); `9b25d34` (Idriss Toure, 26 sept., E1–E3 et jalon J1).

### Séance 2 — 29 sept. / 2 oct. 2026 — réalise : Mamadou Racine / valide : Mouhammad Diagne
- Objectifs : E4 à E9, mesures T4 à T6, essais T7 à T10, démonstration.
- Fait : `fsm_step` complète (consommation d'`estop_flag`, ARRÊT_URGENCE, User ignoré, acquittement Touch En si E-Stop relâché, bascule `touch_enabled`); `fsm_maj_del` (clignotement 2 Hz, extinction brève 100 ms); `delay_ms` par SysTick; section critique dans `led_set`; constantes nommées et `dsb` dans `estop.s`.
- Décisions :
  - `delay_ms` par SysTick en scrutation (1 ms = 4000 cycles à MSI 4 MHz) plutôt que par boucle calibrée : la période de la boucle principale reste exactement 1 ms, quelle que soit la durée de `fsm_step`.
  - `button_pressed` est appelée à chaque pas pour User et Touch En, même en urgence, afin que l'anti-rebond reste à jour (un appui maintenu pendant l'urgence ne produit pas d'événement à la sortie).
  - `led_set` masque les interruptions (PRIMASK) pendant quelques cycles : l'ISR E-Stop ne peut pas s'intercaler entre « tout éteindre » et « allumer » (E9).
  - Mesures à l'oscilloscope non réalisées : l'assistant a indiqué qu'elles n'étaient pas exigées.
- Difficultés et solutions :
  - Les variables (`etat`, `touch_enabled`, …) n'affichaient aucune valeur dans Live Expressions : le code étant en assembleur, le débogueur ne connaît pas leur type. Solution : écrire `*(unsigned int*)&etat`.
  - Lecture des boutons par adresse : erreur de port pour PC13 (adresse de GPIOB au lieu de GPIOC). Corrigé : IDR de GPIOC = `0x42020810`, IDR de GPIOB = `0x42020410`.
  - Une DEL clignotant rouge/vert « toute seule » était LD4 COM (activité du ST-LINK pendant le débogage), et non une DEL du programme (LD1, LD2, LD3).
- Essais et mesures : T1 à T10 réalisés sur la carte le 2 oct., tous conformes (voir le tableau des essais).
- Validations Git : `4025222` (Idriss Toure, 2 oct., E4 à E9).

## Tableau des essais (T1 à T10)
| Essai | Date | Résultat observé | Verdict | Preuve (fichier) |
|---|---|---|---|---|
| T1 Réinitialisation (E1) | 2 oct. | Après NRST et au lancement du débogueur : seule LD3 (rouge) allumée, `etat = 0`. | ✅ Conforme | Capture débogueur (ODR, `etat`) à ajouter |
| T2 Cycle User (E2) | 2 oct. | 4 appuis : rouge → verte → rouge → bleue → rouge, une seule DEL à la fois; `etat` 0 → 1 → 0 → 2 → 0. | ✅ Conforme | Vidéo à ajouter |
| T3 Anti-rebond (E3) | 2 oct. | 20 appuis : `compteur_transitions` + 20 exactement; appui maintenu 2 s : + 1. | ✅ Conforme | Capture Live Expressions à ajouter |
| T4 Niveaux logiques | 2 oct. | Lecture de IDR dans le débogueur : User (PC13), E-Stop (PB2), Touch En (PB5) = 0 relâché, 1 appuyé. Hypothèses de `registres.inc` confirmées (actifs hauts, `PUPDR` = 00, aucune entrée flottante observée). | ✅ Conforme | Tableau ci-dessous |
| T5 E-Stop (E4) | 2 oct. | Depuis la verte puis depuis la bleue : la DEL s'éteint immédiatement, la rouge clignote, `etat = 3`. Délai non mesuré (oscilloscope non exigé). | ✅ Conforme | Capture Live Expressions à ajouter |
| T6 Clignotement (E5, E8) | 2 oct. | Rouge clignotante environ 2 Hz en urgence, verte et bleue éteintes. Période théorique 500 ms (250 + 250 appels de `fsm_step` cadencés par SysTick à 1 ms). Oscilloscope non exigé. | ✅ Conforme (visuel) | Chronométrage de 20 périodes à faire (≈ 10 s attendues) |
| T7 Acquittement (E6) | 2 oct. | Touch En avec E-Stop maintenu : refus, `etat` reste à 3. E-Stop relâché sans action : pas de reprise. Touch En avec E-Stop relâché : rouge fixe, `etat = 0`. | ✅ Conforme | Capture Live Expressions à ajouter |
| T8 User ignoré en urgence (E5) | 2 oct. | 3 appuis User en urgence : aucun changement, `etat` reste à 3. User fonctionne de nouveau après l'acquittement. | ✅ Conforme | Relevé de `etat` |
| T9 Touch En hors urgence (E7) | 2 oct. | En ARRÊT puis en MARCHE_AVANT : `touch_enabled` 0 → 1 → 0, extinction brève visible de la DEL active, `etat` inchangé. | ✅ Conforme | Capture Live Expressions à ajouter |
| T10 Robustesse (E9) | 2 oct. | User + Touch En simultanés; E-Stop pendant un appui User; E-Stop pendant l'extinction brève; appuis User répétés en urgence : jamais deux DEL allumées, jamais de sortie d'urgence sans Touch En. | ✅ Conforme | Description |

Mesures de T4 (lecture de `GPIOx_IDR` dans le débogueur) :

| Bouton | Broche | Relâché | Appuyé | Niveau actif | PUPDR |
|---|---|---|---|---|---|
| User | PC13 | 0 | 1 | haut | 00 (tirage externe sur la Nucleo) |
| E-Stop | PB2 | 0 | 1 | haut | 00 |
| Touch En | PB5 | 0 | 1 | haut | 00 |

## Routine conservée pour L3-A
- Routine : `button_pressed` (anti-rebond et détection de front), dans `Core/Src/buttons.s`.
- Interface : `uint32_t button_pressed(uint32_t id);` — R0 = identifiant (0 User, 1 E-Stop, 2 Touch En) → R0 = 1 si un appui vient d'être validé, 0 sinon. Appelée toutes les 1 ms. Fenêtre de 30 échantillons consécutifs (`ANTIREBOND_MS`). État conservé en .bss : `btn_valide[3]`, `btn_compteur[3]`. AAPCS : `push {r4, r5, r6, lr}`, appelle `button_raw`.
- Cas d'essai (à rejouer à l'identique sur la version C du lab 3) :

| Cas | Entrée (niveau brut, 1 échantillon par ms) | Résultat attendu |
|---|---|---|
| 1 | Bouton relâché en permanence | 0 à chaque appel |
| 2 | Appui stable de 60 ms | un seul 1, au 30e échantillon à 1 |
| 3 | Appui maintenu 2 s | un seul 1 |
| 4 | Appui de 29 ms puis relâché | jamais 1 |
| 5 | Rebonds : 5 ms à 1, 5 ms à 0, répétés 10 fois | jamais 1 |
| 6 | 20 appuis de 60 ms séparés de 60 ms | exactement 20 fois 1 |
| 7 | Relâchement après un appui validé | jamais 1 (le relâchement est validé mais ne produit pas d'événement) |
| 8 | Identifiant invalide (3) | 0 |
- Résultats (lab 1) : cas 3 et 6 vérifiés sur la carte (T3); cas 2, 4 et 5 vérifiés en simulation du binaire (durées exactes impossibles à produire à la main); cas 1, 7 et 8 à consigner.

## Déclaration des sources et de l'usage d'outils d'IA générative
- Sources : code de départ CEG3536_Lab1_Demarrage (Brightspace); RM0438; manuel Zhu, 4e éd.
- Outils d'IA (outil, version, usage) ou « aucun usage » :
