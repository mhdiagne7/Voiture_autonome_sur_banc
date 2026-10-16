/* ---------------------------------------------------------------------------
 * fsm.s — machine à états du véhicule : panneau de commande (laboratoire 1)
 *         et propulsion, consigne, rampe, vitesse, buzzer (laboratoire 2)
 *         (CEG 3536)
 *
 * Routines exportées : fsm_init, fsm_step
 * Routines locales   : fsm_entree_etat (entrée dans un état hors urgence),
 *                      fsm_maj_sorties (seul point d'appel de led_set,
 *                      motor_set_pwm et buzzer_step, critère B4)
 * Variables (.bss)   : etat, prochain_sens, touch_enabled, compteur_transitions,
 *                      consigne_pct, pwm_pct, rampe_compteur, fenetre_compteur,
 *                      clignote_compteur, clignote_phase, blink_cycles,
 *                      blink_dernier
 *
 * États et sorties (section 3 du lab 2) :
 *   ARRÊT           rouge fixe   PWM 0      AI1 0 AI2 0 STB 0   bip court
 *   MARCHE_AVANT    verte        rampe      AI1 1 AI2 0 STB 1   bip court
 *   MARCHE_ARRIÈRE  bleue        rampe      AI1 0 AI2 1 STB 1   double bip
 *   ARRÊT_URGENCE   rouge 2 Hz   0 (ISR)    0     0     0 (ISR) son continu
 *
 * Transitions :
 *   E3 : User   ARRÊT -> AVANT -> ARRÊT -> ARRIÈRE -> ARRÊT (hors urgence) ;
 *               le changement de sens passe toujours par ARRÊT (CCR1 = 0).
 *   E4 : Touch En hors urgence : consigne 25 -> 50 -> 75 -> 100 -> 25, bip.
 *   E7 : estop_flag (levé par EXTI2_IRQHandler) -> ARRÊT_URGENCE.
 *   E8 : en urgence, User et consigne ignorés ; Touch En avec E-Stop relâché
 *        -> ARRÊT (son coupé, consigne conservée, moteur arrêté).
 *
 * fsm_step est appelée exactement une fois par ms (boucle principale
 * cadencée par tick_1ms, SysTick) : toutes les durées sont des compteurs
 * d'appels. Aucune routine appelée ici ne bloque.
 * ------------------------------------------------------------------------- */

#include "registres.inc"
#include "registres_lab2.inc"

    .syntax unified
    .cpu    cortex-m33
    .thumb


/* -------------------------------------------------------------------------
 * Variables
 * ------------------------------------------------------------------------- */
    .bss
    .align  2

    .global etat
etat:                   .space  4   /* état courant (ETAT_x)                      */

prochain_sens:          .space  4   /* 0 = prochain départ AVANT, 1 = ARRIÈRE     */

    .global touch_enabled
touch_enabled:          .space  4   /* lab 1 ; reste à 0 au lab 2 (lab1.h)        */

    .global compteur_transitions
compteur_transitions:   .space  4   /* entrées dans un état hors urgence          */

    .global consigne_pct
consigne_pct:           .space  4   /* consigne de vitesse : 25, 50, 75, 100 %    */

    .global pwm_pct
pwm_pct:                .space  4   /* rapport cyclique appliqué (rampe), %       */

rampe_compteur:         .space  4   /* ms écoulées dans le pas de rampe (10 ms)   */

fenetre_compteur:       .space  4   /* ms écoulées dans la fenêtre de vitesse     */

clignote_compteur:      .space  4   /* ms écoulées dans la demi-période (250 ms)  */

clignote_phase:         .space  4   /* 0 rouge éteinte, 1 rouge allumée           */

    .global blink_cycles
blink_cycles:           .space  4   /* cycles DWT entre deux basculements (lab 1) */

blink_dernier:          .space  4   /* DWT_CYCCNT au basculement précédent        */


/* -------------------------------------------------------------------------
 * Tables indexées par l'état (un octet par état, ETAT_ARRET .. URGENCE)
 * ------------------------------------------------------------------------- */
    .section .rodata

etat_vers_del:
    .byte   LED_ROUGE, LED_VERTE, LED_BLEUE, LED_ROUGE

etat_vers_dir:                      /* paramètre de motor_set_dir              */
    .byte   MOTOR_ARRET, MOTOR_AVANT, MOTOR_ARRIERE, MOTOR_ARRET

etat_vers_bips:                     /* paramètre de buzzer_bip (E9)            */
    .byte   1, 1, 2, 0


    .text
    .align  2


