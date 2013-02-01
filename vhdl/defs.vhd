library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

package defs is
  subtype unsigned37 is unsigned(36 downto 0);
  subtype unsigned36 is unsigned(35 downto 0);
  subtype unsigned24 is unsigned(23 downto 0);
  subtype unsigned18 is unsigned(17 downto 0);
  subtype unsigned14 is unsigned(13 downto 0);
  subtype unsigned9 is unsigned(8 downto 0);
  subtype unsigned8 is unsigned(7 downto 0);
  subtype unsigned7 is unsigned(6 downto 0);
  subtype unsigned3 is unsigned(2 downto 0);
  subtype unsigned2 is unsigned(1 downto 0);

  subtype signed36 is signed(35 downto 0);
  subtype signed32 is signed(31 downto 0);
  subtype signed18 is signed(17 downto 0);
  subtype signed16 is signed(15 downto 0);
  subtype signed14 is signed(13 downto 0);

  type sinrom_t is array (0 to 1023) of unsigned18;
  type four_signed36 is array (0 to 3) of signed36;

  subtype command_t is std_logic_vector(23 downto 0);
  type program_t is array(integer range <>) of command_t;

  function b2s (x : boolean) return std_logic is
  begin
    if x then
      return '1';
    else
      return '0';
    end if;
  end b2s;
end defs;
