library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.all;

entity test_go is
end test_go;

architecture test_go of test_go is
   signal reclk_p, reclk_n : std_logic;
begin
  g : entity work.go port map (
    adc_p => "0001000",
    adc_n => "1110111",
    adc_clk_p => open,
    adc_clk_n => open,
    adc_reclk_p => reclk_p,
    adc_reclk_n => reclk_n,

    adc_sen => open,
    adc_sdata => open,
    adc_sclk => open,
    adc_reset => open,

    audio_scki => open,
    audio_lrck => open,
    audio_data => open,
    audio_bck => open,
    audio_pd_inv => open,
    audio_demp => open,

    usb_d => open,
    usb_c => "111ZZZ11",

    flash_cs_inv => open,
    flash_sclk => open,
    flash_si => open,
    flash_so => '1',

    cpu_ssifss => '1',
    cpu_ssiclk => '1',
    cpu_ssirx => open,
    cpu_ssitx => '1',

    spartan_m0 => '1',
    spartan_m1 => '1',

    led => open,

    clkin125 => '1',
    clkin125_en => open);

  process
  begin
    reclk_p <= '0';
    reclk_n <= '1';
    wait for 2ns;
    reclk_p <= '1';
    reclk_n <= '0';
    wait for 2ns;
  end process;
end;