/* =========================================================================
 * void fsm_init(void)
 *
 * E1 : etat = ARRÊT, consigne 50 %, PWM nulle, variables à zéro, DEL rouge
 * seule, buzzer silencieux (aucun bip au démarrage). motor_init a déjà mis
 * CCR1 = 0, STB = 0, AI1 = AI2 = 0.
 * Démarre aussi DWT_CYCCNT pour blink_cycles (mesure du clignotement).
 * AAPCS : appelle fsm_maj_sorties -> push {r4, lr} (8 octets, pile alignée).
 * Registres modifiés : r0-r2.
 * ========================================================================= */

    .global fsm_init
    .type   fsm_init, %function

fsm_init:
    push    {r4, lr}

    movs    r1, #0
    ldr     r0, =etat
    str     r1, [r0]                    /* ETAT_ARRET = 0 */
    ldr     r0, =prochain_sens
    str     r1, [r0]
    ldr     r0, =touch_enabled
    str     r1, [r0]
    ldr     r0, =compteur_transitions
    str     r1, [r0]
    ldr     r0, =pwm_pct
    str     r1, [r0]
    ldr     r0, =rampe_compteur
    str     r1, [r0]
    ldr     r0, =fenetre_compteur
    str     r1, [r0]
    ldr     r0, =clignote_compteur
    str     r1, [r0]
    ldr     r0, =clignote_phase
    str     r1, [r0]
    ldr     r0, =blink_cycles
    str     r1, [r0]
    ldr     r0, =blink_dernier
    str     r1, [r0]

    movs    r2, #CONSIGNE_INITIALE
    ldr     r0, =consigne_pct
    str     r2, [r0]                    /* 50 % après réinitialisation */

    /* DWT_CYCCNT : DEMCR.TRCENA puis DWT_CTRL.CYCCNTENA */
    ldr     r0, =DEMCR
    ldr     r2, [r0]
    orr     r2, r2, #DEMCR_TRCENA
    str     r2, [r0]
    ldr     r0, =DWT_CYCCNT
    str     r1, [r0]
    ldr     r0, =DWT_CTRL
    ldr     r2, [r0]
    orr     r2, r2, #DWT_CTRL_CYCCNTENA
    str     r2, [r0]

    bl      fsm_maj_sorties             /* rouge seule, PWM 0, silence */

    pop     {r4, pc}

    .size   fsm_init, .-fsm_init


/* =========================================================================
 * static void fsm_entree_etat(uint32_t nouvel_etat)
 *
 * Entrée dans ARRÊT, MARCHE_AVANT ou MARCHE_ARRIÈRE (jamais l'urgence) :
 *   etat = r0 ; compteur_transitions++ ; pwm_pct = 0 ; rampe_compteur = 0 ;
 *   motor_set_dir(etat_vers_dir[etat]) ; buzzer_bip(etat_vers_bips[etat]).
 * motor_set_dir accepte toujours ici : vers ARRÊT elle force CCR1 = 0 ;
 * depuis ARRÊT, CCR1 est déjà nul (règle E3). La rampe repart de 0.
 * AAPCS : appelle deux routines -> push {r4, lr} ; r4 = nouvel état.
 * Registres modifiés : r0-r3.
 * ========================================================================= */

    .type   fsm_entree_etat, %function

fsm_entree_etat:
    push    {r4, lr}
    mov     r4, r0

    ldr     r1, =etat
    str     r4, [r1]

    ldr     r1, =compteur_transitions
    ldr     r2, [r1]
    adds    r2, r2, #1
    str     r2, [r1]

    movs    r2, #0
    ldr     r1, =pwm_pct
    str     r2, [r1]
    ldr     r1, =rampe_compteur
    str     r2, [r1]

    ldr     r1, =etat_vers_dir
    ldrb    r0, [r1, r4]
    bl      motor_set_dir               /* AI1/AI2/STB selon l'état (E3) */

    ldr     r1, =etat_vers_bips
    ldrb    r0, [r1, r4]
    bl      buzzer_bip                  /* bip court ou double bip (E9) */

    pop     {r4, pc}

    .size   fsm_entree_etat, .-fsm_entree_etat


/* =========================================================================
 * void fsm_step(void)
 *
 * Un pas de la machine à états, une fois par ms :
 *   A. E7 : estop_flag levé -> le consommer, propulsion à zéro (redondant
 *      avec l'ISR), son continu, etat = ARRÊT_URGENCE, départ du clignotement.
 *   B. événements validés de User et Touch En (button_pressed appelée à
 *      chaque pas pour les deux boutons, même en urgence, pour l'anti-rebond).
 *   C. en urgence : User et consigne ignorés ; Touch En + E-Stop relâché
 *      -> son coupé, ARRÊT (E8).
 *      hors urgence : Touch En -> consigne suivante + bip (E4) ;
 *                     User -> défilement des états (E3).
 *   D. fenêtre de vitesse : toutes les 500 ms, encoder_read (E6).
 *   E. fsm_maj_sorties : rampe, DEL, buzzer.
 *
 * AAPCS : push {r4, r5, r6, lr} = 16 octets (pile alignée sur 8).
 *   r4 = événement User, r5 = événement Touch En, r6 = état courant.
 * Registres modifiés : r0-r3 (r4-r6 restaurés).
 * ========================================================================= */

    .global fsm_step
    .type   fsm_step, %function

