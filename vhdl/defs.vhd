library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

package defs is
  subtype unsigned37 is unsigned(36 downto 0);
  subtype unsigned36 is unsigned(35 downto 0);
  subtype unsigned24 is unsigned(23 downto 0);
  subtype unsigned18 is unsigned(17 downto 0);
  subtype unsigned16 is unsigned(15 downto 0);
  subtype unsigned14 is unsigned(13 downto 0);
  subtype unsigned10 is unsigned(9 downto 0);
  subtype unsigned9 is unsigned(8 downto 0);
  subtype unsigned8 is unsigned(7 downto 0);
  subtype unsigned7 is unsigned(6 downto 0);
  subtype unsigned6 is unsigned(5 downto 0);
  subtype unsigned3 is unsigned(2 downto 0);
  subtype unsigned2 is unsigned(1 downto 0);

  subtype signed36 is signed(35 downto 0);
  subtype signed18 is signed(17 downto 0);
  subtype signed14 is signed(13 downto 0);

  type sinrom_t is array (0 to 1023) of unsigned18;
  type four_signed36 is array (0 to 3) of signed36;

end defs;