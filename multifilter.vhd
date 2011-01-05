library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library work;
use work.defs.all;

-- Multiplex two streams through the filter.  The filter is second
-- order, the first order diffs samples 1024 apart, then the second
-- diffs two first order diffs, again 1024 apart.
-- Each channel gets done once per 8 cycles, and the output
-- is updated once every 4 cycles.
entity multifilter is
  port (in0 : in signed36;
        in1 : in signed36;
        qq : out signed36;
        Clk : in std_logic);
end;

architecture Behavioral of multifilter is
  type ram_t is array(0 to 512) of signed36;
  signal ram : ram_t;
  signal buf : signed36;
  signal ramout : signed36;
  signal count : unsigned(9 downto 0);
  signal index : unsigned(8 downto 0);
  alias switch : std_logic is index(0);
  alias phase : unsigned(1 downto 0) is count(1 downto 0);

  signal diff : signed36;

begin
  index <= count(9 downto 2) & count(0);

  process (Clk)
    variable dd : signed36;
  begin
    if Clk'event and Clk = '1' then
      count <= count + 1;

      if switch = '0' then
        dd := in0;
      else
        dd := in1;
      end if;

      -- Only wanted on phase 0 and 1.
      buf <= ram(to_integer(index));

      -- Only wanted on phase 1 and 2.
      ramout <= buf;

      -- Only need to do in one of phase 0&1 but doing it on both is harmless.
      if phase(1) = '0' then
        diff <= dd;
      end if;

      if phase(1) = '1' then
        diff <= diff - ramout;
        ram(to_integer(index)) <= diff;
      end if;

      if phase = "00" then
        qq <= diff;
      end if;

    end if;
  end process;

end Behavioral;