fsm_step:
    push    {r4, r5, r6, lr}

    /* -------------------------------------------------------------
     * A. E-Stop : l'ISR a déjà coupé le moteur, allumé la rouge et le
     *    buzzer ; ici, le changement complet d'état.
     * ------------------------------------------------------------- */
    ldr     r0, =estop_flag
    ldr     r1, [r0]
    cmp     r1, #0
    beq     fsm_lire_boutons

    movs    r1, #0
    str     r1, [r0]                    /* drapeau consommé */

    bl      motor_stop_now              /* redondant avec l'ISR : état sûr garanti */

    movs    r1, #0
    ldr     r0, =pwm_pct
    str     r1, [r0]
    ldr     r0, =rampe_compteur
    str     r1, [r0]
    ldr     r0, =clignote_compteur
    str     r1, [r0]

    movs    r1, #1
    ldr     r0, =buzzer_continu
    str     r1, [r0]                    /* son continu jusqu'à l'acquittement */
    ldr     r0, =clignote_phase
    str     r1, [r0]                    /* rouge allumée (déjà par l'ISR) */

    movs    r1, #ETAT_ARRET_URGENCE
    ldr     r0, =etat
    str     r1, [r0]

    ldr     r0, =DWT_CYCCNT             /* départ de la mesure du clignotement */
    ldr     r1, [r0]
    ldr     r0, =blink_dernier
    str     r1, [r0]


fsm_lire_boutons:
    /* -------------------------------------------------------------
     * B. Événements validés (anti-rebond 30 ms + front)
     * ------------------------------------------------------------- */
    movs    r0, #BTN_USER
    bl      button_pressed
    mov     r4, r0

    movs    r0, #BTN_TOUCH
    bl      button_pressed
    mov     r5, r0

    ldr     r0, =etat
    ldr     r6, [r0]

    cmp     r6, #ETAT_ARRET_URGENCE
    bne     fsm_hors_urgence


    /* -------------------------------------------------------------
     * C1. ARRÊT_URGENCE (E8) : User et consigne ignorés ;
     *     acquittement seulement si E-Stop relâché.
     * ------------------------------------------------------------- */
    cmp     r5, #0
    beq     fsm_fenetre

    movs    r0, #BTN_ESTOP
    bl      button_raw
    cmp     r0, #0
    bne     fsm_fenetre                 /* E-Stop maintenu : refusé */

    movs    r1, #0
    ldr     r0, =buzzer_continu
    str     r1, [r0]                    /* son coupé */
    movs    r0, #ETAT_ARRET
    bl      fsm_entree_etat             /* rouge fixe, moteur arrêté, bip court */
    b       fsm_fenetre


fsm_hors_urgence:
    /* -------------------------------------------------------------
     * C2. E4 : Touch En -> consigne suivante (100 -> 25), bip court
     * ------------------------------------------------------------- */
    cmp     r5, #0
    beq     fsm_user

    ldr     r0, =consigne_pct
    ldr     r1, [r0]
    adds    r1, r1, #CONSIGNE_PAS
    cmp     r1, #CONSIGNE_MAX
    it      hi
    movhi   r1, #CONSIGNE_MIN
    str     r1, [r0]
    movs    r0, #1
    bl      buzzer_bip


fsm_user:
    /* -------------------------------------------------------------
     * C3. E3 : User -> défilement ; le sens change toujours via ARRÊT
     * ------------------------------------------------------------- */
    cmp     r4, #0
    beq     fsm_fenetre

    cmp     r6, #ETAT_ARRET
    beq     fsm_depuis_arret

    movs    r0, #ETAT_ARRET             /* AVANT ou ARRIÈRE -> ARRÊT (CCR1 = 0) */
    bl      fsm_entree_etat
    b       fsm_fenetre

fsm_depuis_arret:
    ldr     r1, =prochain_sens
    ldr     r2, [r1]
    cmp     r2, #0
    bne     fsm_vers_arriere

    movs    r2, #1
    str     r2, [r1]                    /* prochaine sortie d'ARRÊT : ARRIÈRE */
    movs    r0, #ETAT_MARCHE_AVANT
    bl      fsm_entree_etat
    b       fsm_fenetre

fsm_vers_arriere:
    movs    r2, #0
    str     r2, [r1]                    /* prochaine sortie d'ARRÊT : AVANT */
    movs    r0, #ETAT_MARCHE_ARRIERE
    bl      fsm_entree_etat


