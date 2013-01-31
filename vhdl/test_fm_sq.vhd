-- Generate a complex signal with a square wave fm signal.  We apply
-- a small dc offset for fun.

-- We update the output every 80 cycles.

-- The peak modulation we can have is 75/3125 * 2pi radians, about 0.15 radians.
-- Let's use 1/16, about half that.

-- Let's take a modulation frequency around 500 Hz.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.defs.all;

entity test_fm_sq is
  port (qq : out signed36;
        ii : out signed36;
        clk : in std_logic);
end test_fm_sq;

architecture test_fm_sq of test_fm_sq is
  signal divide : unsigned(19 downto 0) := (others => '0');
  signal strobe : boolean;
  signal x : signed36 := x"1f0000000";
  signal y : signed36 := x"000000000";
  signal x1, x2, x3 : signed36;
  signal y1, y2, y3 : signed36;
  alias direction : std_logic is divide(19);
begin
  qq <= x;
  ii <= y;
  process
  begin
    wait until rising_edge(clk);
    if divide(2 downto 0) = "100" then
      divide <= divide + 4;
    else
      divide <= divide + 1;
    end if;
    strobe <= divide(6 downto 2) = "11111";
    --strobe <= divide(2) = '1';
    if strobe then
      x <= x3;
      y <= y3;
    end if;

    if direction = '1' then
      y1 <= y + x(35 downto 4);
      x1 <= x - y(35 downto 4);
    else
      y1 <= y - x(35 downto 4);
      x1 <= x + y(35 downto 4);
    end if;

    y2 <= y1 + x1(35 downto 10);
    x2 <= x1 - y1(35 downto 10);

    if x2(35 downto 34) = x2(34 downto 33)
      and y2(35 downto 34) = y2(34 downto 33) then
      x3 <= x2;
      y3 <= y2;
    else
      x3 <= x2(35) & x2(35 downto 1);
      y3 <= y2(35) & y2(35 downto 1);
    end if;
  end process;
end test_fm_sq;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.defs.all;

entity test_it is
  port (qq : out signed36;
        ii : out signed36);
end test_it;
architecture test_it of test_it is
  signal clk : std_logic;
begin
  uut: entity work.test_fm_sq port map(qq, ii, clk);
  process
  begin
    wait for 0.5ns;
    clk <= '0';
    wait for 0.5ns;
    clk <= '1';
  end process;
end;
