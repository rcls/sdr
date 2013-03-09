MEMORY {
  sram (WX) : ORIGIN = 0x20000000, LENGTH = 8K
  flash (RX) : ORIGIN = 0, LENGTH = 64K
}

SECTIONS
{
  .boot : {
     *(.bootstart*)
     *(.boottext*)
  } > flash
  __unreloc_start = .;
  .text 0x20001c00 : {
     __text_start = .;
     KEEP(*(.start))
     *(.text*)
     *(.rodata*)
     *(.got*)
     . = NEXT(4);
     __text_end = .;
  } AT> flash
  .bss (NOLOAD) : {
     __bss_start = .;
     *(SORT_BY_ALIGNMENT(.bss*))
     __bss_end = .;
  } > sram

  /DISCARD/ : {
     *(.data*)
  }
}
