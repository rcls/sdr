library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

package defs is
  subtype unsigned37 is unsigned(36 downto 0);
  subtype unsigned36 is unsigned(35 downto 0);
  subtype unsigned24 is unsigned(23 downto 0);
  subtype unsigned18 is unsigned(17 downto 0);
  subtype unsigned16 is unsigned(15 downto 0);
  subtype unsigned9 is unsigned(8 downto 0);
  subtype unsigned8 is unsigned(7 downto 0);
  subtype unsigned7 is unsigned(6 downto 0);
  subtype unsigned3 is unsigned(2 downto 0);
  subtype unsigned2 is unsigned(1 downto 0);

  subtype signed36 is signed(35 downto 0);
  subtype signed32 is signed(31 downto 0);
  subtype signed18 is signed(17 downto 0);
  subtype signed16 is signed(15 downto 0);
  subtype signed15 is signed(14 downto 0);
  subtype signed14 is signed(13 downto 0);

  type sinrom_t is array (0 to 1023) of unsigned18;
  type four_signed36 is array (0 to 3) of signed36;

  subtype command_t is std_logic_vector(23 downto 0);
  type program_t is array(integer range <>) of command_t;

  attribute keep : string;

  function b2s (x : boolean) return std_logic is
  begin
    if x then
      return '1';
    else
      return '0';
    end if;
  end b2s;

  -- The bottom 3 bits are added mod 5, so the overall effect is adding mod320.
  function addmod320(x : unsigned9; y : unsigned9) return unsigned9 is
    variable lo : unsigned(2 downto 0);
    variable carry : unsigned(0 downto 0);
  begin
    if x(2 downto 0) + ('0' & y(2 downto 0)) >= x"5" then
      lo := x(2 downto 0) + y(2 downto 0) + "011";
      carry := "1";
    else
      lo := x(2 downto 0) + y(2 downto 0);
      carry := "0";
    end if;
    return (x(8 downto 3) + y(8 downto 3) + carry) & lo;
  end;

  -- Extend by n bits; the shift parameter selects which of upper and lower
  -- bits to take the shift from.
  function take(x : signed; reduce : integer; shift : unsigned)
    return signed is
    variable shifted : signed(x'high downto x'low);
  begin
    shifted := x sll to_integer(shift);
    return shifted(shifted'high downto x'low + reduce);
  end;
end defs;
