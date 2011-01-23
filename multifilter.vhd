library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library work;
use work.defs.all;

-- Multiplex streams through the filter (currently two but the arithmetic works
-- for 4 or 8).  One sample is processed every four clock cycles.  The providers
-- of the data should have carried out the second order summation; we do the
-- second order differencing.  We output x(t)-x(t-27*8)-x(t-37*8)-x(t-64*8)
-- with a latency of four (?) clock cycles, and t incrementing once every 4
-- cycles.
--
-- Phase 0: Save input x(t), start load x(t-64*8) [same loc.], output prev,
--    acc := -x(t-27*8).
-- Phase 1: acc += x(t-64*8), start load x(t).
-- Phase 2: acc += x(t),      start load x(t-37*8).
-- Phase 3: acc -= x(t-37*8), start load x(t+1-27*8).
-- Phase 0, index += 0.
-- Phase 1, index -= 37*8
-- Phase 2, index += 1+10*8
-- Phase 3, index += 27*8
entity multifilter is
  port (in0 : in signed36;
        in1 : in signed36;
        qq : out signed36;
        Clk : in std_logic);
end;

architecture Behavioral of multifilter is
  type ram_t is array(0 to 511) of signed36;
  signal ram : ram_t;
  signal rambuf : signed36;
  signal ramout : signed36;
  signal index : unsigned(8 downto 0);
  signal phase : unsigned(1 downto 0);
  alias switch : std_logic is index(0);

  signal acc : signed36;

  -- To force dual-porting.
  signal index2 : unsigned(8 downto 0);
  alias switch2 : std_logic is index2(0);

begin
  index2 <= index;

  process (Clk)
    variable addend1 : signed36;
  begin
    if Clk'event and Clk = '1' then
      phase <= phase + 1;
      rambuf <= ram(to_integer(index));
      ramout <= rambuf;

      addend1 := acc;

      case phase is
        when "00" =>
          qq <= acc;
          addend1 := x"000000000";
          if switch = '0' then
            ram(to_integer(index)) <= in0;
          end if;
          if switch2 = '1' then
            ram(to_integer(index2)) <= in1;
          end if;
        when "01" =>
          index <= index + (1 + 512 - 37 * 8);
        when "10" =>
          index <= index + (10 * 8);
        when others => -- "11"
          index <= index + 27 * 8;
      end case;
      if phase = "01" or phase = "10" then
        acc <= addend1 + ramout;
      else
        acc <= addend1 - ramout;
      end if;
    end if;
  end process;

end Behavioral;
