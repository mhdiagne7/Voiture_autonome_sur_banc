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
- 25–26 sept. : E1–E3 fonctionnels, J1 dans Git.
- Avant la séance 2 : E4 à E7 codés, compilation sans avertissement, T1–T3 refaits sur la carte.
- Séance 2 : mesures T4–T6, essais T7–T10, démonstration.
- Au plus tard le 7 oct. : brouillon du rapport; relecture croisée le 8 oct.; remise le 9 oct.

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
- Validations Git :

### Séance 2 — 29 sept. / 2 oct. 2026 — réalise : Mamadou Racine / valide : Mouhammad Diagne
- Objectifs :
- Fait :
- Décisions :
- Difficultés et solutions :
- Essais et mesures :
- Validations Git :

## Tableau des essais (T1 à T10)
| Essai | Date | Résultat observé | Verdict | Preuve (fichier) |
|---|---|---|---|---|
| T1 Réinitialisation | | | | |
| T2 Cycle User | | | | |
| T3 Anti-rebond | | | | |
| T4 Niveaux logiques | | | | |
| T5 E-Stop | | | | |
| T6 Clignotement | | | | |
| T7 Acquittement | | | | |
| T8 User ignoré en urgence | | | | |
| T9 Touch En hors urgence | | | | |
| T10 Robustesse | | | | |

## Routine conservée pour L3-A
- Routine : `button_pressed` ou `led_set`
- Interface :
- Cas d'essai :

## Déclaration des sources et de l'usage d'outils d'IA générative
- Sources : code de départ CEG3536_Lab1_Demarrage (Brightspace); RM0438; manuel Zhu, 4e éd.
- Outils d'IA (outil, version, usage) ou « aucun usage » :
