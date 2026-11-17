# JOURNAL.md — Journal d'équipe, CEG 3536, laboratoire 3 (automne 2026)

Équipe (groupe 10) : Idriss Toure, Mouhammad Habiballah Diagne, Mamadou Racine — Section : A01 — Dépôt Git : https://github.com/mhdiagne7/Voiture_autonome_sur_banc

## Jalon J2 — module d'événements testé sur hôte

| Plateforme | Compilateur et version | Commande | Résultat (cas réussis / échecs) | Date et validation Git |
|---|---|---|---|---|
| Windows 11 | gcc (MinGW) 4.8.1 | `gcc -std=gnu11 -Wall -Wextra -O0 -g -I../Core/Inc -o test_evq.exe test_evq.c ../Core/Src/evq.c ../Core/Src/evq_test.c` (mêmes options que `make` dans `hote/`) | 9 / 0 — « 9 cas, 0 echec(s) : OK », aucun avertissement | 2026-11-13 ; code dans le commit 58ce500 |
| Linux (Ubuntu, WSL2, noyau 6.6.87) | gcc 15.2.0 | `make` dans `hote/` (mêmes options) | 9 / 0 — « 9 cas, 0 echec(s) : OK », aucun avertissement | 2026-11-13 ; code dans le commit 58ce500 |
| STM32 (cible) | arm-none-eabi-gcc (STM32CubeIDE 2.2.0), -O0 | commande série `q` | 9 / 0 — trame `Q,echecs=0` | 2026-11-13 (séance 2) |

Trace (identique sur les deux hôtes, sauf la première ligne) :

```
evq : capacite 32, sizeof(evq_event_t) = 12, int = 32 bits, long = 32 bits   (Windows)
evq : capacite 32, sizeof(evq_event_t) = 12, int = 32 bits, long = 64 bits   (Linux)
  cas 1 : reussi
  ...
  cas 9 : reussi
9 cas, 0 echec(s) : OK
```

Saturation volontaire sur cible (commande `t`, 40 événements dans une file de 32) : débordements = 8 dans la télémétrie, trames continues, aucun blocage ; `z` remet le compteur à 0 (`Z,ok`).

Cas ajoutés par l'équipe (au-delà des 9 fournis) :

| Cas | Description | Résultat |
|---|---|---|
| — | Aucun cas ajouté à ce jour : les 9 cas fournis couvrent les huit catégories exigées (vide, un élément, FIFO, plein, débordement, enroulement, vidage, compteur) | — |

Différences observées entre hôtes (tailles des types, options, avertissements) : `long` vaut 32 bits sous Windows (modèle LLP64) et 64 bits sous Linux (LP64) ; `int` et `sizeof(evq_event_t)` = 12 octets sont identiques, car le module n'utilise que des types à taille fixe (`uint32_t`). Mêmes options, aucun avertissement avec gcc 4.8.1 ni gcc 15.2.0 ; même résultat que sur la cible.

## Rôles et rotation

| Séance | Réalise | Valide | Module C dont chacun est responsable | Routine assembleur écrite ou modifiée par chacun |
|---|---|---|---|---|
| Séance 1 (6 nov.) | Les trois membres, en alternance au poste (un membre à la carte et au débogueur) | Les deux autres membres (vérification des valeurs, relecture, relevés) | Idriss : `main.c`, `telem.c` (LPUART1) ; Mouhammad : `fsm.c`, `l3a_c.c` + banc L3-A ; Mamadou : `adc_dma.c`, `acq.c` | Mamadou : `vitesse.s` (nouvelle routine Q16.16) ; routines des labs 1 et 2 inchangées, appelées depuis le C |
| Période d'étude (25–31 oct.) | Les trois membres | Les trois membres | Idriss : `evq.c`, `evq_test.c`, `hote/test_evq.c` (jalon J2) | — |
| Séance 2 (13 nov.) | Les trois membres, en alternance au poste | Les deux autres membres | Mêmes répartitions ; essais T4 à T10 menés à trois | — |

