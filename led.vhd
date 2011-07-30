library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
--use IEEE.STD_LOGIC_ARITH.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity led is
    Port ( clkin125 : in  STD_LOGIC;
           clkin125_en : out STD_LOGIC;
           usb_d : inout STD_LOGIC_VECTOR (7 downto 0);
           usb_c : inout STD_LOGIC_VECTOR (7 downto 0);
           led : out  STD_LOGIC_VECTOR (7 downto 0));
end led;

architecture Behavioral of led is
 signal divide : std_logic_vector(23 downto 0);
 signal leds : std_logic_vector(7 downto 0) := "00000001";

 alias nRXF : STD_LOGIC is usb_c(0);
 alias nTXE : STD_LOGIC is usb_c(1);
 alias nRD : STD_LOGIC is usb_c(2);
 alias nWR : STD_LOGIC is usb_c(3);
 alias SIWA : STD_LOGIC is usb_c(4);

 signal nREAD : STD_LOGIC := '1';
 signal wr : boolean := false;
begin
  led <= not leds(7 downto 0);
  clkin125_en <= '1';

  nRD <= nREAD;

  nRXF <= 'Z';
  nTXE <= 'Z';

  SIWA <= '0';

  usb_c(7 downto 4) <= "ZZZZ";

  usb_d <= leds(7 downto 0) when wr else "ZZZZZZZZ";

  process(clkin125)
  begin
    if clkin125'event and clkin125 = '1' then
      divide <= std_logic_vector(unsigned(divide) + 1);
      case divide is
        when x"ffffff" =>
          leds <= (leds(4) xor leds(3) xor leds(2) xor leds(0)) & leds(7 downto 1);
        when x"000000" =>
          nREAD <= nRXF;
        when x"000004" =>
          if nREAD = '0' then
            leds <= usb_d;
          end if;
          nREAD <= '1';
        when x"000010" =>
          wr <= true;
        when x"000012" =>
          nWR <= '0';
        when x"000015" =>
          nWR <= '1';
          wr <= false;
        when others =>
      end case;
    end if;
  end process;

end Behavioral;
