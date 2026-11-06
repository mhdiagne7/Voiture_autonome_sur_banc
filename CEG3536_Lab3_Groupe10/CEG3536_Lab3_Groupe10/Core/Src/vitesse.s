/* ---------------------------------------------------------------------------
 * vitesse.s — conversion des fronts d'encodeur en vitesse, virgule fixe
 *             (CEG 3536, laboratoire 3, E3)
 *
 * Routine exportée (AAPCS) : enc_fronts_vers_rpm_q16 (prototype dans lab3.h)
 *
 * Fenêtre de FENETRE_VITESSE_MS = 250 ms ; 748 fronts par tour de l'arbre de
 * sortie (2 fronts x 11 impulsions x 34). tr/min = fronts x 4 x 60 / 748
 * = fronts x 240 / 748.
 * Format Q16.16 : résultat = tr/min x 65536 = fronts x (240 x 65536 / 748).
 * Constante : k = round(240 x 65536 / 748) = round(21027,68) = 21028, soit
 * une erreur relative de +0,0015 % (< 0,05 % exigés, E3).
 * Débordement : fronts x k tient sur 32 bits pour fronts <= 204 249
 * (2^32 / 21028) ; le maximum exigé est 65 535. À pleine vitesse, le banc donne
 * environ 1 100 fronts par fenêtre de 250 ms.
 * ------------------------------------------------------------------------- */
#include "registres.inc"
#include "registres_lab2.inc"

    .syntax unified
    .cpu    cortex-m33
    .thumb

    .equ RPM_Q16_K, 21028        /* identique à RPM_Q16_K de lab3.h               */

    .text
    .align  2

/* uint32_t enc_fronts_vers_rpm_q16(uint32_t fronts)
 * r0 = fronts comptés dans la fenêtre ; retour r0 = tr/min en Q16.16.
 * Routine feuille : modifie r0 et r1, rien à préserver, retour par bx lr.
 * mul sur 32 bits suffit (voir ci-dessus).                                  */
    .global enc_fronts_vers_rpm_q16
    .type   enc_fronts_vers_rpm_q16, %function
enc_fronts_vers_rpm_q16:
    ldr     r1, =RPM_Q16_K
    mul     r0, r0, r1                  /* r0 = fronts x k = tr/min x 65536 */
    bx      lr
    .size   enc_fronts_vers_rpm_q16, .-enc_fronts_vers_rpm_q16
