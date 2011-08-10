library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
--use IEEE.STD_LOGIC_ARITH.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
library UNISIM;
use UNISIM.VComponents.all;

entity led is
    Port ( clkin125 : in  STD_LOGIC;
           clkin125_en : out STD_LOGIC;
           usb_d : inout unsigned(7 downto 0);
           usb_c : inout unsigned(7 downto 0) := "ZZZZ11ZZ";
           led : out  unsigned(7 downto 0));
end led;

architecture Behavioral of led is
 signal divide : unsigned(23 downto 0);
 signal leds : unsigned(7 downto 0) := "00000001";

 alias nRXF : STD_LOGIC is usb_c(0);
 alias nTXE : STD_LOGIC is usb_c(1);
 alias nRD : STD_LOGIC is usb_c(2);
 alias nWR : STD_LOGIC is usb_c(3);
 alias SIWA : STD_LOGIC is usb_c(4);

 signal nREAD : STD_LOGIC := '1';
 signal wr : boolean := false;

 signal overflow : boolean := false;
 signal run : boolean := false;

 signal icap_write : std_logic := '1';
 signal icap_clk : std_logic := '1';
 signal icap_ce : std_logic := '1';

 subtype std_logic16 is std_logic_vector(15 downto 0);

 signal icap_insane : std_logic16;
 signal icap_i : std_logic16;

 type word_array is array (natural range <>) of std_logic16;
 constant icap_commands : word_array(0 to 15) := (
   x"ffff", x"ffff",
   x"aa99", x"5566",
   x"3261", x"0000",
   x"3281", x"0300",
   x"32a1", x"0000",
   x"32c1", x"0300",
   x"30a1", x"000e",
   x"2000", x"2000");

begin
  led <= not leds(7 downto 0);
  clkin125_en <= '1';

  nRD <= nREAD;

  nRXF <= 'Z';
  nTXE <= 'Z';

  SIWA <= '0';

  usb_c(7 downto 4) <= "ZZZZ";

  usb_d <= leds(7 downto 0) when wr else "ZZZZZZZZ";

  icap: ICAP_SPARTAN6 port map (BUSY => open,
                                O => open,
                                CE => icap_ce,
                                CLK => icap_clk,
                                I => icap_insane,
                                WRITE => icap_write);

  icap_sanitise: for i in 0 to 7 generate
    icap_insane(15 - i) <= icap_i(8 + i);
    icap_insane(7 - i) <= icap_i(i);
  end generate;

  process(clkin125)
    variable sum : unsigned(24 downto 0);
  begin
    if clkin125'event and clkin125 = '1' then
      sum := ('0' & divide) + 1;
      divide <= sum(23 downto 0);
      overflow <= (sum(24) = '1');

      if overflow then
        leds <= (leds(4) xor leds(3) xor leds(2) xor leds(0)) & leds(7 downto 1);
        --leds <= leds(6 downto 0) & (leds(3) xor leds(4) xor leds(5) xor leds(7));
        nREAD <= nRXF;
      elsif nREAD & divide(1 downto 0) = "000" then -- divide = 4
        leds <= usb_d;
        nREAD <= '1';
      end if;

      -- Drive the write cycles on 8..15.
      nWR <= '1';
      wr <= false;
      if run then
        case divide(3 downto 0) is
          when x"8"|x"9" =>
            wr <= true;
          when x"a"|x"b" =>
            wr <= true;
            nWR <= '0';
          when x"c"|x"d" =>
            nWR <= '0';
          when x"e"|x"f" =>
            run <= false;
          when others =>
        end case;
      else
        run <= overflow;
      end if;

      if overflow then
        if leds = x"00" then
          icap_ce <= '0';
          icap_write <= '0';
        else
          icap_ce <= '1';
          icap_write <= '1';
        end if;
      end if;

      icap_clk <= divide(7);
      icap_i <= icap_commands(to_integer(divide(11 downto 8)));

    end if;
  end process;

end Behavioral;
