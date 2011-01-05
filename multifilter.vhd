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
  type ram_t is array(0 to 255) of signed36;
  signal ram_new : ram_t;
  signal ram_old : ram_t;
  signal buf_new : signed36;
  signal buf_new2 : signed36;           -- FIXME, use multicycle constraint.
  signal buf_old : signed36;
  signal buf_old2 : signed36;           -- FIXME, use multicycle constraint.
  signal index : unsigned(7 downto 0);
  alias switch : std_logic is index(0);
  signal phase : unsigned(3 downto 0);

  signal diff_new : signed36;

begin
  process (Clk)
    variable dd : signed36;
  begin
    if Clk'event and Clk = '1' then
      phase(3 downto 1) <= phase(2 downto 0);
      if phase(2 downto 0) = x"000" then
        phase(0) <= '1';
      else
        phase(0) <= '0';
      end if;

      if phase(3) = '1' then
        index <= index + 1;
      end if;

      if switch = '0' then
        dd := in0;
      else
        dd := in1;
      end if;

      -- Only wanted on phase 0.
      buf_new <= ram_new(to_integer(index));

      -- Only wanted on phase 1.
      buf_new2 <= buf_new;
      buf_old <= ram_old(to_integer(index));

      -- Only wanted on phase 2.
      buf_old2 <= buf_old;
      diff_new <= dd - buf_new2;
      if phase(2) = '1' then
        ram_new(to_integer(index)) <= dd;
      end if;

      -- Only wanted on phase 3.
      if phase(3) = '1' then
        qq <= diff_new - buf_old2;
        ram_old(to_integer(index)) <= diff_new;
      end if;

    end if;
  end process;

end Behavioral;
