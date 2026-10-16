/* ---------------------------------------------------------------------------
 * gpio.s — pilote RCC/GPIO au niveau des registres (CEG 3536, laboratoire 1)
 *
 * Routines exportées (AAPCS) : gpio_init, led_set
 * Aucun appel à la HAL. Adresses et masques : registres.inc (RM0438).
 * ------------------------------------------------------------------------- */
#include "registres.inc"

    .syntax unified
    .cpu    cortex-m33
    .thumb

    .text
    .align  2

/* void gpio_init(void)
 * Active les horloges GPIOA/B/C (RCC_AHB2ENR) et configure :
 *   PA9 (rouge), PC7 (verte), PB7 (bleue) : sortie push-pull, basse vitesse
 *   PC13 (User), PB2 (E-Stop), PB5 (Touch En) : entrée, PUPDR selon registres.inc
 * Registres modifiés : r0, r1 (routine feuille, rien à préserver).          */
    .global gpio_init
    .type   gpio_init, %function
gpio_init:
    /* --- horloges des ports A, B, C --- */
    ldr     r0, =RCC_BASE
    ldr     r1, [r0, #RCC_AHB2ENR]
    orr     r1, r1, #(RCC_AHB2ENR_GPIOAEN | RCC_AHB2ENR_GPIOBEN | RCC_AHB2ENR_GPIOCEN)
    str     r1, [r0, #RCC_AHB2ENR]
    ldr     r1, [r0, #RCC_AHB2ENR]  /* relecture : délai après activation */

    /* --- GPIOA : PA9 sortie --- */
    ldr     r0, =GPIOA_BASE
    ldr     r1, [r0, #GPIO_MODER]
    bic     r1, r1, #(3 << (2 * LED_ROUGE_PIN))
    orr     r1, r1, #(1 << (2 * LED_ROUGE_PIN))
    str     r1, [r0, #GPIO_MODER]
    ldr     r1, [r0, #GPIO_OTYPER]
    bic     r1, r1, #(1 << LED_ROUGE_PIN)           /* push-pull */
    str     r1, [r0, #GPIO_OTYPER]
    ldr     r1, [r0, #GPIO_OSPEEDR]
    bic     r1, r1, #(3 << (2 * LED_ROUGE_PIN))     /* basse vitesse */
    str     r1, [r0, #GPIO_OSPEEDR]
    ldr     r1, [r0, #GPIO_PUPDR]
    bic     r1, r1, #(3 << (2 * LED_ROUGE_PIN))     /* aucun tirage */
    str     r1, [r0, #GPIO_PUPDR]

    /* --- GPIOC : PC7 sortie, PC13 entrée --- */
    ldr     r0, =GPIOC_BASE
    ldr     r1, [r0, #GPIO_MODER]
    bic     r1, r1, #(3 << (2 * LED_VERTE_PIN))
    orr     r1, r1, #(1 << (2 * LED_VERTE_PIN))
    bic     r1, r1, #(3 << (2 * BTN_USER_PIN))      /* 00 = entrée */
    str     r1, [r0, #GPIO_MODER]
    ldr     r1, [r0, #GPIO_OTYPER]
    bic     r1, r1, #(1 << LED_VERTE_PIN)
    str     r1, [r0, #GPIO_OTYPER]
    ldr     r1, [r0, #GPIO_OSPEEDR]
    bic     r1, r1, #(3 << (2 * LED_VERTE_PIN))
    str     r1, [r0, #GPIO_OSPEEDR]
    ldr     r1, [r0, #GPIO_PUPDR]
    bic     r1, r1, #(3 << (2 * LED_VERTE_PIN))
    bic     r1, r1, #(3 << (2 * BTN_USER_PIN))
    orr     r1, r1, #(BTN_USER_PUPDR << (2 * BTN_USER_PIN))
    str     r1, [r0, #GPIO_PUPDR]

    /* --- GPIOB : PB7 sortie, PB2 et PB5 entrées --- */
    ldr     r0, =GPIOB_BASE
    ldr     r1, [r0, #GPIO_MODER]
    bic     r1, r1, #(3 << (2 * LED_BLEUE_PIN))
    orr     r1, r1, #(1 << (2 * LED_BLEUE_PIN))
    bic     r1, r1, #(3 << (2 * BTN_ESTOP_PIN))
    bic     r1, r1, #(3 << (2 * BTN_TOUCH_PIN))
    str     r1, [r0, #GPIO_MODER]
    ldr     r1, [r0, #GPIO_OTYPER]
    bic     r1, r1, #(1 << LED_BLEUE_PIN)
    str     r1, [r0, #GPIO_OTYPER]
    ldr     r1, [r0, #GPIO_OSPEEDR]
    bic     r1, r1, #(3 << (2 * LED_BLEUE_PIN))
    str     r1, [r0, #GPIO_OSPEEDR]
    ldr     r1, [r0, #GPIO_PUPDR]
    bic     r1, r1, #(3 << (2 * LED_BLEUE_PIN))
    bic     r1, r1, #(3 << (2 * BTN_ESTOP_PIN))
    bic     r1, r1, #(3 << (2 * BTN_TOUCH_PIN))
    orr     r1, r1, #(BTN_ESTOP_PUPDR << (2 * BTN_ESTOP_PIN))
    orr     r1, r1, #(BTN_TOUCH_PUPDR << (2 * BTN_TOUCH_PIN))
    str     r1, [r0, #GPIO_PUPDR]

    /* état sûr initial : toutes les DEL éteintes (BSRR, moitié haute = mise à 0) */
    ldr     r0, =GPIOA_BASE
    mov     r1, #(1 << (LED_ROUGE_PIN + 16))
    str     r1, [r0, #GPIO_BSRR]
    ldr     r0, =GPIOC_BASE
    mov     r1, #(1 << (LED_VERTE_PIN + 16))
    str     r1, [r0, #GPIO_BSRR]
    ldr     r0, =GPIOB_BASE
    mov     r1, #(1 << (LED_BLEUE_PIN + 16))
    str     r1, [r0, #GPIO_BSRR]
    bx      lr
    .size   gpio_init, .-gpio_init

/* void led_set(uint32_t del)
 * r0 = LED_AUCUNE (0), LED_ROUGE (1), LED_VERTE (2), LED_BLEUE (3).
 * Allume exactement la DEL demandée et éteint les autres, par BSRR
 * (écriture atomique : jamais de lecture-modification-écriture sur ODR).
 *
 * E9 : la séquence « tout éteindre puis allumer » est une section critique
 * (PRIMASK). Sans elle, l'ISR E-Stop pourrait allumer la rouge entre les deux
 * étapes, puis led_set allumerait la verte : deux DEL allumées. L'interruption
 * est seulement retardée de quelques cycles (quelques µs à 4 MHz), loin de la
 * limite de 10 ms. PRIMASK est restauré à sa valeur d'entrée (appel possible
 * avec les interruptions déjà masquées).
 * Registres modifiés : r1-r3 (r0 conservé, routine feuille).                */
    .global led_set
    .type   led_set, %function
led_set:
    mrs     r3, primask                 /* sauvegarder l'état de masquage */
    cpsid   i                           /* début de section critique */
    /* 1) tout éteindre */
    ldr     r1, =GPIOA_BASE
    mov     r2, #(1 << (LED_ROUGE_PIN + 16))
    str     r2, [r1, #GPIO_BSRR]
    ldr     r1, =GPIOC_BASE
    mov     r2, #(1 << (LED_VERTE_PIN + 16))
    str     r2, [r1, #GPIO_BSRR]
    ldr     r1, =GPIOB_BASE
    mov     r2, #(1 << (LED_BLEUE_PIN + 16))
    str     r2, [r1, #GPIO_BSRR]
    /* 2) choisir le port et le bit de la DEL demandée */
    cmp     r0, #LED_ROUGE
    beq     led_set_rouge
    cmp     r0, #LED_VERTE
    beq     led_set_verte
    cmp     r0, #LED_BLEUE
    beq     led_set_bleue
    b       led_set_fin                 /* LED_AUCUNE ou valeur invalide */
led_set_rouge:
    ldr     r1, =GPIOA_BASE
    mov     r2, #(1 << LED_ROUGE_PIN)
    b       led_set_allumer
led_set_verte:
    ldr     r1, =GPIOC_BASE
    mov     r2, #(1 << LED_VERTE_PIN)
    b       led_set_allumer
led_set_bleue:
    ldr     r1, =GPIOB_BASE
    mov     r2, #(1 << LED_BLEUE_PIN)
led_set_allumer:
    str     r2, [r1, #GPIO_BSRR]        /* 3) allumer */
led_set_fin:
    msr     primask, r3                 /* fin de section critique */
    bx      lr
    .size   led_set, .-led_set