Les séances ont été réalisées à trois au même poste ; chacun a lu au débogueur les registres ADC1/DMA1/LPUART1, les registres R0–R3/SP et les trames de télémétrie.

## Calculs préalables

| Grandeur | Formule | Valeur | Vérifiée par |
|---|---|---|---|
| `RPM_Q16_K` | round(240 × 65 536 / 748) | 240 × 65 536 / 748 = 21 027,59 → **21 028** | T3 (5 cas exacts) |
| Erreur relative de la constante | (k − 240 × 65 536 / 748) / (240 × 65 536 / 748) | **+0,0019 %** | T3 |
| fronts maximal sans débordement | 2³² / k | **204 249 fronts** par fenêtre (≈ 65 500 tr/min, très au-delà du moteur : ~2 300 fronts / 500 ms à 100 % au lab 2) | T3 (65 535 → 1 378 069 980, sans débordement) |
| `LPUART1_BRR` | 256 × 4 000 000 / 115 200 | 8 888,9 → **8 889 = 0x22B9** (erreur de débit 0,001 %) | T1 (BRR lu 0x22B9), T9 |
| Débit ADC par voie | 4 MHz / (2 × (640,5 + 12,5)) | **3 062,8 conversions/s** par voie | T4 : 3 076 mesurées (+0,4 %) |
| Durée d'un tour du tampon DMA | 16 / débit par voie (64 avec la version 2) | 5,22 ms avec 16 échantillons ; **20,9 ms** avec `ADC_N_TAMPON` = 64 (≈ 48 tours/s) | T4 : 48,1 tours/s |
| Résolution de la température | 3 300 mV / 4 095 / 10,9 mV/°C | **0,074 °C** par pas | T6 (bruit ±0,15 °C ≈ ±2 pas) |

## Étalonnage de la température (E6)

| Mesure | Température de référence (°C) | `temp_mv` lu | `TEMP_MV_REF` / `TEMP_C10_REF` retenus | Position de S2 |
|---|---|---|---|---|
| Ambiante | Thermomètre du labo lu approximativement : environ 24,7 °C ; écart avec la carte ≤ 0,8 °C (critère ≤ 2 °C respecté sous cette réserve). Étalonnage d'après le point de la fiche technique (1 831 mV à 25,0 °C). | **1 826 mV** (`temp_brut` 2 266) → 25,2 à 25,5 °C dans les trames | 1 831 / 250 (fiche technique, non modifiés) | Gauche (interne) |
| Capteur tenu entre deux doigts (30 s) | — | Hausse de la température observée dans la télémétrie pendant le pincement ; valeur maximale non relevée | — | Gauche (interne) |
| Conditionnement externe (pont OUT–IN ou circuit) | — | Non réalisé (même raison ; demande de couper la plateforme pour poser le pont) | — | — |

Étalonnage sur une mesure réelle (calcul, non appliqué) : avec une référence T_ref fiable, on poserait `TEMP_MV_REF` = 1 826 et `TEMP_C10_REF` = 10 × T_ref ; avec 24,7 °C, l'écart passerait de 0,5–0,8 °C à 0.

Analyse interne / externe (plage, résolution, bruit) : en interne (suiveur, gain 1), 15 à 40 °C ne couvrent qu'environ 270 mV, soit environ 340 pas sur 4 096 (8 % de la pleine échelle) : résolution 0,074 °C par pas. Un conditionnement externe à gain G (avec décalage) étalerait ces 270 mV sur la plage de l'ADC : avec G ≈ 10, la résolution passerait à environ 0,007 °C par pas, mais la plage mesurable se réduirait à environ 25 °C, et le bruit et la dérive analogiques en amont seraient multipliés par G. Le gain n'améliore donc la mesure que si le bruit dominant est celui de la quantification. Ici, le bruit observé (±2 pas) est déjà atténué par la moyenne sur 64 échantillons, et la limite réelle est l'exactitude de l'étalonnage (décalage), que le gain n'améliore pas.

