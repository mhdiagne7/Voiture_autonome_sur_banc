/* ---------------------------------------------------------------------------
 * fsm.s — machine à états du panneau de commande (CEG 3536, laboratoire 1)
 *
 * Routines exportées : fsm_init, fsm_step
 * Routine locale     : fsm_maj_del (seul point d'appel de led_set, critère B3)
 * Variables (.bss)   : etat, prochain_sens, touch_enabled, compteur_transitions,
 *                      clignote_compteur, clignote_phase, touch_signal_compteur
 *
 * États (section 3) :
 *   ETAT_ARRET          rouge fixe
 *   ETAT_MARCHE_AVANT   verte
 *   ETAT_MARCHE_ARRIERE bleue
 *   ETAT_ARRET_URGENCE  rouge clignotante 2 Hz
 *
 * Transitions :
 *   E2 : User      ARRÊT -> AVANT -> ARRÊT -> ARRIÈRE -> ARRÊT (hors urgence)
 *   E4 : estop_flag (posé par EXTI2_IRQHandler) -> ARRÊT_URGENCE, depuis tout état
 *   E5 : en ARRÊT_URGENCE, User est ignoré, la rouge clignote
 *   E6 : en ARRÊT_URGENCE, Touch En avec E-Stop relâché -> ARRÊT
 *   E7 : hors urgence, Touch En inverse touch_enabled + extinction brève 100 ms
 *
 * fsm_step est appelée toutes les PERIODE_SCRUTATION_MS (1 ms, SysTick) :
 * toutes les durées (anti-rebond, clignotement, extinction) sont comptées en
 * nombre d'appels. Aucune routine appelée ici ne bloque.
 * ------------------------------------------------------------------------- */

#include "registres.inc"

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
touch_enabled:          .space  4   /* autorisation TouchPad, 0/1 (E7)            */

    .global compteur_transitions
compteur_transitions:   .space  4   /* transitions produites par User (T3)        */

clignote_compteur:      .space  4   /* appels écoulés dans la demi-période (E5)   */

clignote_phase:         .space  4   /* 0 rouge éteinte, 1 rouge allumée (E5)      */

touch_signal_compteur:  .space  4   /* appels restants d'extinction brève (E7)    */


/* -------------------------------------------------------------------------
 * Table état -> DEL (un octet par état)
 * ------------------------------------------------------------------------- */
    .section .rodata

etat_vers_del:
    .byte   LED_ROUGE       /* ETAT_ARRET */
    .byte   LED_VERTE       /* ETAT_MARCHE_AVANT */
    .byte   LED_BLEUE       /* ETAT_MARCHE_ARRIERE */
    .byte   LED_ROUGE       /* ETAT_ARRET_URGENCE (clignotante, voir fsm_maj_del) */


    .text
    .align  2


/* =========================================================================
 * void fsm_init(void)
 *
 * E1 : après réinitialisation, etat = ETAT_ARRET, variables à zéro,
 *      prochain_sens = AVANT, DEL rouge seule.
 * AAPCS : appelle fsm_maj_del -> LR sauvegardé ; push {r4, lr} = 8 octets,
 *         pile alignée sur 8. Registres modifiés : r0-r2.
 * ========================================================================= */

    .global fsm_init
    .type   fsm_init, %function

fsm_init:
    push    {r4, lr}

    /* r1 = 0 utilisé pour initialiser les variables */
    movs    r1, #0

    /* État initial = ARRÊT */
    ldr     r0, =etat
    movs    r2, #ETAT_ARRET
    str     r2, [r0]

    /* Touch désactivé */
    ldr     r0, =touch_enabled
    str     r1, [r0]

    /* Aucune transition pour l'instant */
    ldr     r0, =compteur_transitions
    str     r1, [r0]

    /* Clignotement (E5) */
    ldr     r0, =clignote_compteur
    str     r1, [r0]

    ldr     r0, =clignote_phase
    str     r1, [r0]

    /* Extinction brève (E7) */
    ldr     r0, =touch_signal_compteur
    str     r1, [r0]

    /* Premier départ depuis ARRÊT = AVANT */
    ldr     r0, =prochain_sens
    str     r1, [r0]

    /* Afficher la DEL correspondant à ETAT_ARRET */
    bl      fsm_maj_del

    pop     {r4, pc}

    .size   fsm_init, .-fsm_init


