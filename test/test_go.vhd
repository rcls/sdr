library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library work;
use work.all;

entity test_go is
end test_go;

architecture test_go of test_go is
   signal usb_c : std_logic_vector(7 downto 0) := "111ZZZ11";
   signal reclk_p : std_logic := '0';
   signal reclk_n : std_logic;

   signal adc_p : std_logic_vector(6 downto 0) := "1000000";
   signal adc_n : std_logic_vector(6 downto 0) := "0111111";
begin
  reclk_n <= not reclk_p;
  adc_n <= not adc_p;

  g : entity work.go port map (
    adc_p => "0000000",
    adc_n => "0000000",
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
    usb_c => usb_c,

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
   variable seed1, seed2 : positive := 1;
   variable rand : real;
  begin
    wait for 2ns;
    reclk_p <= not reclk_p;

    uniform(seed1, seed2, rand);
    adc_p <= std_logic_vector(to_unsigned(integer(trunc(rand * 128.0)), 7));
  end process;
end;
