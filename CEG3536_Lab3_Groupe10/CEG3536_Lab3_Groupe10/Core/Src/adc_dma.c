/* ---------------------------------------------------------------------------
 * adc_dma.c — pilote ADC1 + DMA1 au niveau des registres (CMSIS, sans HAL)
 *             (CEG 3536, laboratoire 3, E4)
 *
 * Séquence (RM0438, sections ADC, DMA, DMAMUX ; énoncé 4.8) :
 *   1. horloges ADC (AHB2), DMA1 et DMAMUX1 (AHB1), GPIOC ; PC0, PC1 analogiques  [FOURNI]
 *   2. horloge de l'ADC : ADC12_COMMON->CCR, CKMODE = 01 (HCLK/1, synchrone)
 *   3. sortie du mode basse consommation (DEEPPWD = 0), régulateur (ADVREGEN,
 *      attendre > 20 µs : delay_ms(1)), étalonnage (ADCAL puis attendre sa
 *      retombée, ADEN = 0 pendant l'étalonnage), activation (ISR = ADRDY (w1c),
 *      ADEN, attendre ISR.ADRDY)
 *   4. CFGR : RES = 00 (12 bits), CONT, DMAEN, DMACFG (circulaire), OVRMOD ;
 *      SMPR1 : SMP1 = SMP2 = 111 (640,5 cycles) ; SQR1 : L = 1 (2 conversions),
 *      SQ1 = 1 (IN1 = PC0), SQ2 = 2 (IN2 = PC1)
 *   5. DMAMUX1_Channel0->CCR = 5 (requête ADC1) ; DMA1_Channel1 : CPAR =
 *      &ADC1->DR, CM0AR = tampon (registre nommé CM0AR sur STM32L5), CNDTR =
 *      ADC_N_VOIES x n_par_voie, CCR = MINC | PSIZE_0 | MSIZE_0 | CIRC
 *      (DIR = 0 : périphérique vers mémoire), puis EN
 *   6. ADSTART
 * Débit par voie = 4 MHz / (2 x (640,5 + 12,5)) ~ 3,06 kHz ; un tour du tampon
 * (64 échantillons par voie) dure ~ 20,9 ms, soit ~ 48 tours par seconde
 * (vérifié par adc_dma_tours, T4).
 * Vérification au débogueur : ADC1->CR = 0x10000005 (ADVREGEN, ADSTART, ADEN),
 * ISR.ADRDY = 1, DMA1_Channel1->CNDTR qui décroît et se recharge, tampon qui
 * évolue quand on bouge le potentiomètre.
 * ------------------------------------------------------------------------- */
#include "stm32l552xx.h"
#include "lab3.h"
#include "adc_dma.h"

static uint32_t tours;

void adc_dma_init(volatile uint16_t *tampon, uint32_t n_par_voie)
{
    /* 1. horloges et broches analogiques [FOURNI] */
    RCC->AHB2ENR |= RCC_AHB2ENR_GPIOCEN | RCC_AHB2ENR_ADCEN;
    RCC->AHB1ENR |= RCC_AHB1ENR_DMA1EN | RCC_AHB1ENR_DMAMUX1EN;
    (void)RCC->AHB1ENR;
    GPIOC->MODER |= GPIO_MODER_MODE0 | GPIO_MODER_MODE1;      /* 11 = analogique */
    GPIOC->PUPDR &= ~(GPIO_PUPDR_PUPD0 | GPIO_PUPDR_PUPD1);

    /* 2. horloge ADC : CKMODE = 01, HCLK/1 (synchrone), soit 4 MHz */
    ADC12_COMMON->CCR = (ADC12_COMMON->CCR & ~ADC_CCR_CKMODE) | ADC_CCR_CKMODE_0;

    /* 3. sortie de veille profonde, régulateur (> 20 µs), étalonnage, activation */
    ADC1->CR &= ~ADC_CR_DEEPPWD;
    ADC1->CR |= ADC_CR_ADVREGEN;
    delay_ms(1u);
    ADC1->CR |= ADC_CR_ADCAL;
    while (ADC1->CR & ADC_CR_ADCAL) {
    }
    delay_ms(1u);                                  /* délai avant ADEN après ADCAL */
    ADC1->ISR = ADC_ISR_ADRDY;                     /* w1c                          */
    ADC1->CR |= ADC_CR_ADEN;
    while (!(ADC1->ISR & ADC_ISR_ADRDY)) {
    }

    /* 4. 12 bits (RES = 00), continu, DMA circulaire, écrasement si débordement ;
     *    640,5 cycles d'échantillonnage ; séquence de 2 : IN1 (PC0), IN2 (PC1)   */
    ADC1->CFGR = (ADC1->CFGR & ~ADC_CFGR_RES)
               | ADC_CFGR_CONT | ADC_CFGR_DMAEN | ADC_CFGR_DMACFG | ADC_CFGR_OVRMOD;
    ADC1->SMPR1 |= ADC_SMPR1_SMP1 | ADC_SMPR1_SMP2;
    ADC1->SQR1 = (1u << ADC_SQR1_L_Pos)            /* L = 1 : 2 conversions        */
               | (1u << ADC_SQR1_SQ1_Pos)
               | (2u << ADC_SQR1_SQ2_Pos);

    /* 5. DMAMUX : requête 5 (ADC1) sur le canal 0 ; DMA1 canal 1, périphérique
     *    vers mémoire, mots de 16 bits, mémoire incrémentée, circulaire         */
    DMAMUX1_Channel0->CCR = 5u;
    DMA1_Channel1->CCR = 0u;
    DMA1_Channel1->CPAR = (uint32_t)&ADC1->DR;
    DMA1_Channel1->CM0AR = (uint32_t)tampon;
    DMA1_Channel1->CNDTR = ADC_N_VOIES * n_par_voie;
    DMA1_Channel1->CCR = DMA_CCR_MINC | DMA_CCR_PSIZE_0 | DMA_CCR_MSIZE_0 | DMA_CCR_CIRC;
    DMA1_Channel1->CCR |= DMA_CCR_EN;
    tours = 0u;

    /* 6. départ des conversions */
    ADC1->CR |= ADC_CR_ADSTART;
}

void adc_dma_step(void)
{
    if (DMA1->ISR & DMA_ISR_TCIF1) {                          /* tour complet  */
        DMA1->IFCR = DMA_IFCR_CTCIF1;
        tours++;
    }
}

uint32_t adc_dma_tours(void)
{
    return tours;
}
