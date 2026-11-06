/* ---------------------------------------------------------------------------
 * l3a_c.c — version C de la routine assembleur conservée pour L3-A
 *           (CEG 3536, laboratoire 3)
 *
 * Composante L3-A (section 4.5 de l'énoncé) : réécrire en C, avec exactement
 * le même prototype et le même comportement, la routine assembleur conservée
 * du laboratoire 1 ou 2 (button_pressed, led_set, motor_set_pwm ou
 * encoder_read, au choix de l'équipe), sans modifier la version assembleur.
 * Le squelette ci-dessous vise motor_set_pwm (motor.s, laboratoire 2) ;
 * adapter le prototype, bench_l3a.h et les cas du banc si une autre routine
 * est choisie. Comparer valeur de retour, effets de bord et cycles DWT avec
 * bench_l3a.c (commande série b), puis le désassemblage à -O0 et -O2.
 * ------------------------------------------------------------------------- */
#include "stm32l552xx.h"
#include "bench_l3a.h"

uint32_t motor_set_pwm_c(uint32_t pct)
{
    /* Même comportement que motor_set_pwm (motor.s) : saturation à 100 %,
     * CCR1 = pct x (ARR + 1) / 100, écriture du registre, retour de la valeur. */
    uint32_t ccr;

    if (pct > 100u) {
        pct = 100u;
    }
    ccr = pct * 200u / 100u;                   /* ARR + 1 = 200 (PWM_PLEINE)   */
    TIM1->CCR1 = ccr;
    return ccr;
}
