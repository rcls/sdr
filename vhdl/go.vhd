library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library unisim;
use unisim.vcomponents.all;

library work;
use work.all;
use work.defs.all;

entity go is
  port(adc_p : in unsigned7;
       adc_n : in unsigned7;
       adc_clk_p : out std_logic;
       adc_clk_n : out std_logic;
       adc_reclk_p : in std_logic;
       adc_reclk_n : in std_logic;

       adc_sen   : out std_logic := '0';
       adc_sdata : out std_logic := '0';
       adc_sclk  : out std_logic := '0';
       adc_reset : out std_logic := '1';

       audio_scki, audio_lrck, audio_data, audio_bck : out std_logic;
       audio_pd_inv, audio_demp : out std_logic;

       usb_d : inout unsigned8;
       usb_c : inout unsigned8;

       flash_cs_inv, flash_sclk, flash_si : out std_logic;
       flash_so : in std_logic;

       spartan_m0 : in std_logic;
       spartan_m1 : in std_logic;

       led : out unsigned8;

       clkin125 : in std_logic;
       clkin125_en : out std_logic);
end go;

architecture behavioural of go is
  signal qq : four_signed36;
  signal ii : four_signed36;

  signal qq_buf : signed36;
  signal ii_buf : signed36;
  signal qq_buf_strobe0 : std_logic;

  signal packet : unsigned(39 downto 0);

  -- Generated clock for delivery to ADC.
  signal adc_clk : std_logic;
  signal adc_clk_neg : std_logic;
  signal adc_clk_u : std_logic;
  signal adc_clk_neg_u : std_logic;
  signal adc_clk_fb : std_logic;

  -- Received clk from ADC.
  signal adc_reclk_b : std_logic;
  signal adc_reclk : std_logic;

  signal adc_reclk_diff : std_logic;

  -- Regenerated reclk.
  signal clk_main : std_logic;
  signal clk_main_neg : std_logic;
  signal clku_main : std_logic;
  signal clku_main_neg : std_logic;
  signal clk_main_fb : std_logic;

  signal clkin125_b : std_logic;
  signal clk_12m5 : std_logic;
  signal clku_12m5 : std_logic;

  signal adc_ddr : unsigned7;
  signal adc_data : signed14;
  signal adc_data_b : signed14;

  signal phase : signed18;
  signal phase_strobe0 : std_logic;

  signal ir_data : signed36;
  signal ir_strobe : std_logic;
  signal ir_strobe0 : std_logic;

  signal usb_xmit, usb_xmit0 : std_logic;
  signal usb_xmit_length : integer range 0 to 5;
  signal usb_xmit_overrun : std_logic;

  signal low_data : signed32;
  signal low_strobe : std_logic;
  signal low_strobe0 : std_logic;

  signal out_data : signed32;
  signal out_strobe0 : std_logic;

  -- The configuration loaded from USB.
  signal config : unsigned(151 downto 0);
  alias adc_control : unsigned8 is config(135 downto 128);
  alias xmit_control : unsigned8 is config(143 downto 136);
  alias xmit_channel : unsigned2 is xmit_control(1 downto 0);
  alias flash_control : unsigned8 is config(151 downto 144);

  signal led_off : unsigned8 := x"fe";

  signal usbd_out : unsigned8;
  signal usb_oe_n : std_logic;

  attribute S : string;
  attribute S of usb_c : signal is "yes";
  attribute S of led : signal is "yes";

  attribute pullup : string;
  attribute pullup of spartan_m0, spartan_m1 : signal is "TRUE";

  alias clk_main_locked : std_logic is led_off(1);
  alias adc_clk_locked : std_logic is led_off(2);

