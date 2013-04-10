library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library work;
use work.defs.all;

-- Multiplex streams through the filter (currently four).  One sample is
-- processed every four clock cycles, i.e., each stream gets 1 every
-- 16 cycles.  The provider of the data should have carried out the second order
-- summation; we do the second order differencing.  We output
-- x(t)-x(t-236)-x(t-244)+x(t-480)
-- with a latency of four (?) clock cycles, and t incrementing once every 4
-- cycles.
--
-- Phase 0: acc = -x(t-59*4), start load x(t-120*4), output prev,
-- Phase 1: acc -= x(t-61*4), start load x(t).
-- Phase 2: acc += x(t-120*4), start load x(t-59*4+"+1").
-- Phase 3: acc += x(t), start load x(t-61*4+"+1").
-- Phase 0, index += 120*4.
-- Phase 1, index += "+1"-59*4
-- Phase 2, index += -2*4
-- Phase 3, index += -59*4
-- Note that the "+1" is +1 mod 4, but is either +5 or +1, choosen so that
-- floor(t/4) increments, so that the total increment over 16 cycles is +16.
-- We store 1 sample per cycle.  In phase 0, make sure that the store pointer
-- is not conflicting with the read pointer.
entity multifilter is
  port (dd : in four_mf_signed;
        qq : out mf_signed;
        qq_last : out std_logic;
        Clk : in std_logic);
end;

architecture multifilter of multifilter is
  subtype index_t is unsigned9;
  type ram_t is array(0 to 511) of mf_signed;

  signal ram : ram_t;
  signal rambuf : mf_signed;
  signal ramout : mf_signed;
  signal index, windex : index_t;

  signal data : mf_signed;
  alias phase : unsigned2 is windex(1 downto 0);
  alias switch : std_logic is index(0);

  signal acc : mf_signed;

  attribute keep of rambuf : signal is "true";
begin
  process
  begin
    wait until rising_edge(clk);
    rambuf <= ram(to_integer(index));
    ramout <= rambuf;

    phase <= phase + 1;
    ram(to_integer(windex)) <= data;

    case phase is
      when "00" =>
        qq <= acc;
        -- The index has already advanced, so we are outputing the last
        -- channel (3) when the index is on channel 0.
        qq_last <= b2s(index(1 downto 0) = "00");
        index(8 downto 2) <= index(8 downto 2) + 120;
        windex(8 downto 2) <= index(8 downto 2);
        acc <= -ramout;
        data <= dd(1);
      when "01" =>
        index(8 downto 2) <= index(8 downto 2) - 59 + 1;
        index(1 downto 0) <= index(1 downto 0) + 1;
        acc <= acc - ramout;
        data <= dd(2);
      when "10" =>
        index(8 downto 2) <= index(8 downto 2) - 2;
        acc <= acc + ramout;
        data <= dd(3);
      when others => -- "11"
        index(8 downto 2) <= index(8 downto 2) - 59;
        acc <= acc + ramout;
        data <= dd(0);
    end case;
  end process;

end multifilter;
