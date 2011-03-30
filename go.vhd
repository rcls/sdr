library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library unisim;
use unisim.vcomponents.all;

library work;
use work.defs.all;

entity go is
  port(adc_p : in std_logic7;
       adc_n : in std_logic7;
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

  signal clk_fast : std_logic; -- 125MHz clock.
  signal clk_fast_neg : std_logic;
  signal clk62m5 : std_logic; -- 62.5MHz clock.

  signal clkbuf125 : std_logic; -- buffered input clock.
  signal clkgen_fast : std_logic; -- 125MHz CMT output.
  signal clkgen62m5 : std_logic; -- 62.5Mhz CMT output.
  signal clkfbout : std_logic; -- FB output from CMT.
  signal clkfbout_buf : std_logic; -- FB output from BUFG.

  signal adc_diff : std_logic7;
--  signal data_vector : std_logic_vector(13 downto 0);
  signal data : signed14;

  signal adc_reclk_diff : std_logic;

  signal clkbuf125_neg : std_logic;

begin
  clkbuf125_neg <= not clkbuf125;
  clk_fast_neg <= not clk_fast;
--  data <= signed(data_vector);

  down0: entity work.downconvert
    port map(data => data,
             freq => f0,
             Clk => clk_fast,
             qq => qq0,
             ii => ii0);

  down1: entity work.downconvert
    port map(data => data,
             freq => f1,
             Clk => clk_fast,
             qq => qq1,
             ii => ii1);

  qfilter: entity work.multifilter
    port map(in0 => qq0,
             in1 => qq1,
             qq => qq_buf,
             clk => clk_fast);

  ifilter: entity work.multifilter
    port map(in0 => ii0,
             in1 => ii1,
             qq => ii_buf,
             clk => clk_fast);

  ph: entity work.phasedetect
    port map(qq_in => qq_buf,
             ii_in => ii_buf,
             phase => phase,
             clk   => clk62m5);

  -- Pseudo differential drive of clock to ADC.
  clk_drv_p : oddr2
    port map (D0 => '0', D1 => '1', C0 => clkbuf125_neg, C1 => clkbuf125,
              Q => adc_clk_p);
  clk_drv_n : oddr2
    port map (D0 => '1', D1 => '0', C0 => clkbuf125_neg, C1 => clkbuf125,
              Q => adc_clk_n);

  -- Clk input from ADC.  FIXME - use bufio2 / bufio2fb
  adc_reclk_in: IBUFGDS_DIFF_OUT
    generic map (diff_term => true)
    port map (I => adc_reclk_n, IB => adc_reclk_p,
              O => open, OB => adc_reclk_diff);

  -- DDR input from ADC.
  adc_in: for i in 0 to 6 generate
    -- According to the TI docs, we get the low bits on the falling clock edge
    -- (i.e., clk_fast_neg) and then the high bits on the rising clock edge.
    adc_in: IBUFDS_DIFF_OUT
      generic map (diff_term => true)
      port map (I => adc_n(i), IB => adc_p(i),
                O => open, OB => adc_diff(i));
    adc_ddr: IDDR2
      generic map (ddr_alignment => "C1")
      port map (C0 => clk_fast_neg,
                C1 => clk_fast,
                CE => '1',
                D => adc_diff(i),
                Q0 => data(i*2),
                Q1 => data(i*2+1));
  end generate;

  process (clk_fast)
  begin
    if clk_fast'event and clk_fast = '1' then
      if set_f0 = '1' then
        f0 <= freq;
      end if;
      if set_f1 = '1' then
        f1 <= freq;
      end if;
    end if;
  end process;

  -- Input buffering
  --------------------------------------
  clk125_buf : IBUFG port map (O => clkbuf125, I => clkin125);

  -- PLL generating the clocks synchronous to the clock signal from the ADC.
  -- We run the PLL oscillator at 750MHz, which for the ADC at 125MHz is
  -- 6 times the input clock.
  pll : PLL_BASE
    generic map(
      --BANDWIDTH            => "HIGH",
      CLK_FEEDBACK         => "CLKFBOUT",
      COMPENSATION         => "SYSTEM_SYNCHRONOUS",
      DIVCLK_DIVIDE        => 1,
      CLKFBOUT_MULT        => 6, -- 125MHz.
      --CLKFBOUT_PHASE       => 0.000,
      CLKOUT0_DIVIDE       => 6, -- 125MHz.
      --CLKOUT0_PHASE        => 0.000,
      --CLKOUT0_DUTY_CYCLE   => 0.500,
      CLKOUT1_DIVIDE       => 12, -- 62.5Mhz
      --CLKOUT1_PHASE        => 0.000,
      --CLKOUT1_DUTY_CYCLE   => 0.500,
      CLKIN_PERIOD         => 8.0,
      REF_JITTER           => 0.001)
    port map(
      -- Output clocks
      CLKFBOUT            => clkfbout,
      CLKOUT0             => clkgen_fast,
      CLKOUT1             => clkgen62m5,
      CLKOUT2             => open,
      CLKOUT3             => open,
      CLKOUT4             => open,
      CLKOUT5             => open,
      LOCKED              => open,
      RST                 => '0',
      -- Input clock control
      CLKFBIN             => clkfbout_buf,
      CLKIN               => adc_reclk_diff);

  -- Output buffering
  -------------------------------------
  clk_fast_buf : BUFG port map (I => clkgen_fast, O => clk_fast);
  clk62m5_buf : BUFG port map (I => clkgen62m5, O => clk62m5);

  clkf_buf : BUFG port map (I => clkfbout, O => clkfbout_buf);

end Behavioral;