/* =========================================================================
 * void fsm_step(void)
 *
 * Un pas de la machine à états :
 *   A. E4 : consommer estop_flag -> ARRÊT_URGENCE
 *   B. lire les événements validés de User et Touch En (button_pressed est
 *      appelée à CHAQUE pas pour les deux boutons, même quand l'événement
 *      est ignoré, afin que l'anti-rebond reste à jour)
 *   C. si ARRÊT_URGENCE : User ignoré (E5) ; Touch En + E-Stop relâché -> ARRÊT (E6)
 *      sinon            : Touch En -> bascule touch_enabled (E7) ;
 *                         User -> défilement (E2)
 *   D. fsm_maj_del
 *
 * AAPCS : appelle d'autres routines -> LR sauvegardé.
 *   push {r4, r5, r6, lr} = 16 octets : pile alignée sur 8 aux appels.
 *   r4 = événement User, r5 = événement Touch En, r6 = état courant.
 *   Registres modifiés : r0-r3 (r4-r6 restaurés).
 * ========================================================================= */

    .global fsm_step
    .type   fsm_step, %function

fsm_step:
    push    {r4, r5, r6, lr}

    /* -------------------------------------------------------------
     * A. E4 : l'ISR a-t-elle positionné estop_flag ?
     *    L'ISR a déjà mis les sorties en état sûr ; ici on fait le
     *    changement complet d'état.
     * ------------------------------------------------------------- */
    ldr     r0, =estop_flag
    ldr     r1, [r0]
    cmp     r1, #0
    beq     fsm_lire_boutons

    movs    r1, #0
    str     r1, [r0]                    /* estop_flag = 0 (drapeau consommé) */

    ldr     r0, =etat
    movs    r1, #ETAT_ARRET_URGENCE
    str     r1, [r0]

    /* départ du clignotement : rouge allumée (déjà allumée par l'ISR) */
    movs    r1, #0
    ldr     r0, =clignote_compteur
    str     r1, [r0]
    ldr     r0, =touch_signal_compteur  /* annuler une extinction brève en cours */
    str     r1, [r0]
    movs    r1, #1
    ldr     r0, =clignote_phase
    str     r1, [r0]


fsm_lire_boutons:
    /* -------------------------------------------------------------
     * B. Événements validés (anti-rebond + front, E3)
     * ------------------------------------------------------------- */
    movs    r0, #BTN_USER
    bl      button_pressed
    mov     r4, r0                      /* r4 = 1 si appui User validé */

    movs    r0, #BTN_TOUCH
    bl      button_pressed
    mov     r5, r0                      /* r5 = 1 si appui Touch En validé */

    ldr     r0, =etat
    ldr     r6, [r0]                    /* r6 = état courant */

    cmp     r6, #ETAT_ARRET_URGENCE
    bne     fsm_hors_urgence


    /* -------------------------------------------------------------
     * C1. ARRÊT_URGENCE
     *     E5 : r4 (User) n'est pas consulté -> appui ignoré.
     *     E6 : acquittement par Touch En seulement si E-Stop relâché.
     *          Aucune reprise automatique : sans appui Touch En, on reste.
     * ------------------------------------------------------------- */
    cmp     r5, #0
    beq     fsm_step_fin                /* pas d'appui Touch En */

    movs    r0, #BTN_ESTOP
    bl      button_raw                  /* niveau actuel de E-Stop (1 = appuyé) */
    cmp     r0, #0
    bne     fsm_step_fin                /* E-Stop maintenu : acquittement refusé */

    ldr     r0, =etat
    movs    r1, #ETAT_ARRET
    str     r1, [r0]                    /* ARRÊT_URGENCE -> ARRÊT (rouge fixe) */
    b       fsm_step_fin


fsm_hors_urgence:
    /* -------------------------------------------------------------
     * C2. E7 : Touch En hors urgence
     *     touch_enabled ^= 1 ; extinction brève de la DEL active.
     * ------------------------------------------------------------- */
    cmp     r5, #0
    beq     fsm_user

    ldr     r0, =touch_enabled
    ldr     r1, [r0]
    eor     r1, r1, #1
    str     r1, [r0]

    ldr     r0, =touch_signal_compteur
    movs    r1, #(TOUCH_SIGNAL_MS / PERIODE_SCRUTATION_MS)
    str     r1, [r0]


fsm_user:
    /* -------------------------------------------------------------
     * C3. E2 : défilement par User
     * ------------------------------------------------------------- */
    cmp     r4, #0
    beq     fsm_step_fin                /* pas d'appui User */

    ldr     r0, =etat                   /* r0 = &etat pour la suite */

    cmp     r6, #ETAT_ARRET
    beq     fsm_depuis_arret

    /* AVANT -> ARRÊT, ARRIÈRE -> ARRÊT */
    movs    r1, #ETAT_ARRET
    str     r1, [r0]
    b       fsm_transition_faite


