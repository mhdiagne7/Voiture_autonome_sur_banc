/* ---------------------------------------------------------------------------
 * acq.c — objet d'acquisition d'une voie analogique (CEG 3536, lab. 3, L3-C)
 * Aucun registre : les échantillons viennent d'un tampon mémoire rempli par
 * le DMA. Toutes les opérations en entiers 32 bits.
 * Version 1 : acq_init, acq_brut, acq_mv, acq_valeur (relation linéaire).
 * Version 2 (changement d'exigence, énoncé 4.6) : acq_config_filtre et, dans
 * acq_valeur, zone morte puis hystérésis, sans toucher aux appelants.
 * ------------------------------------------------------------------------- */
#include "acq.h"

#define ACQ_PLEINE_ECHELLE 4095
#define ACQ_VREF_MV        3300

void acq_init(acq_t *a, const volatile uint16_t *src, uint32_t pas, uint32_t n_moy,
              int32_t gain_num, int32_t gain_den, int32_t decalage)
{
    a->src = src;
    a->pas = (pas == 0u) ? 1u : pas;
    a->n_moy = (n_moy == 0u) ? 1u : n_moy;
    a->gain_num = gain_num;
    a->gain_den = (gain_den == 0) ? 1 : gain_den;
    a->decalage = decalage;
    a->hysteresis = 0;
    a->zone_morte = 0;
    a->v_min = 0;
    a->v_max = 0;
    a->derniere = 0;
    a->initialisee = 0u;
}

void acq_config_filtre(acq_t *a, int32_t hysteresis, int32_t zone_morte,
                       int32_t v_min, int32_t v_max)
{
    a->hysteresis = hysteresis;
    a->zone_morte = zone_morte;
    a->v_min = v_min;
    a->v_max = v_max;
    a->initialisee = 0u;      /* la prochaine valeur est prise telle quelle   */
}

/* Moyenne arrondie des n_moy échantillons src[i * pas] du tampon DMA (E4).
 * Chaque lecture de 16 bits est atomique : le DMA peut écrire pendant le calcul
 * sans produire de valeur incohérente.                                       */
uint32_t acq_brut(const acq_t *a)
{
    uint32_t somme = 0u;
    for (uint32_t i = 0u; i < a->n_moy; i++) {
        somme += a->src[i * a->pas];
    }
    return (somme + a->n_moy / 2u) / a->n_moy;
}

uint32_t acq_mv(const acq_t *a)
{
    return (acq_brut(a) * ACQ_VREF_MV + ACQ_PLEINE_ECHELLE / 2) / ACQ_PLEINE_ECHELLE;
}

/* v = mv x gain_num / gain_den + decalage (E5, E6).
 * Version 2 (énoncé 4.6) : zone morte aux extrémités, puis hystérésis : la valeur
 * ne change que si l'écart avec la dernière dépasse hysteresis. Une valeur ramenée
 * à une extrémité par la zone morte passe directement : sinon, la consigne
 * resterait bloquée à 1 ou 2 % avec le potentiomètre tout en bas.            */
int32_t acq_valeur(acq_t *a)
{
    int32_t v = ((int32_t)acq_mv(a) * a->gain_num) / a->gain_den + a->decalage;
    int32_t extremite = 0;

    if (a->zone_morte > 0) {
        if (v < a->v_min + a->zone_morte) {
            v = a->v_min;
            extremite = 1;
        } else if (v >= a->v_max - a->zone_morte) {
            v = a->v_max;
            extremite = 1;
        }
    }
    if (a->hysteresis > 0 && a->initialisee && !extremite) {
        int32_t ecart = v - a->derniere;
        if (ecart < 0) {
            ecart = -ecart;
        }
        if (ecart <= a->hysteresis) {
            return a->derniere;
        }
    }
    a->derniere = v;
    a->initialisee = 1u;
    return v;
}
