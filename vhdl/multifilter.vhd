library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library work;
use work.defs.all;

-- Multiplex streams through the filter (currently four but the arithmetic works
-- for eight).  One sample is processed every four clock cycles.  The providers
-- of the data should have carried out the second order summation; we do the
-- second order differencing.  We output x(t)-x(t-27*8)-x(t-37*8)+x(t-64*8)
-- with a latency of four (?) clock cycles, and t incrementing once every 4
-- cycles.
--
-- The *8 is for 250MHz; at 125MHz we do *4.
--
-- Phase 0: Save input x(t), start load x(t-64*8) [same loc.], output prev,
--    acc := -x(t-37*8).
-- Phase 1: acc -= x(t-27*8), start load x(t).
-- Phase 2: acc += x(t-64*8), start load x(t+1-37*8).
-- Phase 3: acc += x(t), start load x(t+1-27*8).
-- Phase 0, index += 0.
-- Phase 1, index += 1-37*8
-- Phase 2, index += 10*8
-- Phase 3, index += 27*8
entity multifilter is
  port (dd : in four_signed36;
        qq : out signed36;
        qq0_strobe : out std_logic;
        Clk : in std_logic);
end;

architecture behavioural of multifilter is
  constant scale : integer := 8; -- 4 for 125MHz, 8 for 250MHz.
  subtype index_t is unsigned(8 downto 0); -- 8 bits for 125MHz, 9 bits for 250.
  type ram_t is array(0 to scale * 64 - 1) of signed36;

  signal ram : ram_t;
  signal rambuf : signed36;
  signal ramout : signed36;
  signal index : index_t;

  signal data : signed36;
  signal phase : unsigned(1 downto 0);
  alias switch : std_logic is index(0);

  signal acc : signed36;

begin

  process (Clk)
    variable addend1 : signed36;
  begin
    if Clk'event and Clk = '1' then
      phase <= phase + 1;
      rambuf <= ram(to_integer(index));
      ramout <= rambuf;

      addend1 := acc;

      data <= dd(to_integer(index) mod 4);

      case phase is
        when "00" =>
          qq <= acc;
          qq0_strobe <= b2s((index mod 4) = 1);
          addend1 := x"000000000";
          ram(to_integer(index)) <= data;
        when "01" =>
          index <= index + 1 + 27 * scale;
        when "10" =>
          index <= index + 10 * scale;
        when others => -- "11"
          index <= index + 27 * scale;
      end case;
      if phase = "10" or phase = "11" then
        acc <= addend1 + ramout;
      else
        acc <= addend1 - ramout;
      end if;
    end if;
  end process;

end behavioural;
