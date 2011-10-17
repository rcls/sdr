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
  subtype unsigned8 is unsigned(7 downto 0);
  subtype unsigned7 is unsigned(6 downto 0);
  subtype unsigned6 is unsigned(5 downto 0);
  subtype unsigned3 is unsigned(2 downto 0);
  subtype unsigned2 is unsigned(1 downto 0);
  type sinrom_t is array (0 to 1023) of unsigned18;

  subtype signed48 is signed(47 downto 0);
  subtype signed36 is signed(35 downto 0);
  subtype signed32 is signed(31 downto 0);
  subtype signed18 is signed(17 downto 0);
  subtype signed14 is signed(13 downto 0);

--subtype std_logic7 is std_logic_vector(6 downto 0);

  function addmod96(x : unsigned7; y : unsigned7) return unsigned7;

end defs;

package body defs is
  function addmod96(x : unsigned7; y : unsigned7) return unsigned7 is
    variable low: unsigned6;
    variable high: unsigned2;
  begin
    low := ("0" & x(4 downto 0)) + ("0" & y(4 downto 0));
    case low(5) & x(6 downto 5) & y(6 downto 5) is
      when "00000" => high := "00";
      when "00001" => high := "01";
      when "00010" => high := "10";
      when "00100" => high := "01";
      when "00101" => high := "10";
      when "00110" => high := "00";
      when "01000" => high := "10";
      when "01001" => high := "00";
      when "01010" => high := "01";
      when "10000" => high := "01";
      when "10001" => high := "10";
      when "10010" => high := "00";
      when "10100" => high := "10";
      when "10101" => high := "00";
      when "10110" => high := "01";
      when "11000" => high := "00";
      when "11001" => high := "01";
      when "11010" => high := "10";
      when others => high := "XX";
    end case;
    return high & low(4 downto 0);
  end addmod96;

end package body defs;
