library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library unisim;
use unisim.vcomponents.all;

library work;
use work.defs.all;

entity go is
  port(adc_p : in unsigned7;
       adc_n : in unsigned7;
       adc_clk_p : out std_logic;
       adc_clk_n : out std_logic;
       adc_reclk_p : in std_logic;
       adc_reclk_n : in std_logic;

       usb_d : inout unsigned8;
       usb_c : inout unsigned8;

       adc_sen : out std_logic := '0';
       adc_sdata : out std_logic := '0';
       adc_sclk : out std_logic := '0';
       adc_reset : out std_logic := '1';

       led : out unsigned8;

       clkin125 : in std_logic;
       clkin125_en : out std_logic);
end go;

architecture behavioural of go is
  type four_unsigned24 is array(0 to 3) of unsigned24;
  signal f : four_unsigned24;

  signal qq : four_signed36;
  signal ii : four_signed36;

  signal qq_buf : signed36;
  signal ii_buf : signed36;

  signal packet : unsigned(23 downto 0);

  signal clkin125_buf : std_logic;

  -- Generated clock for delivery to ADC.
  signal adc_clk : std_logic;
  signal adc_clk_neg : std_logic;
  signal adc_clk_u : std_logic;
  signal adc_clk_neg_u : std_logic;
  signal adc_clk_fb : std_logic;

  -- Received clk from ADC.
  signal adc_reclk_b : std_logic;
  signal adc_reclk : std_logic;

  -- Regenerated reclk.
  signal clk_main : std_logic;
  signal clk_main_neg : std_logic;
  signal clku_main : std_logic;
  signal clku_main_neg : std_logic;
  signal clk_main_fb : std_logic;

  signal clk_12m5 : std_logic;
  signal clku_12m5 : std_logic;

  signal adc_ddr : unsigned7;
  signal adc_data : signed14;

  signal adc_reclk_diff : std_logic;

  signal clkbuf125_neg : std_logic;

  -- The configuration loaded from USB.
  signal config : unsigned(103 downto 0) := x"08000000000000000000000000";

  signal led_off : unsigned8 := x"fe";

  signal usbd_out : unsigned8;
  signal usb_oe_n : std_logic;

  attribute S : string;
  attribute S of usb_c : signal is "yes";
  attribute S of led : signal is "yes";

  alias clk_main_locked : std_logic is led_off(1);
  alias adc_clk_locked : std_logic is led_off(2);

begin
  usb_d <= usbd_out when usb_oe_n = '0' else "ZZZZZZZZ";
  usb_c(4) <= '0'; -- SIWA
  usb_c(7 downto 5) <= "ZZZ";
  clkin125_en <= '1';

  adc_sen   <= config(96);
  adc_sdata <= config(97);
  adc_sclk  <= config(98);
  adc_reset <= config(99);

  led_control: for i in 0 to 7 generate
    led(i) <= '0' when led_off(i) = '0' else 'Z';
  end generate;

  led_off(7 downto 4) <= config(103 downto 100);

  down: for i in 0 to 3 generate
    f(i) <= config(i * 24 + 23 downto i * 24);
    down0: entity work.downconvert
      port map (data => adc_data, freq => f(i), clk => clk_main,
                qq => qq(i), ii => ii(i));
  end generate;

  qfilter: entity work.multifilter
    port map(dd => qq, qq => qq_buf, clk => clk_main);

  ifilter: entity work.multifilter
    port map(dd => ii, qq => ii_buf, clk => clk_main);

  ph: entity work.phasedetect
    port map(qq_in=>qq_buf, ii_in=>ii_buf, phase => packet(17 downto 0),
             clk=> clk_main);

  -- Protocol: config packets, little endian:
  -- 3 bytes freq(0)
  -- 3 bytes freq(1)
  -- 3 bytes freq(2)
  -- 3 bytes freq(3)
  -- 1 byte: low nibble ADC control pins, bit 4: data enable, bits 4..7: LEDs.

  -- Data packets, little endian.
  -- 18 bits radio phase data.
  -- 5 bits unused.
  -- 1 bit tx overrun indicator.

  usb: entity work.usbio
    generic map(config_bytes => 13, packet_bytes => 3)
    port map(usbd_in => usb_d, usbd_out => usbd_out, usb_oe_n => usb_oe_n,
             usb_nRXF => usb_c(0), usb_nTXE => usb_c(1),
             usb_nRD => usb_c(2),  usb_nWR => usb_c(3),
             config => config, tx_overrun => packet(23),
             packet => packet, xmit => config(100), clk => clk_12m5);

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
  adc_reclk_in: IBUFGDS_DIFF_OUT
    generic map (diff_term => true)
    port map(I => adc_reclk_n, IB => adc_reclk_p,
             O=> open, OB => adc_reclk_b);
  -- Are these needed?  Do we need to tie them together?
  adc_reclk_buf: BUFIO2 port map(
    I => adc_reclk_b,
    DIVCLK => adc_reclk, IOCLK => open, SERDESSTROBE => open);
  adc_reclkfb: BUFIO2FB port map(I => clk_main, O => clk_main_fb);

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
      CLKOUT2_DIVIDE => 80,
      CLKIN_PERIOD   => 4.0)
    port map(
      -- Output clocks
      CLKFBIN => clk_main_fb,
      CLKOUT0 => clku_main, CLKOUT1 => clku_main_neg, CLKOUT2 => clku_12m5,
      RST     => '0', LOCKED => clk_main_locked,
      CLKIN   => adc_reclk);

  clk_main_bufg     : BUFG port map(I => clku_main,     O => clk_main);
  clk_main_neg_bufg : BUFG port map(I => clku_main_neg, O => clk_main_neg);
  clk_12m5_bufg     : BUFG port map(I => clku_12m5,     O => clk_12m5);

  clkin125_bufg : BUFG port map(I => clkin125, O=>clkin125_buf);

  -- Generate the clock to the ADC.  We run the PLL oscillator at 1000MHz, (8
  -- times the input clock), and then generate a 250MHz output.
  adc_clk_pll : PLL_BASE
    generic map(
      BANDWIDTH       => "LOW",
      CLK_FEEDBACK    => "CLKFBOUT",
      DIVCLK_DIVIDE   => 1, CLKFBOUT_MULT   => 8,
      CLKOUT0_DIVIDE  => 4,
      CLKOUT1_DIVIDE  => 4, CLKOUT1_PHASE   => 180.000,
      CLKIN_PERIOD    => 8.0)
    port map(
      -- Output clocks
      CLKFBIN => adc_clk_fb, CLKFBOUT => adc_clk_fb,
      CLKOUT0 => adc_clk_u,  CLKOUT1  => adc_clk_neg_u,
      RST     => '0',        LOCKED   => adc_clk_locked,
      CLKIN   => clkin125_buf);
  adc_clk_bufg     : BUFG port map (I => adc_clk_u,     O => adc_clk);
  adc_clk_neg_bufg : BUFG port map (I => adc_clk_neg_u, O => adc_clk_neg);

end behavioural;
