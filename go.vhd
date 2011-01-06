library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library work;
use work.defs.all;

entity go is
  port(data : in signed14;
       freq : in unsigned24;
       set_f0 : in std_logic;
       set_f1 : in std_logic;
       phase : out signed18;
       clk : in std_logic);
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

begin
  down0: entity work.downconvert
    port map(data => data,
             freq => f0,
             Clk => Clk,
             qq => qq0,
             ii => ii0);

  down1: entity work.downconvert
    port map(data => data,
             freq => f1,
             Clk => Clk,
             qq => qq1,
             ii => ii1);

  qfilter: entity work.multifilter
    port map(in0 => qq0,
             in1 => qq1,
             qq => qq_buf,
             clk => clk);

  ifilter: entity work.multifilter
    port map(in0 => ii0,
             in1 => ii1,
             qq => ii_buf,
             clk => clk);

  ph: entity work.phasedetect
    port map(qq=>qq_buf,
             ii=>ii_buf,
             phase=>phase,
             clk=> clk);

  process (clk)
  begin
    if clk'event and clk = '1' then
      if set_f0 = '1' then
        f0 <= freq;
      end if;
      if set_f1 = '1' then
        f1 <= freq;
      end if;
    end if;
  end process;
end Behavioral;
