library IEEE;
use IEEE.NUMERIC_STD.ALL;

package defs is
subtype unsigned24 is unsigned(23 downto 0);
subtype unsigned18 is unsigned(17 downto 0);
subtype unsigned2 is unsigned(1 downto 0);
subtype unsigned3 is unsigned(2 downto 0);
type sinrom_t is array (0 to 1023) of unsigned18;

subtype signed72 is signed(71 downto 0);
subtype signed36 is signed(35 downto 0);
subtype signed18 is signed(17 downto 0);
subtype signed14 is signed(13 downto 0);

end defs;