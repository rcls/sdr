library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library unisim;
use unisim.vcomponents.all;

library work;
use work.defs.all;

entity go is
  port(data : in signed14;
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

  signal clk250m : std_logic; -- 250MHz clock.
  signal clk62m5 : std_logic; -- 62.5MHz clock.

  signal clkbuf125 : std_logic; -- buffered input clock.
  signal clkgen250m : std_logic; -- 250MHz CMT output.
  signal clkgen62m5 : std_logic; -- 62.5Mhz CMT output.
  signal clkfbout : std_logic; -- FB output from CMT.
  signal clkfbout_buf : std_logic; -- FB output from BUFG.

begin
  down0: entity work.downconvert
    port map(data => data,
             freq => f0,
             Clk => clk250m,
             qq => qq0,
             ii => ii0);

  down1: entity work.downconvert
    port map(data => data,
             freq => f1,
             Clk => clk250m,
             qq => qq1,
             ii => ii1);

  qfilter: entity work.multifilter
    port map(in0 => qq0,
             in1 => qq1,
             qq => qq_buf,
             clk => clk250m);

  ifilter: entity work.multifilter
    port map(in0 => ii0,
             in1 => ii1,
             qq => ii_buf,
             clk => clk250m);

  ph: entity work.phasedetect
    port map(qq=>qq_buf,
             ii=>ii_buf,
             phase=>phase,
             clk=> clk250m);

  process (clk250m)
  begin
    if clk250m'event and clk250m = '1' then
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

  -- Clocking primitive
  pll_base_inst : PLL_BASE
    generic map(
      BANDWIDTH            => "HIGH",
      CLK_FEEDBACK         => "CLKFBOUT",
      COMPENSATION         => "SYSTEM_SYNCHRONOUS",
      DIVCLK_DIVIDE        => 1,
      CLKFBOUT_MULT        => 8,
      CLKFBOUT_PHASE       => 0.000,
      CLKOUT0_DIVIDE       => 4,
      CLKOUT0_PHASE        => 0.000,
      CLKOUT0_DUTY_CYCLE   => 0.500,
      CLKOUT1_DIVIDE       => 16,
      CLKOUT1_PHASE        => 0.000,
      CLKOUT1_DUTY_CYCLE   => 0.500,
      CLKIN_PERIOD         => 8.0,
      REF_JITTER           => 0.001)
    port map(
      -- Output clocks
      CLKFBOUT            => clkfbout,
      CLKOUT0             => clkgen250m,
      CLKOUT1             => clkgen62m5,
      CLKOUT2             => open,
      CLKOUT3             => open,
      CLKOUT4             => open,
      CLKOUT5             => open,
      LOCKED              => open,
      RST                 => '0',
      -- Input clock control
      CLKFBIN             => clkfbout_buf,
      CLKIN               => clkbuf125);

  -- Output buffering
  -------------------------------------
  clk250m_buf : BUFG port map (I => clkgen250m, O => clk250m);
  clk62m5_buf : BUFG port map (I => clkgen62m5, O => clk62m5);

  clkf_buf : BUFG port map (I => clkfbout, O => clkfbout_buf);

end Behavioral;
