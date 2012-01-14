library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.defs.all;
use work.phasedetect;

entity test_phasedetect is
  port (qq_d : out signed(3 downto 0);
        ii_d : out signed(3 downto 0);
        phase : out unsigned18);
end test_phasedetect;

architecture behavioural of test_phasedetect is

   --Inputs
   signal qq_in : signed36 := (others => '0');
   signal ii_in : signed36 := (others => '0');
   signal clk : std_logic := '0';

   subtype nibble is signed(3 downto 0);
   subtype nibble_pair is signed(7 downto 0);
   type test_nibbles is array(integer range <>) of nibble_pair;

   signal nibbles : test_nibbles(0 to 59) := (
     x"07", x"17", x"27", x"37", x"47", x"57", x"67", x"77",
     x"76", x"75", x"74", x"73", x"72", x"71", x"70",
     x"7f", x"7e", x"7d", x"7c", x"7b", x"7a", x"79", x"78",
     x"68", x"58", x"48", x"38", x"28", x"18", x"08",
     x"f8", x"e8", x"d8", x"c8", x"b8", x"a8", x"98", x"88",
     x"89", x"8a", x"8b", x"8c", x"8d", x"8e", x"8f",
     x"80", x"81", x"82", x"83", x"84", x"85", x"86", x"87",
     x"97", x"a7", x"b7", x"c7", x"d7", x"e7", x"f7");

   signal qq1 : nibble;
   signal ii1 : nibble;
   signal qq2 : nibble;
   signal ii2 : nibble;
   signal qq3 : nibble;
   signal ii3 : nibble;

   signal div20 : integer := 0;

begin
  -- Instantiate the Unit Under Test (UUT)
  uut: entity phasedetect port map (qq_in => qq_in, ii_in => ii_in,
                                    phase => phase, clk => clk);

  process
  begin
    -- hold reset state for 100 ns.
    clk <= '0';
    wait for 100 ns;

    for i in 0 to 59 loop
      qq_in <= nibbles(i)(7 downto 4) & x"00000000";
      ii_in <= nibbles(i)(3 downto 0) & x"00000000";
      for j in 0 to 19 loop
        wait for 2 ns;
        clk <= '1';
        wait for 2 ns;
        clk <= '0';
      end loop;
    end loop;
    for j in 0 to 99 loop
      wait for 2 ns;
      clk <= '1';
      wait for 2 ns;
      clk <= '0';
    end loop;
    wait;
  end process;

  process
  begin
    wait until rising_edge(clk);
    div20 <= (div20 + 1) mod 20;
    if div20 = 19 then
      qq1 <= qq_in(35 downto 32);
      qq2 <= qq1;
      qq3 <= qq2;
      qq_d <= qq3;
      ii1 <= ii_in(35 downto 32);
      ii2 <= ii1;
      ii3 <= ii2;
      ii_d <= ii3;
    end if;
  end process;
end;
