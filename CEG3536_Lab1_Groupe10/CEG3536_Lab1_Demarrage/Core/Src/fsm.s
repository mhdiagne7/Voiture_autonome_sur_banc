/* ---------------------------------------------------------------------------
 * fsm.s — machine à états du panneau de commande (CEG 3536, laboratoire 1)
 *
 * E1 : état initial ARRÊT
 * E2 : transitions avec bouton User
 * E3 : anti-rebond réalisé dans buttons.s
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
etat:
    .space  4

/* 0 = prochain départ AVANT
 * 1 = prochain départ ARRIÈRE
 */
prochain_sens:
    .space  4

    .global touch_enabled
touch_enabled:
    .space  4

    .global compteur_transitions
compteur_transitions:
    .space  4

clignote_compteur:
    .space  4

clignote_phase:
    .space  4

touch_signal_compteur:
    .space  4


/* -------------------------------------------------------------------------
 * Table état -> DEL
 * ------------------------------------------------------------------------- */
    .section .rodata

etat_vers_del:
    .byte   LED_ROUGE       /* ETAT_ARRET */
    .byte   LED_VERTE       /* ETAT_MARCHE_AVANT */
    .byte   LED_BLEUE       /* ETAT_MARCHE_ARRIERE */
    .byte   LED_ROUGE       /* ETAT_ARRET_URGENCE */


    .text
    .align  2


/* =========================================================================
 * fsm_init
 *
 * E1 :
 * Après reset :
 *      etat = ETAT_ARRET
 *      prochain_sens = AVANT
 *      DEL rouge
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

    /* Variables utilisées plus tard pour E5 */
    ldr     r0, =clignote_compteur
    str     r1, [r0]

    ldr     r0, =clignote_phase
    str     r1, [r0]

    /* Variable utilisée plus tard pour E7 */
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
 * fsm_step
 *
 * E2 :
 *
 * ARRÊT -> AVANT -> ARRÊT -> ARRIÈRE -> ARRÊT -> ...
 *
 * button_pressed(BTN_USER) vient de E3.
 * Il retourne 1 UNE SEULE FOIS lorsqu'un appui est validé.
 * ========================================================================= */

    .global fsm_step
    .type   fsm_step, %function

fsm_step:
    push    {r4, lr}

    /* -------------------------------------------------------------
     * E2 : vérifier si un nouvel appui User vient d'être validé
     * ------------------------------------------------------------- */

    movs    r0, #BTN_USER
    bl      button_pressed

    /* r0 = 0 -> aucun nouvel appui */
    cmp     r0, #0
    beq     fsm_step_fin


    /* -------------------------------------------------------------
     * Un nouvel appui a été détecté.
     * Charger l'état actuel.
     * ------------------------------------------------------------- */

    ldr     r0, =etat
    ldr     r4, [r0]


    /* -------------------------------------------------------------
     * Si état actuel = ARRÊT,
     * il faut choisir AVANT ou ARRIÈRE.
     * ------------------------------------------------------------- */

    cmp     r4, #ETAT_ARRET
    beq     fsm_depuis_arret


    /* -------------------------------------------------------------
     * Si on était en AVANT ou ARRIÈRE :
     *
     *      AVANT   -> ARRÊT
     *      ARRIÈRE -> ARRÊT
     * ------------------------------------------------------------- */

    movs    r1, #ETAT_ARRET
    str     r1, [r0]

    b       fsm_transition_faite


/* =========================================================================
 * On est actuellement en ARRÊT.
 * Regarder prochain_sens pour savoir où aller.
 * ========================================================================= */

fsm_depuis_arret:

    ldr     r1, =prochain_sens
    ldr     r2, [r1]

    /* prochain_sens :
     * 0 -> AVANT
     * 1 -> ARRIÈRE
     */

    cmp     r2, #0
    bne     fsm_vers_arriere


    /* -------------------------------------------------------------
     * ARRÊT -> MARCHE AVANT
     * ------------------------------------------------------------- */

    movs    r3, #ETAT_MARCHE_AVANT
    str     r3, [r0]

    /* La prochaine sortie d'ARRÊT sera ARRIÈRE */
    movs    r2, #1
    str     r2, [r1]

    b       fsm_transition_faite


/* =========================================================================
 * ARRÊT -> MARCHE ARRIÈRE
 * ========================================================================= */

fsm_vers_arriere:

    movs    r3, #ETAT_MARCHE_ARRIERE
    str     r3, [r0]

    /* La prochaine sortie d'ARRÊT sera AVANT */
    movs    r2, #0
    str     r2, [r1]


/* =========================================================================
 * Une véritable transition vient d'avoir lieu.
 * ========================================================================= */

fsm_transition_faite:

    /* compteur_transitions++ */

    ldr     r0, =compteur_transitions
    ldr     r1, [r0]

    adds    r1, r1, #1

    str     r1, [r0]


/* =========================================================================
 * Fin d'un pas de FSM
 * ========================================================================= */

fsm_step_fin:

    /* Toujours remettre les DEL en accord avec l'état */
    bl      fsm_maj_del

    pop     {r4, pc}

    .size   fsm_step, .-fsm_step


/* =========================================================================
 * fsm_maj_del
 *
 * Pour E1-E3 :
 * simplement choisir la DEL correspondant à l'état.
 *
 * Le clignotement E5 et le signal Touch E7 seront ajoutés plus tard.
 * ========================================================================= */

    .type   fsm_maj_del, %function

fsm_maj_del:

    push    {r4, lr}

    /* Charger l'état courant */
    ldr     r0, =etat
    ldr     r4, [r0]

    /* Vérification que l'état est valide */
    cmp     r4, #ETAT_ARRET_URGENCE
    bhi     fsm_maj_del_fin


    /* -------------------------------------------------------------
     * E5 / E7 seront ajoutés ici plus tard.
     * ------------------------------------------------------------- */


    /* Chercher la DEL correspondant à l'état */

    ldr     r1, =etat_vers_del

    /* etat_vers_del[r4] */
    ldrb    r0, [r1, r4]

    /* r0 contient maintenant :
     * LED_ROUGE / LED_VERTE / LED_BLEUE
     */
    bl      led_set


fsm_maj_del_fin:

    pop     {r4, pc}

    .size   fsm_maj_del, .-fsm_maj_del
