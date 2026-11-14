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

| Séance | Réalise | Valide | Module C écrit par chacun | Routine assembleur écrite ou modifiée par chacun |
|---|---|---|---|---|
| Séance 1 | | | | |
| Période d'étude | | | | |
| Séance 2 | | | | |

## Calculs préalables

| Grandeur | Formule | Valeur | Vérifiée par |
|---|---|---|---|
| `RPM_Q16_K` | round(240 × 65 536 / 748) | | T3 |
| Erreur relative de la constante | (k − 240 × 65 536 / 748) / (240 × 65 536 / 748) | | T3 |
| fronts maximal sans débordement | 2³² / k | | T3 |
| `LPUART1_BRR` | 256 × 4 000 000 / 115 200 | | T9 |
| Débit ADC par voie | 4 MHz / (2 × (640,5 + 12,5)) | | T4 |
| Durée d'un tour du tampon DMA | 16 / débit par voie | | T4 |
| Résolution de la température | 3 300 mV / 4 095 / 10,9 mV/°C | | T6 |

## Étalonnage de la température (E6)

| Mesure | Température de référence (°C) | `temp_mv` lu | `TEMP_MV_REF` / `TEMP_C10_REF` retenus | Position de S2 |
|---|---|---|---|---|
| Ambiante | | | | |
| Capteur tenu entre deux doigts (30 s) | | | | |
| Conditionnement externe (pont OUT–IN ou circuit) | | | | |

Analyse interne / externe (plage, résolution, bruit) :

## Journal des séances

### Séance 1 — `<date>` — réalise : `<nom>` / valide : `<nom>`
- Objectifs :
- Fait :
- Décisions (découpage des modules, format des trames, routine L3-A choisie) :
- Difficultés et solutions :
- Mesures :
- Validations Git :

### Période d'étude — travail sur hôte
- Fait (evq, test_evq, cas ajoutés, L3-B / L3-C rédigés) :
- Validations Git :

### Séance 2 — `<date>` — réalise : `<nom>` / valide : `<nom>`
- Objectifs :
- Fait :
- Décisions :
- Difficultés et solutions :
- Mesures (température, cycles DWT, désassemblage) :
- Validations Git :

## Composante L3-A : comparaison assembleur / C

Routine comparée : `<motor_set_pwm | button_pressed | led_set | encoder_read>`

| Cas | Entrée | Résultat assembleur | Résultat C | Effet de bord (registre / variable) | Écart |
|---|---|---|---|---|---|
| 1 | | | | | |

| Version | Cycles DWT (moyenne) | Taille (octets) | Registres utilisés | Observations (prologue, volatile) |
|---|---|---|---|---|
| Assembleur | | | | |
| C, -O0 | | | | |
| C, -O2 | | | | |

## Composante L3-C : objet d'acquisition

- Version 1 (validation Git) :
- Version 2 (validation Git) et ce qui a changé :
- Essai d'indépendance des deux instances :
- Comparaison avec la version impérative (annexe) :
- Limites :

## Composante L3-D : traces

| Élément | Preuve (fichier) |
|---|---|
| Désassemblage -O0 annoté | |
| Désassemblage -O2 annoté | |
| Trois instructions et leur encodage Thumb | |
| Captures du débogueur (R0–R3, SP, variable volatile) | |
| Cycles DWT -O0 / -O2 et transformation analysée | |

## Tableau des essais (T1 à T10)

| Essai | Date | Résultat observé | Verdict | Preuve (fichier) |
|---|---|---|---|---|
| T1 Initialisation en C | | | | |
| T2 Appel C → assembleur | | | | |
| T3 Virgule fixe | | | | |
| T4 ADC et DMA | | | | |
| T5 Consigne | | | | |
| T6 Température | | | | |
| T7 File d'événements | | | | |
| T8 E-Stop | | | | |
| T9 Télémétrie | | | | |
| T10 Comparaison et traces | | | | |

## Déclaration des sources et de l'usage d'outils d'IA générative
- Sources (complément, corrigé du laboratoire 2 le cas échéant, CMSIS, manuel) :
- Outils d'IA (outil, version, usage) ou « aucun usage » :