fsm_depuis_arret:
    /* En ARRÊT : prochain_sens choisit AVANT (0) ou ARRIÈRE (1) */
    ldr     r1, =prochain_sens
    ldr     r2, [r1]
    cmp     r2, #0
    bne     fsm_vers_arriere

    /* ARRÊT -> MARCHE AVANT ; la prochaine sortie d'ARRÊT sera ARRIÈRE */
    movs    r3, #ETAT_MARCHE_AVANT
    str     r3, [r0]
    movs    r2, #1
    str     r2, [r1]
    b       fsm_transition_faite


fsm_vers_arriere:
    /* ARRÊT -> MARCHE ARRIÈRE ; la prochaine sortie d'ARRÊT sera AVANT */
    movs    r3, #ETAT_MARCHE_ARRIERE
    str     r3, [r0]
    movs    r2, #0
    str     r2, [r1]


fsm_transition_faite:
    /* compteur_transitions++ (preuve T3) */
    ldr     r0, =compteur_transitions
    ldr     r1, [r0]
    adds    r1, r1, #1
    str     r1, [r0]


fsm_step_fin:
    /* D. Mettre les DEL en accord avec l'état */
    bl      fsm_maj_del

    pop     {r4, r5, r6, pc}

    .size   fsm_step, .-fsm_step


/* =========================================================================
 * static void fsm_maj_del(void)
 *
 * Seul point d'appel de led_set (critère B3). Appelée à chaque pas.
 *   ARRÊT_URGENCE : E5 — clignote_compteur compte les appels ; tous les
 *                   CLIGNOTEMENT_DEMI_MS / PERIODE_SCRUTATION_MS (250) appels,
 *                   clignote_phase s'inverse : 250 ms allumée, 250 ms éteinte.
 *   Autres états  : E7 — tant que touch_signal_compteur > 0, le décrémenter
 *                   et éteindre (LED_AUCUNE) ; sinon DEL de etat_vers_del.
 * AAPCS : appelle led_set -> push {r4, lr}. r4 = état courant.
 *         Registres modifiés : r0-r3 (r4 restauré).
 * ========================================================================= */

    .type   fsm_maj_del, %function

fsm_maj_del:
    push    {r4, lr}

    ldr     r0, =etat
    ldr     r4, [r0]

    cmp     r4, #ETAT_ARRET_URGENCE
    bhi     fsm_maj_del_fin             /* état invalide : ne rien changer */
    bne     fsm_maj_del_normal


    /* ---------------- E5 : clignotement à 2 Hz ---------------- */
    ldr     r0, =clignote_compteur
    ldr     r1, [r0]
    adds    r1, r1, #1
    cmp     r1, #(CLIGNOTEMENT_DEMI_MS / PERIODE_SCRUTATION_MS)
    blo     fsm_clignote_garder

    /* demi-période écoulée : remettre le compteur à 0 et inverser la phase */
    movs    r1, #0
    ldr     r2, =clignote_phase
    ldr     r3, [r2]
    eor     r3, r3, #1
    str     r3, [r2]

fsm_clignote_garder:
    str     r1, [r0]

    ldr     r2, =clignote_phase
    ldr     r3, [r2]
    movs    r0, #LED_AUCUNE
    cmp     r3, #0
    beq     fsm_maj_del_ecrire          /* phase 0 : rouge éteinte */
    movs    r0, #LED_ROUGE              /* phase 1 : rouge allumée */
    b       fsm_maj_del_ecrire


fsm_maj_del_normal:
    /* ---------------- E7 : extinction brève ---------------- */
    ldr     r0, =touch_signal_compteur
    ldr     r1, [r0]
    cmp     r1, #0
    beq     fsm_maj_del_table

    subs    r1, r1, #1
    str     r1, [r0]
    movs    r0, #LED_AUCUNE             /* DEL active éteinte pendant 100 ms */
    b       fsm_maj_del_ecrire


fsm_maj_del_table:
    /* DEL fixe de l'état : etat_vers_del[etat] */
    ldr     r1, =etat_vers_del
    ldrb    r0, [r1, r4]


fsm_maj_del_ecrire:
    bl      led_set


fsm_maj_del_fin:
    pop     {r4, pc}

    .size   fsm_maj_del, .-fsm_maj_del
