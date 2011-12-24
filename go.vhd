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
       freq : in unsigned24;
       set_f0 : in std_logic;
       set_f1 : in std_logic;
       phase : out signed18;
       clkin125 : in std_logic);
end go;

architecture Behavioral of go is
  signal f0 : unsigned24;
  signal f1 : unsigned24;

  signal qq0 : signed36;
  signal ii0 : signed36;
  signal qq1 : signed36;
  signal ii1 : signed36;

  signal qq_buf : signed36;
  signal ii_buf : signed36;

  signal clkin125_buf : std_logic;

  -- Generated clock for delivery to ADC.
  signal adc_clk : std_logic;
  signal adc_clk_neg : std_logic;
  signal adc_clk_u : std_logic;
  signal adc_clk_neg_u : std_logic;
  signal adc_clk_fb : std_logic;

  -- Received clk from ADC.
  signal adc_reclk_b_n : std_logic;
  signal adc_reclk : std_logic;

  -- Regenerated reclk.
  signal clk_main : std_logic;
  signal clk_main_neg : std_logic;
  signal clku_main : std_logic;
  signal clku_main_neg : std_logic;
  signal clk_main_fb : std_logic;

  signal adc_ddr : unsigned7;
--  signal data_vector : std_logic_vector(13 downto 0);
  signal adc_data : signed14;

  signal adc_reclk_diff : std_logic;

  signal clkbuf125_neg : std_logic;

begin
  down0: entity work.downconvert
    port map(data => adc_data, freq => f0, Clk => clk_main,
             qq => qq0, ii => ii0);

  down1: entity work.downconvert
    port map(data => adc_data, freq => f1, Clk => clk_main,
             qq => qq1, ii => ii1);

  qfilter: entity work.multifilter
    port map(in0 => qq0, in1 => qq1, qq => qq_buf, clk => clk_main);

  ifilter: entity work.multifilter
    port map(in0 => ii0, in1 => ii1, qq => ii_buf, clk => clk_main);

  ph: entity work.phasedetect
    port map(qq_in=>qq_buf, ii_in=>ii_buf, phase=>phase, clk=> clk_main);

  process (clk_main)
  begin
    if clk_main'event and clk_main = '1' then
      if set_f0 = '1' then
        f0 <= freq;
      end if;
      if set_f1 = '1' then
        f1 <= freq;
      end if;
    end if;
  end process;


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
    port map(I => adc_reclk_n, IB => adc_reclk_p,
             O => adc_reclk_b_n);
  -- Are these needed?  Do we need to tie them together?
  adc_reclk_buf: BUFIO2 port map(
    I => adc_reclk_b_n,
    DIVCLK => adc_reclk, IOCLK => open, SERDESSTROBE => open);
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
  main_pll : PLL_BASE
    generic map(
      CLK_FEEDBACK    => "CLKOUT0",
      DIVCLK_DIVIDE   => 1, CLKFBOUT_MULT   => 1,
      CLKOUT0_DIVIDE  => 4,
      CLKOUT1_DIVIDE  => 4, CLKOUT1_PHASE   => 180.000,
      CLKIN_PERIOD    => 4.0)
    port map(
      -- Output clocks
      CLKFBIN  => clk_main_fb,
      CLKOUT0  => clku_main_neg, CLKOUT1  => clku_main,
      RST      => '0',
      CLKIN    => adc_reclk);

  clk_main_bufg     : BUFG port map(I => clku_main,     O => clk_main);
  clk_main_neg_bufg : BUFG port map(I => clku_main_neg, O => clk_main_neg);

  clkin125_bufg : BUFG port map(I => clkin125, O=>clkin125_buf);

  -- Generate the clock to the ADC.  We run the PLL oscillator at 1000MHz, (8
  -- times the input clock), and then generate a 250MHz output.
  adc_gen_pll : PLL_BASE
    generic map(
      BANDWIDTH       => "LOW",
      CLK_FEEDBACK    => "CLKFBOUT",
      DIVCLK_DIVIDE   => 1, CLKFBOUT_MULT   => 8,
      CLKOUT0_DIVIDE  => 4,
      CLKOUT1_DIVIDE  => 4, CLKOUT1_PHASE   => 180.000,
      CLKIN_PERIOD    => 8.0)
    port map(
      -- Output clocks
      CLKFBIN   => adc_clk_fb, CLKFBOUT  => adc_clk_fb,
      CLKOUT0   => adc_clk_u, CLKOUT1   => adc_clk_neg_u,
      RST       => '0',
      CLKIN     => clkin125_buf);
  adc_clk_bufg     : BUFG port map (I => adc_clk_u,     O => adc_clk);
  adc_clk_neg_bufg : BUFG port map (I => adc_clk_neg_u, O => adc_clk_neg);

end Behavioral;