## Journal des séances

### Séance 1 — 6 novembre 2026 — réalise / valide : les trois membres, en alternance
- Objectifs : ouvrir le projet du lab 3 (main et fsm en C appelant l'assembleur), valider l'initialisation (T1), l'appel C → assembleur (T2) et la virgule fixe (T3).
- Fait : projet construit à partir du lab 2 et du complément (`main.s` et `fsm.s` remplacés par `main.c` et `fsm.c`) ; T1, T2 et T3 conformes sur la carte.
- Décisions (découpage des modules, format des trames, routine L3-A choisie) : un module par périphérique (`adc_dma`, `telem`), un objet `acq` à deux instances, une file `evq` sans matériel ; trame `T,ticks,etat,sens,consigne,pwm,temp_x10,rpm_x100,nb_evenements,debordements` ; envoi non bloquant (file logicielle vidée tant que la FIFO TX a de la place, et trame refusée entière si la file est pleine, donc jamais tronquée) ; routine L3-A : `motor_set_pwm`.
- Difficultés et solutions :
  - PuTTY ne s'ouvrait pas : remplacé par la console série de STM32CubeIDE (Command Shell Console, COM5, 115 200 8N1).
  - DEL pas rouge au départ : le débogueur s'arrête sur `main`, il faut Resume (F8).
  - Valeur attendue de ADC1->CR : 0x10000005 et non 0x1000000D (le bit 3 est JADSTART) ; commentaire corrigé dans `adc_dma.c`.
  - Commandes série sans réponse : le clavier n'était pas dans la console série (résolu à la séance 2).
- Mesures : voir T1, T2 et T3 dans le tableau des essais.
- Validations Git : commit 58ce500 (code complet du lab 3).

### Période d'étude — travail sur hôte
- Fait (evq, test_evq, cas ajoutés, L3-B / L3-C rédigés) : module `evq` (file circulaire de 32 événements, débordements comptés) et son programme d'essai (9 cas) compilés et exécutés sur Windows et Linux ; objet `acq` (version 1 puis version 2).
- Validations Git : commit 58ce500 (code) ; commit 2895e0c (traces J2 dans ce journal, 13 nov.).

### Séance 2 — 13 novembre 2026 — réalise / valide : les trois membres, en alternance
- Objectifs : terminer T4 à T10 et faire la démonstration.
- Fait : T4, T5, T7, T8 (point d'arrêt), T9 et T10 conformes ; T6 partiel (pincement fait, hausse observée mais maximum non relevé ; pont J5 non fait) ; démonstration faite devant l'assistant (partielle faute de temps, le reste est à vérifier dans le rapport selon l'assistant).
- Décisions : pas de nouvel étalonnage de la température (lecture déjà plausible, référence non fiable) ; le banc L3-A est fait à -O0 puis à -O2, puis retour à -O0.
- Difficultés et solutions :
  - « Debug As : none applicable » : projet resélectionné et configuration de débogage relancée.
  - T4 bas lu 479 au premier essai : curseur pas tout à fait en butée ; 0 au second.
  - Commandes série : il fallait cliquer dans la console série avant de taper `a`, `q`, `t`, `z`, `b`.
  - La copie de la console série ne marchait pas au clavier : remplacée par une capture d'écran.
  - T6 : la hausse au pincement a été observée sans noter la valeur maximale ; le pont J5 n'a pas été fait (le connecteur avait été cherché au mauvais endroit, sous la vitre).
- Mesures (température, cycles DWT, désassemblage) : `temp_mv` 1 826 mV, 25,2–25,5 °C ; cycles 32/50 à -O0 et 21/14 à -O2 (assembleur / C) ; désassemblage dans `T10_desassemblage_O0_O2.txt`.
- Validations Git : commit 2895e0c (journal J2, commentaire ADC).

## Composante L3-A : comparaison assembleur / C

Routine comparée : `motor_set_pwm` (assembleur, `motor.s`) et `motor_set_pwm_c` (C, `l3a_c.c`), comparées par `bench_l3a` (commande `b`, en ARRÊT).

| Cas | Entrée | Résultat assembleur | Résultat C | Effet de bord (registre / variable) | Écart |
|---|---|---|---|---|---|
| 1 | 0 | 0 | 0 | TIM1_CCR1 = 0 | 0 |
| 2 | 1 | 2 | 2 | TIM1_CCR1 = 2 | 0 |
| 3 | 25 | 50 | 50 | TIM1_CCR1 = 50 | 0 |
| 4 | 50 | 100 | 100 | TIM1_CCR1 = 100 | 0 |
| 5 | 75 | 150 | 150 | TIM1_CCR1 = 150 | 0 |
| 6 | 99 | 198 | 198 | TIM1_CCR1 = 198 | 0 |
| 7 | 100 | 200 | 200 | TIM1_CCR1 = 200 | 0 |
| 8 | 0xFFFFFFFF (saturation) | 200 | 200 | TIM1_CCR1 = 200 | 0 |

Résultat de la carte : `B,ecarts=0` à -O0 et à -O2. Le banc écrit une valeur sentinelle (0xFFFF) dans CCR1 avant l'appel C, ce qui prouve que l'écriture a bien lieu.

| Version | Cycles DWT (moyenne) | Taille (octets) | Registres utilisés | Observations (prologue, volatile) |
|---|---|---|---|---|
| Assembleur | 32 (banc compilé à -O0) ; 21 (banc compilé à -O2) | 24 + 4 (littéral TIM1_BASE) = 28 | r0, r1, r2 | pas de prologue (routine feuille) ; `mul` puis `udiv` (division matérielle, 2 à 12 cycles) |
| C, -O0 | 50 | 56 + 8 (littéraux) = 64 | r0, r2, r3, r7 | prologue `push {r7}`, `sub sp, #20` : `pct` et `ccr` sont rangés sur la pile puis relus ; la division par 100 est remplacée par une multiplication par l'inverse (`umull` avec 0x51EB851F, puis `lsrs #5`) |
| C, -O2 | 14 | 14 + 2 (`nop` d'alignement) + 4 (littéral) = 20 | r0, r3 | aucun accès à la pile ; saturation `cmp`/`it cs`/`movcs` ; `pct × 200 / 100` devient `lsls r0, r0, #1` (× 2) ; écriture `str` dans CCR1 conservée (volatile) |

## Composante L3-C : objet d'acquisition

- Version 1 (validation Git) : `acq_init`, `acq_brut` (moyenne arrondie de `n_moy` échantillons pris avec un pas dans le tampon DMA entrelacé), `acq_mv`, `acq_valeur` (relation linéaire `mv × gain_num / gain_den + décalage`). Deux instances : `acq_pot` (pas 2, 16 échantillons) et `acq_temp` (pas 2, décalage d'une case).
- Version 2 (validation Git) et ce qui a changé : `acq_config_filtre` (zone morte de 3 % aux extrémités, hystérésis de 2 points, bornes 0–100) appliqué dans `acq_valeur`. La température passe à 64 échantillons (`TEMP_N_MOY`, tampon `ADC_N_TAMPON` = 64). `main.c` ne change qu'à l'initialisation ; `fsm.c` ne change pas. Correction trouvée à l'essai : test `>=` à la borne haute (sinon la consigne plafonnait à 97). Pas d'hystérésis après un collage à une extrémité, pour que la consigne ne reste pas bloquée à 1–2 %.
- Limite de traçabilité Git : les versions 1 et 2 sont dans le même commit (58ce500). La version 2 est repérée dans le code (commentaires « version 2 » dans `acq.h` et `acq.c`), mais pas par deux commits séparés comme le demande l'énoncé.
- Essai d'indépendance des deux instances : en marche, le potentiomètre à 2 699 (consigne 66) ne change pas la température brute (2 262, comme au repos à 2 263–2 266) ; potentiomètre en bas (0), la température reste à 25,2–25,5 °C. Le filtre de la version 2 n'est configuré que sur `acq_pot`, et la température n'en a pas.
- Comparaison avec la version impérative (annexe) : avec des variables globales, la zone morte et l'hystérésis exigeraient de nouvelles globales (dernière valeur, seuils) partagées entre le potentiomètre et la température, ou dupliquées à la main, et chaque appelant devrait appliquer le filtre lui-même. Avec l'objet, l'état est dans l'instance, et le changement se limite à `acq.c` et à une ligne d'initialisation.
- Limites :
  - 52 octets par instance (13 champs de 32 bits) ;
  - pas de polymorphisme (un seul type de relation, linéaire) ;
  - le tampon DMA est lu pendant que le DMA écrit, donc une moyenne peut mélanger deux tours (sans conséquence ici, la grandeur varie lentement) ;
  - divisions entières à chaque lecture.

## Composante L3-D : traces

| Élément | Preuve (fichier) |
|---|---|
| Désassemblage -O0 annoté | `preuves_lab3/T10_desassemblage_O0_O2.txt` (`motor_set_pwm_c` et `rampe`/`fsm_sorties` à -O0) |
| Désassemblage -O2 annoté | même fichier (à -O2, `rampe` est intégrée dans `fsm_sorties` : 132 + 120 octets à -O0 → 164 octets à -O2 ; l'appel final à `buzzer_step` devient un saut `b.w`, ou appel terminal) |
| Trois instructions et leur encodage Thumb | `cmp r0, #100` = 0x2864 (16 bits, format T1 : 00101, Rn = 000, imm8 = 0x64) ; `movs r1, #200` = 0x21C8 (00100, Rd = 001, imm8 = 0xC8) ; `udiv r0, r0, r1` = 0xFBB0 F0F1 (32 bits : Rn = 0, Rd = 0, Rm = 1) |
| Captures du débogueur (R0–R3, SP, variable volatile) | `T2_motor_set_pwm_sortie.png` (R0 = 2, R2 = 0x40012C00, SP = 0x2002FFA0 aligné sur 8, LR dans `rampe`) ; `T2_variables_volatile.png` (ticks_ms 290 704, etat 2) ; `T2_vitesse_entree.png` / `T2_vitesse_sortie.png` |
| Cycles DWT -O0 / -O2 et transformation analysée | `T10_bench_O2.png` (21 / 14) ; -O0 : 32 / 50 (relevé noté). À -O2, la réduction de force s'appuie sur l'intervalle de `pct` après saturation (au plus 100), ce qui rend `pct × 200 / 100 = pct × 2` exact. Limites : l'accès volatile à CCR1 est conservé ; à -O2, le débogueur affiche des variables `<optimized out>` et ne s'arrête pas sur chaque ligne. |

Le désassemblage a été obtenu avec `arm-none-eabi-objdump` à partir du même compilateur que STM32CubeIDE 2.2.0 (GNU Tools for STM32 14.3.1), avec les mêmes options de processeur.

## Tableau des essais (T1 à T10)

Preuves dans `Documents/CEG3536/preuves_lab3/` (hors dépôt).

| Essai | Date | Résultat observé | Verdict | Preuve (fichier) |
|---|---|---|---|---|
| T1 Initialisation en C | 6 nov. | Ligne `H` puis trames `T` à 5 Hz ; ADC1 CR 0x10000005, CFGR 0x80003003, SMPR1 0x1F8, SQR1 0x2041 ; DMA1 CCR1 0x5A1, CPAR 0x42028040 (`&ADC1->DR`) ; LPUART1 CR1 0x2000000D, BRR 0x22B9 ; température ≈ 24,8 °C | Conforme | `T1_terminal.png`, `T1_adc1_sfr.png`, `T1_dma1_sfr.png`, `T1_lpuart1_sfr.png` |
| T2 Appel C → assembleur | 6 nov. | Sortie de `motor_set_pwm` : R0 = 2, R2 = 0x40012C00, SP 0x2002FFA0 (multiple de 8), LR 0x0800152D dans `rampe` ; pile d'appels main → fsm_sorties → rampe → motor_set_pwm ; volatile : ticks_ms 290 704, etat 2 ; `enc_fronts_vers_rpm_q16` : 545 → 11 460 260 (174,87 tr/min) | Conforme | `T2_motor_set_pwm_sortie.png`, `T2_variables_volatile.png`, `T2_vitesse_entree.png`, `T2_vitesse_sortie.png` |
| T3 Virgule fixe | 6 nov. | 0 → 0 ; 1 → 21 028 ; 748 → 15 728 944 (240,00 tr/min) ; 1 870 → 39 322 360 (600,00) ; 65 535 → 1 378 069 980 ; tous exacts | Conforme | relevés du débogueur (R0) |
| T4 ADC et DMA | 6 et 13 nov. | Potentiomètre en bas 0, au milieu 1 987, en haut 4 074 ; température brute ≈ 2 263–2 270 ; 341 tours de tampon en 7 094 ms = 48,1 tours/s = 3 076 conversions/s par voie (3 063 calculées, +0,4 %) | Conforme | `T4_bas_tampon_adc.png`, `T4_milieu.png`, `T4_haut.png` |
| T5 Consigne | 13 nov. | Sans effet en ARRÊT ; suit 0 → 100 % en marche, avec la rampe ; stable au repos (hystérésis) ; 0 en butée basse ; dans les deux sens | Conforme | `T5_consigne_66.png` (consigne 66, pwm 66) |
| T6 Température | 13 nov. | `temp_mv` 1 826, 25,2–25,5 °C, bruit ±0,15 °C ; thermomètre lu approximativement à 24,7 °C (écart ≤ 0,8 °C) ; pincement : hausse observée, maximum non relevé ; pont J5 non réalisé | Partiel | trames (`T9_trames.png`, 7ᵉ champ), commande `a` |
| T7 File d'événements | 13 nov. | Hôtes : 9/0 sous Windows (gcc 4.8.1) et Linux (gcc 15.2.0) ; cible : `Q,echecs=0` ; `t` (×3) : débordements 8 → 16 → 24, trames continues ; `z` : `Z,ok`, compteur à 0 | Conforme | `T7_q_autotest.png`, `T7_saturation_t.png`, `T7_saturation_z.png`, section J2 |
| T8 E-Stop | 13 nov. | Moteur en marche, E-Stop : point d'arrêt après `bl motor_stop_now`, TIM1 CCR1 = 0 (PSC 0, ARR 0xC7) ; ligne `E,estop`, état 3 et acquittement non consignés par capture | Conforme (point d'arrêt) | `T8_estop_tim1_ccr1.png` |
| T9 Télémétrie | 13 nov. | 51 trames de 863 403 à 873 403 ms, écart constant de 200 ms (5,00 Hz) ; 10 champs, aucune trame tronquée ; débordements 0 (capture faite à pwm 0) | Conforme | `T9_trames.png` |
| T10 Comparaison et traces | 13 nov. | `B,ecarts=0` ; cycles assembleur / C : 32 / 50 à -O0, 21 / 14 à -O2 ; tailles 28 / 64 / 20 octets ; désassemblage annoté | Conforme | `T10_bench_O2.png`, `T10_desassemblage_O0_O2.txt` |

## Déclaration des sources et de l'usage d'outils d'IA générative
- Sources (complément, corrigé du laboratoire 2 le cas échéant, CMSIS, manuel) : projet du laboratoire 2 de l'équipe ; complément CEG3536_Lab3_Complement (Brightspace : `bench_l3a.c`, `evq_test.c`, `telemetrie.py`, commandes série) ; énoncé v1.3 ; CMSIS (en-têtes STM32L5xx) ; RM0438, PM0264, DS12737 ; guide de la plateforme Leafy.
- Outils d'IA (outil, version, usage) ou « aucun usage » : Claude (Anthropic): aide a la comprehension des concepts
-  
