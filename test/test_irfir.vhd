library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.defs.all;
use work.irfir;

entity test_irfir is
  port (q : out signed36);
end test_irfir;

architecture behavioural of test_irfir is

   --Inputs
   signal d : unsigned18 := (others => '0');
   signal clk : std_logic := '0';

begin
  -- Instantiate the Unit Under Test (UUT)
  uut: entity irfir
    generic map (acc_width => 36, out_width => 36)
    port map (d => d, q => q, clk => clk);

  process
  begin
    loop
      wait for 0.5 ns;
      clk <= '0';
      wait for 0.5 ns;
      clk <= '1';
    end loop;
  end process;

  process
  begin
    wait for 920 ns;
    loop
      for i in 1 to 4 loop
        for j in 1 to 80 loop
          wait until falling_edge(clk);
        end loop;
        d <= d + 1;
      end loop;
    end loop;
  end process;
end;