begin
  usb_d <= usbd_out when usb_oe_n = '0' else "ZZZZZZZZ";
  usb_c(7 downto 5) <= "ZZZ";
  usb_c(0) <= 'Z'; -- nRXF.
  usb_c(1) <= 'Z'; -- nTXE.

  clkin125_en <= '1';

  audio_pd_inv <= '1';
  audio_demp <= '0';

  adc_sen   <= adc_control(0);
  adc_sdata <= adc_control(1);
  adc_sclk  <= adc_control(2);
  adc_reset <= adc_control(3);

  flash_cs_inv <= flash_control(0);
  flash_si <= flash_control(1);
  flash_sclk <= flash_control(2);

  led_control: for i in 0 to 7 generate
    led(i) <= '0' when led_off(i) = '0' else 'Z';
  end generate;

  led_off(5) <= not usb_xmit_overrun;

  led_off(6) <= spartan_m0;
  led_off(7) <= not spartan_m1;

  blinky : entity blinkoflow port map(
    adc_data_b, led_off(4), open, clk_main);

  down: for i in 0 to 3 generate
    downblock: block
      signal freq : unsigned24;
      signal gain : unsigned8;
    begin
      freq <= config(i * 32 + 23 downto i * 32);
      gain <= config(i * 32 + 31 downto i * 32 + 24);
      down0: entity downconvert
        port map (data => adc_data_b, freq => freq, gain => gain,
                  clk => clk_main,
                  qq => qq(i), ii => ii(i));
    end block;
  end generate;

  qfilter: entity multifilter
    port map(qq, qq_buf, qq_buf_strobe0, clk_main);

  ifilter: entity multifilter
    port map(ii, ii_buf, open, clk_main);

  ph: entity phasedetect
    port map(qq_buf, ii_buf, phase, qq_buf_strobe0, phase_strobe0, clk_main);

  irf: entity irfir
    generic map (acc_width => 36, out_width => 36)
    port map(phase, phase_strobe0, ir_data, ir_strobe, ir_strobe0, clk_main);

  lf: entity lowfir
    generic map (acc_width => 37, out_width => 32)
    port map(ir_data(35 downto 18), ir_strobe0,
             low_data, low_strobe, low_strobe0, clk_main);

  demph: entity quaddemph generic map (32, 40, 32, 1)
    port map (low_data, low_strobe, low_strobe0,
              out_data, out_strobe0, clk_main);

  au: entity audio generic map (bits_per_sample => 32)
    port map (out_data, out_data, out_strobe0,
              audio_scki, audio_lrck, audio_data, audio_bck, clk_main);

  process
  begin
    wait until rising_edge(clk_main);
    adc_data_b <= adc_data xor "10" & x"000";
    packet <= (others => 'X');

    case xmit_control(3 downto 2) is
      when "00" =>
        packet(35 downto 0) <= unsigned(ir_data);
        packet(38 downto 36) <= "000";
        packet(39) <= usb_xmit_overrun;
        usb_xmit <= usb_xmit xor ir_strobe;
        usb_xmit0 <= ir_strobe0;
        usb_xmit_length <= 5;
      when "01" =>
        packet(13 downto 0) <= unsigned(adc_data_b);
        packet(14) <= usb_xmit_overrun;
        usb_xmit <= usb_xmit xor ir_strobe;
        usb_xmit0 <= '1';
        usb_xmit_length <= 2;
      when "10" =>
        packet(2 downto 0) <= flash_control(2 downto 0);
        packet(3) <= flash_so;
        packet(6 downto 4) <= "000";
        packet(7) <= usb_xmit_overrun;
        usb_xmit <= flash_control(3);
        usb_xmit0 <= '1';
        usb_xmit_length <= 1;
      when others =>
        usb_xmit_length <= 0;
        usb_xmit0 <= '1';
    end case;
  end process;

  -- Protocol: config packets, little endian:
  -- 3 bytes freq(0)
  -- 1 byte gain(0)
  -- 3 bytes freq(1)
  -- 1 byte gain(1)
  -- 3 bytes freq(2)
  -- 1 byte gain(2)
  -- 3 bytes freq(3)
  -- 1 byte gain(3)
  -- 1 byte:
  --  low nibble ADC control pins,
  --  bit 4: data enable,
  --  bits 4..7: LEDs.

  -- Data packets, little endian.
  -- 36 bits radio phase data.
  -- 3 pad bits.
  -- 1 bit tx overrun indicator.

  usb: entity usbio
    generic map(
      19, 5,
      x"0f" & x"ff" & x"09"
      & x"00000000" & x"00000000" & x"00000000" & x"005ed288")
    port map(usbd_in => usb_d, usbd_out => usbd_out, usb_oe_n => usb_oe_n,
             usb_nRXF => usb_c(0), usb_nTXE => usb_c(1),
             usb_nRD => usb_c(2),  usb_nWR => usb_c(3),
             usb_SIWA => usb_c(4),
             config => config, tx_overrun => usb_xmit_overrun,
             packet => packet,
             xmit => usb_xmit, xmit0 => usb_xmit0,
             xmit_channel => xmit_channel, xmit_length => usb_xmit_length,
             clk => clk_12m5);

  -- DDR input from ADC.
  adc_input: for i in 0 to 6 generate
    adc_in: ibufds generic map (diff_term => true)
      port map (I => adc_n(i), IB => adc_p(i), O => adc_ddr(i));
    adc_ddr_expand: IDDR2
      generic map (ddr_alignment => "C0")
      port map (C0 => clk_main, C1 => clk_main_neg,
                CE => '1',
                D  => adc_ddr(i),
                Q0 => adc_data(i*2+1), Q1 => adc_data(i*2));
  end generate;

  -- Clk input from ADC.  The ADC drives the data as even on P-falling followed
  -- by odd on P-rising.
  adc_reclk_in: IBUFGDS
    generic map (diff_term => true)
    port map(I => adc_reclk_n, IB => adc_reclk_p, O => adc_reclk_b);
  -- Are these needed?  Do we need to tie them together?
  adc_reclk_buf: BUFIO2
    port map(I => adc_reclk_b, DIVCLK => adc_reclk,
             IOCLK => open, SERDESSTROBE => open);
  adc_reclkfb: BUFIO2FB port map(I => clk_main_neg, O => clk_main_fb);

  -- Pseudo differential drive of clock to ADC.
  adc_clk_ddr_p : oddr2
    port map (D0 => '1', D1 => '0', C0 => adc_clk, C1 => adc_clk_neg,
              Q => adc_clk_p);
  adc_clk_ddr_n : oddr2
    port map (D0 => '0', D1 => '1', C0 => adc_clk, C1 => adc_clk_neg,
              Q => adc_clk_n);

  -- Regenerate the clock from the ADC.
  -- We run the PLL oscillator at 1000MHz, i.e., 4 times the input clock.
  clk_main_pll : PLL_BASE
    generic map(
      CLK_FEEDBACK   => "CLKOUT0",
      DIVCLK_DIVIDE  => 1, CLKFBOUT_MULT => 1,
      CLKOUT0_DIVIDE => 4,
      CLKOUT1_DIVIDE => 4, CLKOUT1_PHASE => 180.0,
      CLKOUT2_DIVIDE => 80, CLKOUT2_PHASE => 9.0,
      CLKIN_PERIOD   => 4.0)
    port map(
      -- Output clocks
      CLKFBIN => clk_main_fb,
      CLKOUT0 => clku_main_neg, CLKOUT1 => clku_main, CLKOUT2 => clku_12m5,
      RST     => '0', LOCKED => clk_main_locked,
      CLKIN   => adc_reclk);

  clk_main_bufg     : BUFG port map(I => clku_main,     O => clk_main);
  clk_main_neg_bufg : BUFG port map(I => clku_main_neg, O => clk_main_neg);
  clk_12m5_bufg     : BUFG port map(I => clku_12m5,     O => clk_12m5);

  clkin125_bufg : bufg port map(I => clkin125, O => clkin125_b);

  -- Generate the clock to the ADC.  We run the PLL oscillator at 1000MHz, (8
  -- times the input clock), and then generate a 250MHz output.
  adc_clk_pll : PLL_BASE
    generic map(
      BANDWIDTH      => "LOW",
      CLK_FEEDBACK   => "CLKFBOUT",
      DIVCLK_DIVIDE  => 1, CLKFBOUT_MULT => 8,
      CLKOUT0_DIVIDE => 4,
      CLKOUT1_DIVIDE => 4, CLKOUT1_PHASE => 180.000,
      CLKIN_PERIOD   => 8.0)
    port map(
      -- Output clocks
      CLKFBIN => adc_clk_fb, CLKFBOUT => adc_clk_fb,
      CLKOUT0 => adc_clk_u,  CLKOUT1  => adc_clk_neg_u,
      RST     => '0',        LOCKED   => adc_clk_locked,
      CLKIN   => clkin125_b);

  adc_clk_bufg     : BUFG port map (I => adc_clk_u,     O => adc_clk);
  adc_clk_neg_bufg : BUFG port map (I => adc_clk_neg_u, O => adc_clk_neg);

end behavioural;