fsm_fenetre:
    /* -------------------------------------------------------------
     * D. E6 : fenêtre de vitesse de FENETRE_VITESSE_MS (500 ms)
     * ------------------------------------------------------------- */
    ldr     r1, =fenetre_compteur
    ldr     r0, [r1]
    adds    r0, r0, #1
    cmp     r0, #FENETRE_VITESSE_MS
    blo     fsm_fenetre_garder
    movs    r0, #0
    str     r0, [r1]
    ldr     r0, =sens_mesure
    bl      encoder_read                /* vitesse_fronts et sens_mesure */
    b       fsm_sorties
fsm_fenetre_garder:
    str     r0, [r1]


fsm_sorties:
    /* E. Sorties : rampe, DEL, buzzer */
    bl      fsm_maj_sorties

    pop     {r4, r5, r6, pc}

    .size   fsm_step, .-fsm_step


/* =========================================================================
 * static void fsm_maj_sorties(void)
 *
 * Seul point de mise à jour des sorties (critère B4), une fois par ms :
 *   1. Rampe (E4), en MARCHE_AVANT et MARCHE_ARRIÈRE : toutes les
 *      RAMPE_PAS_MS (10) ms, pwm_pct se rapproche de consigne_pct d'un point,
 *      puis motor_set_pwm(pwm_pct). 0 -> 100 % en 100 pas = 1 s.
 *   2. DEL : en urgence, clignotement 250 / 250 ms (et blink_cycles) ;
 *      sinon etat_vers_del[etat].
 *   3. buzzer_step : bips et son continu (E9).
 * AAPCS : push {r4, lr} ; r4 = état courant. Registres modifiés : r0-r3, r12.
 * ========================================================================= */

    .type   fsm_maj_sorties, %function

fsm_maj_sorties:
    push    {r4, lr}

    ldr     r0, =etat
    ldr     r4, [r0]
    cmp     r4, #ETAT_ARRET_URGENCE
    bhi     fsm_maj_sorties_fin         /* état invalide : ne rien changer */


    /* ---------------- 1. Rampe (E4) ---------------- */
    cmp     r4, #ETAT_MARCHE_AVANT
    beq     fsm_rampe
    cmp     r4, #ETAT_MARCHE_ARRIERE
    bne     fsm_del

fsm_rampe:
    ldr     r1, =rampe_compteur
    ldr     r0, [r1]
    adds    r0, r0, #1
    cmp     r0, #RAMPE_PAS_MS
    blo     fsm_rampe_garder
    movs    r0, #0
    str     r0, [r1]

    ldr     r1, =pwm_pct
    ldr     r0, [r1]
    ldr     r2, =consigne_pct
    ldr     r2, [r2]
    cmp     r0, r2
    beq     fsm_del                     /* consigne atteinte */
    ite     lo
    addlo   r0, r0, #1                  /* montée d'un point */
    subhs   r0, r0, #1                  /* descente d'un point */
    str     r0, [r1]
    bl      motor_set_pwm               /* CCR1 = pwm_pct × 200 / 100 */
    b       fsm_del

fsm_rampe_garder:
    str     r0, [r1]


fsm_del:
    /* ---------------- 2. DEL ---------------- */
    cmp     r4, #ETAT_ARRET_URGENCE
    bne     fsm_del_table

    /* Clignotement à 2 Hz (E8) */
    ldr     r0, =clignote_compteur
    ldr     r1, [r0]
    adds    r1, r1, #1
    cmp     r1, #(CLIGNOTEMENT_DEMI_MS / PERIODE_SCRUTATION_MS)
    blo     fsm_clignote_garder

    movs    r1, #0                      /* demi-période écoulée */
    ldr     r2, =clignote_phase
    ldr     r3, [r2]
    eor     r3, r3, #1
    str     r3, [r2]

    /* blink_cycles = écart de DWT_CYCCNT avec le basculement précédent */
    ldr     r2, =DWT_CYCCNT
    ldr     r3, [r2]
    ldr     r2, =blink_dernier
    ldr     r12, [r2]
    str     r3, [r2]
    sub     r3, r3, r12
    ldr     r2, =blink_cycles
    str     r3, [r2]

fsm_clignote_garder:
    str     r1, [r0]

    ldr     r2, =clignote_phase
    ldr     r3, [r2]
    movs    r0, #LED_AUCUNE
    cmp     r3, #0
    beq     fsm_del_ecrire
    movs    r0, #LED_ROUGE
    b       fsm_del_ecrire

fsm_del_table:
    ldr     r1, =etat_vers_del
    ldrb    r0, [r1, r4]

fsm_del_ecrire:
    bl      led_set


    /* ---------------- 3. Buzzer (E9) ---------------- */
    bl      buzzer_step


fsm_maj_sorties_fin:
    pop     {r4, pc}

    .size   fsm_maj_sorties, .-fsm_maj_sorties
