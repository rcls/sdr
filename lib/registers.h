#ifndef REGISTERS_H_
#define REGISTERS_H_

#define REG_RADIO_FREQ(i) ((i) * 4)
#define REG_RADIO_GAIN(i) ((i) * 4 + 3)

#define REG_ADC 16
#define REG_XMIT 17
#define REG_FLASH 18
#define REG_BANDPASS_FREQ 19
#define REG_BANDPASS_GAIN 20
#define REG_SAMPLE_RATE 21
#define REG_SAMPLE_DECAY_LO 22
#define REG_SAMPLE_DECAY_HI 23

#define REG_MAGIC 0xfe
#define REG_ADDRESS 0xff

#define ADC_SEN 1
#define ADC_SDATA 2
#define ADC_SCLK 4
#define ADC_RESET 8
#define ADC_CLOCK_SELECT 128

#define XMIT_SOURCE(x) ((x) << 2)

#define XMIT_IR 0
#define XMIT_SAMPLE 4
#define XMIT_FLASH 8
#define XMIT_PHASE 12
#define XMIT_BANDPASS 16
#define XMIT_BURST 20
#define XMIT_IDLE 28

#define XMIT_TURBO 64
#define XMIT_LOW_LATENCY 128
#define XMIT_PUSH 192

#define FLASH_CS 1
#define FLASH_DATA 2
#define FLASH_CLK 4
#define FLASH_RECV 8
#define FLASH_XMIT 8
#define FLASH_OVERRUN 128

#define MAGIC_MAGIC 0xb5

#endif
