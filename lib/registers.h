#ifndef LIB_REGISTERS_H_
#define LIB_REGISTERS_H_

#define REG_RADIO_FREQ(i) ((i) * 4 + 16)
#define REG_RADIO_GAIN(i) ((i) * 4 + 19)

#define REG_USB_DATA 0
#define REG_ADC 1
#define REG_XMIT 2
#define REG_FLASH 3
#define REG_BANDPASS_FREQ 4
#define REG_BANDPASS_GAIN 5
#define REG_SAMPLE_RATE 6
#define REG_SAMPLE_DECAY_LO 7
#define REG_SAMPLE_DECAY_HI 8
#define REG_PLL_DECAY 9
#define REG_AUDIO_CHANNEL 10

#define REG_PLL_FREQ 32
#define REG_PLL_ERROR 40
#define REG_PLL_LEVEL 48
#define REG_PLL_CAPTURE 55

#define ADC_SEN 1
#define ADC_SDATA 2
#define ADC_SCLK 4
#define ADC_RESET 8

#define XMIT_IR 0
#define XMIT_SAMPLE 4
#define XMIT_MULTIF 8
#define XMIT_PHASE 12
#define XMIT_BANDPASS 16
#define XMIT_BURST 20
#define XMIT_CPU_SSI 24

#define XMIT_TURBO 64
#define XMIT_LOW_LATENCY 128
#define XMIT_PUSH 192

#define FLASH_DATA 1
#define FLASH_CS 2
#define FLASH_CLK 4
#define CLOCK_SELECT 128

#endif
