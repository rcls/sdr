-- This generates the cpu clock @50 MHz.
-- It is carefully phased to get the 25Mbps SPI working.
-- It can be rephased via jtag user2.
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library unisim;
use unisim.vcomponents.all;

library work;
use work.all;
use work.defs.all;

entity clockgen is
  port (cpu_clk : out std_logic; wform : out unsigned(9 downto 0);
        clk_main, clk_main_neg, clk_50m : in std_logic);
end clockgen;
architecture clockgen of clockgen is
  signal update2, update3 : std_logic := '0';
  signal drck, tdi, tdi2, sel, sel2, update : std_logic;
  signal drck2, drck3 : std_logic := '1';
  signal init, bits, shift : unsigned(9 downto 0) := "0111110000";
  signal updated : boolean := true;
  signal count : integer range 0 to 4;
  signal first, second : std_logic;
  signal div50by2, div50by2prev, edge50 : std_logic;
begin
  occ : oddr2 generic map(ddr_alignment=>"C0", srtype=>"async")
    port map (c0 => clk_main, c1 => clk_main_neg, q => cpu_clk,
              d0 => first, d1 => second);
  jtg : bscan_spartan6 generic map (jtag_chain => 2)
    port map (drck => drck, tdi => tdi, update => update, tdo => shift(0),
              sel => sel);

  wform <= init;

  process
  begin
    wait until rising_edge(clk_50m);
    div50by2 <= not div50by2;
  end process;

  process
  begin
    wait until rising_edge(clk_main);
    div50by2prev <= div50by2;
    edge50 <= div50by2prev xor div50by2;

    count <= count + 1;
    if edge50 = '1' then
      count <= 0;
      if updated then
        bits(4 downto 0) <= (others => bits(9));
        bits(9 downto 5) <= (others => init(0));
        updated <= false;
      else
        bits <= init;
      end if;
    end if;
    first <= bits(count * 2);
    second <= bits(count * 2 + 1);

    drck2 <= drck;
    drck3 <= drck2;
    update2 <= update;
    update3 <= update2;
    sel2 <= sel;
    tdi2 <= tdi;

    if drck2 = '1' and drck3 = '0' and sel2 = '1' then
      shift <= tdi2 & shift(9 downto 1);
    end if;
    if update2 = '1' and update3 = '0' then
      init <= shift;
      updated <= true;
    end if;
  end process;
end clockgen;
