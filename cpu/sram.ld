MEMORY {
  sram (WX) : ORIGIN = 0x20000000, LENGTH = 8K
  flash (RX) : ORIGIN = 0, LENGTH = 64K
}

SECTIONS
{
  .text : {
     __text_start = .;
     KEEP(*(.start))
     *(.text*)
     *(.rodata*)
     *(.data*)
     *(.got*)
     . = NEXT(4);
     __text_end = .;
  } > sram
  .bss (NOLOAD) : {
     __bss_start = .;
     *(SORT_BY_ALIGNMENT(.bss*))
     __bss_end = .;
  } > sram
}
